import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';

admin.initializeApp();
const db = admin.firestore();

/** Escape HTML special characters to prevent XSS */
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Configure email transporter (Gmail or Firebase built-in)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.ADMIN_EMAIL || '',
    pass: process.env.ADMIN_EMAIL_PASSWORD || '',
  },
});

/**
 * Listen for data deletion requests and process them
 * Triggered when a new document is added to data_deletion_requests collection
 */
export const processDataDeletionRequest = functions.firestore
  .document('data_deletion_requests/{docId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = snap.id;
    
    try {
      const { email, dataTypes, reason, language } = requestData;
      
      console.log(`Processing data deletion request ${requestId} for ${email}`);
      
      // Verify email format
      if (!email || !email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
        await updateRequestStatus(requestId, 'failed', 'Invalid email format');
        return;
      }
      
      // Find user by email
      const userSnapshot = await db.collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();
      
      if (userSnapshot.empty) {
        await updateRequestStatus(requestId, 'failed', 'User not found');
        // Still send email to user
        await sendNotificationEmail(email, 'error', language, 'User account not found in our system');
        return;
      }
      
      const userId = userSnapshot.docs[0].id;
      const userEmail = userSnapshot.docs[0].get('email');
      
      // Verify email matches
      if (userEmail.toLowerCase() !== email.toLowerCase()) {
        await updateRequestStatus(requestId, 'failed', 'Email mismatch');
        return;
      }
      
      // Process data deletion
      const deletedData = await deleteUserData(userId, dataTypes);
      
      // Update request status
      await updateRequestStatus(requestId, 'completed', null, {
        deletedSections: deletedData,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Send confirmation email to user
      await sendNotificationEmail(email, 'success', language, deletedData);
      
      // Send notification to admin
      await sendAdminNotification(requestId, email, dataTypes, reason, deletedData);
      
      console.log(`Successfully processed deletion request ${requestId}`);
      
    } catch (error) {
      console.error(`Error processing deletion request ${requestId}:`, error);
      await updateRequestStatus(requestId, 'failed', error instanceof Error ? error.message : 'Unknown error');
    }
  });

/**
 * Commit operations in chunked batches (Firestore limit: 500 ops per batch)
 */
async function commitInChunks(operations: Array<{type: 'delete', ref: FirebaseFirestore.DocumentReference} | {type: 'update', ref: FirebaseFirestore.DocumentReference, data: object}>): Promise<void> {
  const BATCH_LIMIT = 499;
  for (let i = 0; i < operations.length; i += BATCH_LIMIT) {
    const chunk = operations.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const op of chunk) {
      if (op.type === 'delete') {
        batch.delete(op.ref);
      } else {
        batch.update(op.ref, op.data);
      }
    }
    await batch.commit();
  }
}

/**
 * Delete specified user data sections
 */
async function deleteUserData(userId: string, dataTypes: string[]): Promise<string[]> {
  const operations: Array<{type: 'delete', ref: FirebaseFirestore.DocumentReference} | {type: 'update', ref: FirebaseFirestore.DocumentReference, data: object}> = [];
  const userRef = db.collection('users').doc(userId);
  const deletedSections: string[] = [];
  
  // Normalize dataTypes - if "all" is included, delete everything
  const shouldDeleteAll = dataTypes.includes('all');
  const finalTypes = shouldDeleteAll ? ['bookmarks', 'wird', 'settings', 'history'] : dataTypes;
  
  for (const dataType of finalTypes) {
    try {
      if (dataType === 'bookmarks') {
        // Delete bookmarks subcollection
        const bookmarksSnapshot = await userRef.collection('bookmarks').get();
        bookmarksSnapshot.forEach(doc => operations.push({type: 'delete', ref: doc.ref}));
        deletedSections.push('bookmarks');
      } else if (dataType === 'wird') {
        // Delete wird data (daily progress)
        const wirdSnapshot = await userRef.collection('wird').get();
        wirdSnapshot.forEach(doc => operations.push({type: 'delete', ref: doc.ref}));
        deletedSections.push('wird');
      } else if (dataType === 'settings') {
        // Reset user settings (don't delete user doc, just clear settings)
        operations.push({type: 'update', ref: userRef, data: {
          'appSettings.theme': 'light',
          'appSettings.fontSize': 'medium',
          'appSettings.language': 'ar',
          'appSettings.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        }});
        deletedSections.push('settings');
      } else if (dataType === 'history') {
        // Delete reading/listening history
        const historySnapshot = await userRef.collection('readingHistory').get();
        historySnapshot.forEach(doc => operations.push({type: 'delete', ref: doc.ref}));
        
        const listeningSnapshot = await userRef.collection('listeningHistory').get();
        listeningSnapshot.forEach(doc => operations.push({type: 'delete', ref: doc.ref}));
        deletedSections.push('history');
      }
    } catch (error) {
      console.warn(`Warning deleting ${dataType} for user ${userId}:`, error);
    }
  }
  
  // Commit all deletions in chunked batches
  if (operations.length > 0) {
    await commitInChunks(operations);
  }
  
  return deletedSections;
}

/**
 * Update deletion request status
 */
async function updateRequestStatus(
  requestId: string,
  status: 'pending' | 'completed' | 'failed',
  errorMessage?: string | null,
  additionalData?: object
): Promise<void> {
  const updateData: any = {
    status,
    statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  if (errorMessage) {
    updateData.errorMessage = errorMessage;
  }
  
  if (additionalData) {
    Object.assign(updateData, additionalData);
  }
  
  await db.collection('data_deletion_requests').doc(requestId).update(updateData);
}

/**
 * Send email notification to user
 */
async function sendNotificationEmail(
  userEmail: string,
  type: 'success' | 'error',
  language: string,
  dataOrMessage: string[] | string
): Promise<void> {
  const isArabic = language === 'ar';
  
  let subject: string;
  let htmlContent: string;
  
  if (type === 'success') {
    const deletedSections = Array.isArray(dataOrMessage) ? dataOrMessage : [];
    subject = isArabic ? 'تأكيد: تم حذف بياناتك بنجاح' : 'Confirmation: Your Data Has Been Deleted';
    
    const deletedItemsList = deletedSections
      .map(item => {
        const labels: Record<string, {ar: string, en: string}> = {
          'bookmarks': { ar: 'الإشارات المرجعية', en: 'Bookmarks' },
          'wird': { ar: 'الورد اليومي', en: 'Daily Wird' },
          'settings': { ar: 'الإعدادات الشخصية', en: 'Personal Settings' },
          'history': { ar: 'تاريخ التلاوة', en: 'Recitation History' },
        };
        return `<li>${labels[item]?.[isArabic ? 'ar' : 'en'] || item}</li>`;
      })
      .join('\n');
    
    htmlContent = isArabic
      ? `
        <div style="direction: rtl; font-family: Arial, sans-serif; color: #333;">
          <h2>السلام عليكم ورحمة الله وبركاته</h2>
          <p>تم استقبال طلب حذف البيانات وتم معالجته بنجاح.</p>
          <h3>البيانات المحذوفة:</h3>
          <ul>${deletedItemsList}</ul>
          <p><strong>ملاحظة:</strong> قد تستغرق بعض البيانات المخزنة مؤقتاً وقتاً إضافياً للحذف تماماً.</p>
          <p>شكراً لك على استخدام تطبيق نور الإيمان.</p>
        </div>
      `
      : `
        <div style="font-family: Arial, sans-serif; color: #333;">
          <h2>Hello,</h2>
          <p>Your data deletion request has been processed successfully.</p>
          <h3>Deleted Data Categories:</h3>
          <ul>${deletedItemsList}</ul>
          <p><strong>Note:</strong> Some cached data may take additional time to be completely removed from backups.</p>
          <p>Thank you for using Quraan - Noor Al-Iman.</p>
        </div>
      `;
  } else {
    const errorMsg = typeof dataOrMessage === 'string' ? dataOrMessage : 'Unknown error';
    subject = isArabic ? 'خطأ: فشل طلب حذف البيانات' : 'Error: Data Deletion Request Failed';
    
    htmlContent = isArabic
      ? `
        <div style="direction: rtl; font-family: Arial, sans-serif; color: #d32f2f;">
          <h2>خطأ في معالجة الطلب</h2>
          <p>اعتذر، لم يتمكن النظام من معالجة طلب حذف البيانات:</p>
          <p><strong>${errorMsg}</strong></p>
          <p>يرجى التواصل معنا عبر البريد الإلكتروني للمساعدة.</p>
        </div>
      `
      : `
        <div style="font-family: Arial, sans-serif; color: #d32f2f;">
          <h2>Request Processing Error</h2>
          <p>We apologize, but we were unable to process your data deletion request:</p>
          <p><strong>${errorMsg}</strong></p>
          <p>Please contact us via email for assistance.</p>
        </div>
      `;
  }
  
  try {
    await transporter.sendMail({
      from: process.env.ADMIN_EMAIL || 'noreply@quran-app.com',
      to: userEmail,
      subject,
      html: htmlContent,
      replyTo: 'support@quran-app.com',
    });
    console.log(`Sent ${type} notification to ${userEmail}`);
  } catch (error) {
    console.error(`Failed to send email to ${userEmail}:`, error);
  }
}

/**
 * Send admin notification about data deletion request
 */
async function sendAdminNotification(
  requestId: string,
  email: string,
  dataTypes: string[],
  reason: string,
  deletedSections: string[]
): Promise<void> {
  const adminEmail = process.env.ADMIN_EMAIL || 'admin@quran-app.com';
  
  if (!adminEmail || adminEmail === '') {
    console.warn('Admin email not configured, skipping admin notification');
    return;
  }
  
  const subject = `[Data Deletion] Request ${requestId} - ${email}`;
  
  const htmlContent = `
    <div style="font-family: Arial, sans-serif; color: #333; direction: ltr;">
      <h2>Data Deletion Request Notification</h2>
      <table style="border-collapse: collapse; width: 100%;">
        <tr>
          <td style="border: 1px solid #ddd; padding: 8px; font-weight: bold;">Request ID:</td>
          <td style="border: 1px solid #ddd; padding: 8px;">${requestId}</td>
        </tr>
        <tr>
          <td style="border: 1px solid #ddd; padding: 8px; font-weight: bold;">User Email:</td>
          <td style="border: 1px solid #ddd; padding: 8px;">${email}</td>
        </tr>
        <tr>
          <td style="border: 1px solid #ddd; padding: 8px; font-weight: bold;">Requested Types:</td>
          <td style="border: 1px solid #ddd; padding: 8px;">${dataTypes.join(', ')}</td>
        </tr>
        <tr>
          <td style="border: 1px solid #ddd; padding: 8px; font-weight: bold;">Deleted Sections:</td>
          <td style="border: 1px solid #ddd; padding: 8px;">${deletedSections.join(', ')}</td>
        </tr>
        <tr>
          <td style="border: 1px solid #ddd; padding: 8px; font-weight: bold;">User Reason:</td>
          <td style="border: 1px solid #ddd; padding: 8px;">${escapeHtml(reason || 'N/A')}</td>
        </tr>
      </table>
      <p style="margin-top: 20px; color: #666; font-size: 0.9em;">
        This is an automated notification. Check Firebase Console for more details.
      </p>
    </div>
  `;
  
  try {
    await transporter.sendMail({
      from: process.env.ADMIN_EMAIL || 'noreply@quran-app.com',
      to: adminEmail,
      subject,
      html: htmlContent,
    });
    console.log(`Sent admin notification for request ${requestId}`);
  } catch (error) {
    console.error(`Failed to send admin notification:`, error);
  }
}
