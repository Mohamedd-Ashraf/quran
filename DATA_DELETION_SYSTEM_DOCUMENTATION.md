# نظام حذف البيانات - التوثيق الكامل
# Data Deletion System - Complete Documentation

---

## المحتويات / Contents

1. [نظرة عامة / Overview](#overview)
2. [العملية خطوة بخطوة / Step-by-Step Process](#process)
3. [مكونات النظام / System Components](#components)
4. [دليل النشر والإعداد / Deployment Guide](#deployment)
5. [مراقبة وتتبع الطلبات / Monitoring](#monitoring)
6. [استكشاف الأخطاء / Troubleshooting](#troubleshooting)

---

## <a id="overview"></a>نظرة عامة / Overview

يوفر هذا النظام للمستخدمين طريقة آمنة وشفافة لحذف بيانات محددة دون حذف الحساب بالكامل. النظام يضمن:

✅ **حذف موثوق**: حذف فعلي من Firestore  
✅ **تأكيد بريدي**: إشعارات تلقائية للمستخدم والمطور  
✅ **شفافية كاملة**: تسجيل كامل لكل طلب  
✅ **أمان عالي**: تحقق من الهوية عبر البريد الإلكتروني  

### الفرق بين حذف البيانات وحذف الحساب

| الميزة | حذف البيانات (**Data Deletion**) | حذف الحساب (**Account Deletion**) |
|--------|----------------------------------|-----------------------------------|
| الحساب | ✅ يبقى | ❌ يُحذف نهائياً |
| بيانات المستخدم | ⚙️ مختارة (جزئي) | ❌ كل شيء |
| البريد | ✅ يبقى نشطاً | ❌ محذوف |
| إعادة التفعيل | ✅ سهل | ❌ صعب جداً |

---

## <a id="process"></a>العملية خطوة بخطوة / Step-by-Step Process

### 1️⃣ المستخدم يطلب الحذف / User Requests Deletion

**المسار الكامل:**

```
التطبيق (Flutter)
    ↓
  إعدادات / Settings
    ↓
  إزالة بيانات / Request Data Deletion
    ↓
  فتح رابط الويب / Open Web Form
    ↓
https://quraan-dd543.web.app/data-deletion-request
```

**الصفحة توفر:**

- 🌐 نسخة عربية وإنجليزية
- ✉️ حقل بريد إلكتروني (مطلوب)
- ☑️ خيارات محددة للحذف:
  - الإشارات المرجعية (Bookmarks)
  - الورد اليومي (Daily Wird)
  - الإعدادات الشخصية (Personal Settings)
  - تاريخ التلاوة (Reading History)
  - حذف الكل (Delete All)
- 💬 تعليق اختياري (السبب)
- 🤖 حماية من الروبوتات (Honeypot field)

### 2️⃣ النموذج يُرسل البيانات / Form Submits Data

```javascript
await addDoc(collection(db, 'data_deletion_requests'), {
  email: 'user@example.com',
  dataTypes: ['bookmarks', 'history'],
  reason: 'أريد تنظيف بيانات قديمة',
  language: 'ar',
  source: 'public_data_deletion_form',
  status: 'pending',
  app: 'Quraan - Noor Al-Iman',
  clientTimestamp: new Date().toISOString(),
  userAgent: navigator.userAgent,
  createdAt: serverTimestamp()
});
```

**التخزين:** Firestore → `data_deletion_requests/{requestId}`

### 3️⃣ Cloud Function يستمع ويعالج / Cloud Function Processes

```typescript
// استدعاء يلقائي Triggered automatically
processDataDeletionRequest 
  .on('data_deletion_requests/{docId}').onCreate()
```

**الخطوات:**

```
[CREATE] document in data_deletion_requests
  ↓
[VALIDATE] email format & request data
  ↓
[FIND] user by email in /users collection
  ↓
[DELETE] specified data sections from user document
  ↓
[UPDATE] request status → 'completed'
  ↓
[EMAIL] send confirmation to user
  ↓
[EMAIL] send admin notification to developer
```

### 4️⃣ حذف البيانات الفعلي / Actual Data Deletion

| نوع البيانات | المسار | مثال |
|-----------|--------|-----|
| **Bookmarks** | `/users/{userId}/bookmarks/{docId}` | حذف جميع المرجعيات |
| **Wird** | `/users/{userId}/wird/{docId}` | حذف سجل الورد |
| **Settings** | تحديث `/users/{userId}` | إعادة تعيين الإعدادات |
| **History** | `/users/{userId}/readingHistory/{docId}` + `/users/{userId}/listeningHistory/{docId}` | حذف السجلات |

**مثال عملي:**

```firestore
// قبل الحذف / Before Deletion
users/user_123
  ├── email: "user@example.com"
  ├── profileData: { ... }
  ├── bookmarks (subcollection)
  │   ├── bookmark_1
  │   ├── bookmark_2
  │   └── bookmark_3
  └── readingHistory (subcollection)
      ├── session_1
      ├── session_2
      └── session_3

// بعد طلب حذف bookmarks و history
users/user_123
  ├── email: "user@example.com"
  ├── profileData: { ... }  ← unchanged
  ├── bookmarks (فارغ / empty)
  └── readingHistory (فارغ / empty)
```

### 5️⃣ تأكيد بريدي / Email Confirmations

#### أ) بريد للمستخدم / User Email

**الموضوع:** تأكيد: تم حذف بياناتك بنجاح

```
السلام عليكم ورحمة الله

تم استقبال طلب حذف البيانات وتم معالجته بنجاح.

البيانات المحذوفة:
- الإشارات المرجعية
- تاريخ التلاوة

ملاحظة: قد تستغرق بعض البيانات المخزنة مؤقتاً وقتاً إضافياً للحذف تماماً.

شكراً لك.
```

#### ب) بريد للمطور / Admin Email

**الموضوع:** [Data Deletion] Request {ID} - user@example.com

```
Data Deletion Request Notification

Request ID: data_deletion_requests/abc123xyz
User Email: user@example.com
Requested Types: bookmarks, history
Deleted Sections: bookmarks, history
User Reason: أريد تنظيف بيانات قديمة
Status: Completed
Processed At: 2026-04-16T10:30:45Z

Check Firebase Console for more details.
```

---

## <a id="components"></a>مكونات النظام / System Components

### 1. الصفحة العامة / Public Web Form
- **الملف:** `public/data-deletion-request.html`
- **URL:** `https://quraan-dd543.web.app/data-deletion-request`
- **الغرض:** واجهة مستخدم لإرسال طلبات الحذف
- **الأمان:** Honeypot, email validation, rate limiting (via Firestore rules)

### 2. قواعد Firestore / Firestore Rules
- **الملف:** `firestore.rules`
- **المجموعة:** `data_deletion_requests/{requestId}`
- **السماحات:**
  - ✅ **CREATE**: صفحة الويب العامة فقط
  - ❌ **READ/LIST/UPDATE/DELETE**: لا أحد من العملاء
  - ✅ **Cloud Functions**: لديهم حق الوصول الكامل (Admin SDK)

**القواعس:**
```firestore
match /data_deletion_requests/{requestId} {
  allow create: if 
    email is valid &&
    dataTypes is not empty &&
    reason.length <= 1000 &&
    status == 'pending' &&
    source == 'public_data_deletion_form';
  
  // read/list/update/delete implicitly denied
}
```

### 3. Cloud Functions
- **الملف:** `functions/src/index.ts`
- **الدالة الرئيسية:** `processDataDeletionRequest`
- **الحدث:** Firestore write trigger
- **المميزات:**
  - التحقق من صحة البريد
  - البحث عن المستخدم
  - حذف البيانات المحددة
  - إرسال رسائل بريد إلكترونية
  - تسجيل الحالة

**المراحل الداخلية:**

```typescript
1. onCreate(snap) {
     const { email, dataTypes, reason } = snap.data();
     
     // Validate email
     if (!isValidEmail(email)) {
       updateStatus('failed');
       return;
     }
     
     // Find user
     const user = await findUserByEmail(email);
     if (!user) {
       updateStatus('failed');
       return;
     }
     
     // Delete data
     const deleted = await deleteUserData(userId, dataTypes);
     
     // Update status
     updateStatus('completed', { deletedSections: deleted });
     
     // Send emails
     sendUserConfirmation(email, deleted);
     sendAdminNotification(email, dataTypes, deleted);
   }
```

### 4. التطبيق (Flutter)
- **الملف:** `lib/features/quran/presentation/screens/settings_screen.dart`
- **السطر:** ~2149
- **الدالة:** `_openDataDeletionRequest(context)`
- **الغرض:** فتح رابط الصفحة من قائمة الإعدادات

```dart
ListTile(
  title: Text('Request Data Deletion'),
  subtitle: Text('Delete specific data without account deletion'),
  onTap: () => _openDataDeletionRequest(context),
)
```

---

## <a id="deployment"></a>دليل النشر والإعداد / Deployment Guide

### الخطوة 1: تثبيت المتطلبات / Install Prerequisites

```bash
# تثبيت Firebase CLI
npm install -g firebase-tools

# التحقق من الإصدار
firebase --version
```

### الخطوة 2: إعداد متغيرات البيئة / Setup Environment Variables

**في المجلد `functions/`، أنشئ ملف `.env.local`:**

```bash
# Gmail Configuration
ADMIN_EMAIL=your-admin@gmail.com
ADMIN_EMAIL_PASSWORD=your-app-specific-password

# Firebase Configuration (يُملأ تلقائياً)
GCLOUD_PROJECT=quraan-dd543
```

**كيفية الحصول على Gmail App Password:**

1. اذهب إلى: https://myaccount.google.com/apppasswords
2. اختر **Mail** و **Windows Computer**
3. انسخ كلمة المرور 16 حرف
4. ألصقها في `.env.local`

### الخطوة 3: نشر Cloud Functions / Deploy Functions

```bash
# من مجلد المشروع الرئيسي
cd e:\Quraan\quraan

# التحقق من الإعدادات
firebase list

# اختبار محلي (اختياري)
cd functions
npm install
npm run serve

# النشر إلى الإنتاج
firebase deploy --only functions

# مراقبة السجلات
firebase functions:log
```

### الخطوة 4: التحقق من النشر / Verify Deployment

```bash
# الاتصال بـ Firebase
firebase functions:list

# يجب أن تظهر:
# ✓ processDataDeletionRequest (Firestore write trigger)
```

---

## <a id="monitoring"></a>مراقبة وتتبع الطلبات / Monitoring

### عرض جميع الطلبات في Firebase Console

1. اذهب إلى **Firebase Console**
2. **Firestore Database**
3. اختر المجموعة **`data_deletion_requests`**
4. يمكنك رؤية:
   - معرف الطلب
   - البريد الإلكتروني
   - الحالة (pending/completed/failed)
   - وقت الإنشاء
   - الأقسام المحذوفة

### الحالات الممكنة / Possible Statuses

```
pending    → تم الاستقبال، في انتظار المعالجة
completed  → تم حذف البيانات بنجاح
failed     → فشلت المعالجة (خطأ في البريد، مستخدم غير موجود، إلخ)
```

### استعلام باستخدام CLI

```bash
firebase firestore:list data_deletion_requests

# عرض طلب محدد
firebase firestore:show data_deletion_requests/{requestId}

# تصفية الطلبات غير المكتملة
firebase firestore:query \
  "data_deletion_requests" \
  --filter-compare-value="pending" \
  --filter-field-path="status"
```

### السجلات / Logs

```bash
# عرض آخر 100 سجل
firebase functions:log

# عرض السجلات للـ 24 ساعة الأخيرة
firebase functions:log --limit=1000

# البحث عن أخطاء
firebase functions:log | grep -i "error"
```

---

## <a id="troubleshooting"></a>استكشاف الأخطاء / Troubleshooting

### المشكلة 1: الطلب معلق في حالة "pending"

**الأسباب المحتملة:**
- Cloud Function لم يتم نشره
- الدالة لا تعمل (خطأ في الكود)
- مشكلة في اتصال البيانات

**الحل:**

```bash
# تحقق من حالة الدالة
firebase functions:list

# اعرض السجلات
firebase functions:log

# أعد نشر الدالة
firebase deploy --only functions
```

### المشكلة 2: الطلب يفشل مع الخطأ "User not found"

**السبب:**
- البريد الإلكتروني المدخل لا يطابق المسجل

**الحل:**
- اطلب من المستخدم إدخال البريد نفسه المسجل في الحساب
- تحقق من Firestore أن المستخدم موجود

```firestore
// في Firestore Console
users/
  └── ...
      └── email: user@example.com  ← يجب أن يتطابق تماماً
```

### المشكلة 3: رسائل البريد لا تُرسل

**الأسباب:**
- متغيرات البيئة خاطئة
- Gmail App Password غير صحيح
- حساب Gmail لم يتم تفعيل الوصول

**الحل:**

```bash
# تحقق من المتغيرات
cat functions/.env.local

# أعد إنشاء Gmail App Password
# واتبع الخطوات في "Deployment Guide" أعلاه

# اختبر الإرسال يدويًا (Python)
python -c "
import smtplib
server = smtplib.SMTP('smtp.gmail.com', 587)
server.starttls()
server.login('your-email@gmail.com', 'your-app-password')
print('✓ تم الاتصال بنجاح')
"
```

### المشكلة 4: بيانات المستخدم لم تُحذف

**التحقق:**

```firestore
// قبل الحذف
users/user_id/bookmarks/
  ├── bookmark_1 ✓
  ├── bookmark_2 ✓
  └── bookmark_3 ✓

// بعد الحذف (يجب أن تكون فارغة)
users/user_id/bookmarks/
  ├── (خالي)
```

**الحل:**

1. تحقق من السجلات لأخطاء الحذف
2. تأكد من صحة هيكل البيانات
3. قد تحتاج إلى حذف يدوي من Firebase Console (في حالات الطوارئ)

---

## أمثلة عملية / Practical Examples

### مثال 1: طلب حذف كامل البيانات

**المدخلات:**
```json
{
  "email": "ahmed@example.com",
  "dataTypes": ["all"],
  "reason": "أريد الحذف النهائي",
  "language": "ar"
}
```

**النتيجة:**
- ❌ جميع الإشارات المرجعية محذوفة
- ❌ كل الورد اليومي محذوف
- ❌ الإعدادات أُعيدت
- ❌ السجلات محذوفة
- ✅ البريد والحساب يبقيان

### مثال 2: طلب حذف جزئي

**المدخلات:**
```json
{
  "email": "fatima@example.com",
  "dataTypes": ["history"],
  "reason": "",
  "language": "ar"
}
```

**النتيجة:**
- ✅ الإشارات المرجعية تبقى
- ✅ الورد اليومي يبقى
- ✅ الإعدادات تبقى
- ❌ فقط السجلات محذوفة

---

## الخلاصة / Summary

| المرحلة | المدة | الحالة |
|--------|------|--------|
| استقبال الطلب | لحظات | automated |
| معالجة الطلب | ثواني | Cloud Function |
| حذف البيانات | ثواني | Database |
| إرسال البريد | 1-5 دقائق | إرسال بريدي |
| **المجموع** | **< 5 دقائق** | ✅ مكتمل |

---

## المراجع / References

- [Firebase Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Cloud Functions for Firebase](https://firebase.google.com/docs/functions)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Nodemailer Documentation](https://nodemailer.com/)

---

**آخر تحديث:** 2026-04-16  
**الإصدار:** 1.0  
**الحالة:** 🟢 مستعد للنشر
