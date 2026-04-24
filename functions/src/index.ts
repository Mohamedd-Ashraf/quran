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

function stableAnonymousNumberFromUid(uid: string): number {
  let hash = 2166136261;
  for (let i = 0; i < uid.length; i++) {
    hash ^= uid.charCodeAt(i);
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return (hash % 999) + 1;
}

function anonymousDisplayNameFromUid(uid: string): string {
  return `مستخدم مجهول #${stableAnonymousNumberFromUid(uid)}`;
}

function utcDateKey(date = new Date()): string {
  const yyyy = date.getUTCFullYear().toString().padStart(4, '0');
  const mm = (date.getUTCMonth() + 1).toString().padStart(2, '0');
  const dd = date.getUTCDate().toString().padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function aliasFromUid(uid: string): string {
  const cleaned = uid.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
  const tail = cleaned.length >= 4
    ? cleaned.slice(-4)
    : cleaned.padStart(4, '0');
  return `User${tail}`;
}

function toNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

async function upsertDailyLeaderboardEntry(
  uid: string,
  payload: {
    totalScore: number;
    streak: number;
    correctAnswers: number;
    totalAnswered: number;
  },
): Promise<void> {
  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.data() || {};

  const showInLeaderboard = userData.showInLeaderboard !== false;
  const userName = typeof userData.name === 'string' && userData.name.trim().length > 0
    ? userData.name.trim()
    : aliasFromUid(uid);

  const cachedDisplayName = showInLeaderboard
    ? userName
    : anonymousDisplayNameFromUid(uid);
  const dateKey = utcDateKey();

  await db
    .collection('leaderboard_daily')
    .doc(dateKey)
    .collection('entries')
    .doc(uid)
    .set(
      {
        uid,
        score: payload.totalScore,
        totalScore: payload.totalScore,
        streak: payload.streak,
        correctAnswers: payload.correctAnswers,
        totalAnswered: payload.totalAnswered,
        isAnonymous: !showInLeaderboard,
        cachedDisplayName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
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
      
      // Find user by email using Firebase Auth (authoritative user lookup)
      let userId: string;
      try {
        const userRecord = await admin.auth().getUserByEmail(email);
        userId = userRecord.uid;
      } catch (authError: any) {
        console.log(`User not found in Firebase Auth for email ${email}: ${authError.code}`);
        await updateRequestStatus(requestId, 'failed', 'User not found');
        await sendNotificationEmail(email, 'error', language, 'User account not found in our system');
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
  const finalTypes = shouldDeleteAll ? ['bookmarks', 'wird', 'settings'] : dataTypes;
  
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

/**
 * Process full account deletion requests (deletes all data + Firebase Auth user)
 * Triggered when a new document is added to account_deletion_requests collection
 */
export const processAccountDeletionRequest = functions.firestore
  .document('account_deletion_requests/{docId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = snap.id;
    const accountRequestsRef = snap.ref;

    const setStatus = (status: string, extra?: object) =>
      accountRequestsRef.update({
        status,
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...extra,
      });

    try {
      const { email, language } = requestData;
      console.log(`Processing account deletion request ${requestId} for ${email}`);

      if (!email || !email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
        await setStatus('failed', { errorMessage: 'Invalid email format' });
        return;
      }

      // Find user via Firebase Auth (authoritative lookup)
      let userRecord: admin.auth.UserRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
      } catch (authError: any) {
        console.log(`User not found for account deletion ${email}: ${authError.code}`);
        await setStatus('failed', { errorMessage: 'User not found' });
        await sendNotificationEmail(email, 'error', language,
          'User account not found in our system');
        return;
      }

      const userId = userRecord.uid;

      // Delete all Firestore subcollections (bookmarks, wird, settings)
      await deleteUserData(userId, ['all']);

      // Delete the root user Firestore document
      try {
        await db.collection('users').doc(userId).delete();
      } catch (e) {
        console.warn(`Could not delete root user document for ${userId}:`, e);
      }

      // Delete the Firebase Auth account (point of no return)
      await admin.auth().deleteUser(userId);

      await setStatus('completed', {
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send confirmation email
      const isArabic = language === 'ar';
      const subject = isArabic
        ? 'تأكيد: تم حذف حسابك بنجاح - نور الإيمان'
        : 'Confirmation: Your Account Has Been Deleted – Noor Al-Iman';
      const htmlContent = isArabic
        ? `<div style="direction:rtl;font-family:Arial,sans-serif;color:#333;max-width:600px;margin:0 auto;">
            <h2 style="color:#667eea;">السلام عليكم ورحمة الله وبركاته</h2>
            <p>تم حذف حسابك وجميع بياناتك بنجاح من تطبيق <strong>نور الإيمان</strong>.</p>
            <h3 style="color:#d32f2f;">ما تم حذفه:</h3>
            <ul>
              <li>حسابك في Firebase (لن تتمكن من تسجيل الدخول بهذا البريد الإلكتروني مجدداً)</li>
              <li>الإشارات المرجعية</li>
              <li>بيانات الورد اليومي</li>
              <li>الإعدادات الشخصية</li>
            </ul>
            <p style="margin-top:15px;">شكراً لك على استخدام تطبيق نور الإيمان. نسأل الله أن يتقبل منا ومنك.</p>
          </div>`
        : `<div style="font-family:Arial,sans-serif;color:#333;max-width:600px;margin:0 auto;">
            <h2 style="color:#667eea;">Hello,</h2>
            <p>Your account and all associated data have been <strong>permanently deleted</strong> from Noor Al-Iman.</p>
            <h3 style="color:#d32f2f;">What was deleted:</h3>
            <ul>
              <li>Your Firebase authentication account (you can no longer sign in with this email)</li>
              <li>All bookmarks</li>
              <li>Daily Wird data</li>
              <li>Personal settings</li>
            </ul>
            <p style="margin-top:15px;">Thank you for using Noor Al-Iman. May Allah accept from you.</p>
          </div>`;

      try {
        await transporter.sendMail({
          from: process.env.ADMIN_EMAIL || 'noreply@quran-app.com',
          to: email,
          subject,
          html: htmlContent,
        });
      } catch (mailError) {
        console.error(`Failed to send account deletion email to ${email}:`, mailError);
      }

      console.log(`Account deletion complete: request ${requestId}, uid ${userId}`);
    } catch (error) {
      console.error(`Error processing account deletion request ${requestId}:`, error);
      try {
        await setStatus('failed', {
          errorMessage: error instanceof Error ? error.message : 'Unknown error',
        });
      } catch (_) { /* best-effort */ }
    }
  });

export const mirrorQuizLeaderboardToDaily = functions.firestore
  .document('quiz_leaderboard/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid as string;
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;

    await upsertDailyLeaderboardEntry(uid, {
      totalScore: toNumber(after.totalScore),
      streak: toNumber(after.streak),
      correctAnswers: toNumber(after.correctAnswers),
      totalAnswered: toNumber(after.totalAnswered),
    });
  });

export const applyPendingLeaderboardVisibilityDaily = functions.pubsub
  .schedule('5 0 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const today = utcDateKey();
    const users = await db
      .collection('users')
      .where('showInLeaderboardPendingFrom', '<=', today)
      .get();

    if (users.empty) return null;

    const batch = db.batch();
    for (const doc of users.docs) {
      const data = doc.data();
      if (typeof data.showInLeaderboardPending === 'boolean') {
        batch.set(
          doc.ref,
          {
            showInLeaderboard: data.showInLeaderboardPending,
            showInLeaderboardPending: admin.firestore.FieldValue.delete(),
            showInLeaderboardPendingFrom: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }

    await batch.commit();
    return null;
  });
