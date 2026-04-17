# Play Store Pre-Submission Audit

Last updated: 2026-04-17

## نتائج حرجة / عالية

### 1) حرج: مسار طلب حذف البيانات غير فعّال فعليًا

الحالة الآن: مكتمل تقنيًا وتوثيقيًا + Cloud Functions جاهزة للنشر

- كان النموذج لا يرسل الطلب لأي Backend ويكتفي بالتسجيل في Console. ✅ تم إصلاحه
- تم ربط النموذج فعليًا بـ Firestore وإضافة Rules مخصصة للإنشاء المقيّد. ✅ جاهز
- تم إضافة Cloud Functions المسؤولة عن معالجة الطلبات وحذف البيانات الفعلي. ✅ مكتمل
- تم إضافة نظام رسائل بريدية تلقائية للمستخدم والمطور. ✅ جاهز
- تم إضافة شاشة واضحة في التطبيق (Settings → Request Data Deletion). ✅ موجود
- يتبقى فقط نشر Cloud Functions في Firebase. ⏳ يدوي

**التفاصيل التقنية:**

- **الصفحة العامة:** `public/data-deletion-request.html` (HTML + Firebase SDK)
- **قواعد الأمان:** `firestore.rules` (Firestore Security Rules)
- **Cloud Functions:** `functions/src/index.ts` (TypeScript + Node.js)
  - دالة `processDataDeletionRequest` تستمع لـ `data_deletion_requests` collection
  - تتحقق من صحة البريد والطلب
  - تبحث عن المستخدم وتحذف البيانات المحددة
  - ترسل بريد تأكيد للمستخدم
  - ترسل تنبيه للمطور (Admin)
- **واجهة التطبيق:** `lib/features/quran/presentation/screens/settings_screen.dart` (سطر ~2149)
  - خيار "Request Data Deletion" في الإعدادات
  - يفتح الصفحة العامة في متصفح الويب

ملفات مرتبطة:

- public/data-deletion-request.html
- firestore.rules
- functions/src/index.ts (NEW)
- functions/package.json (NEW)
- functions/tsconfig.json (NEW)
- functions/.env.example (NEW)
- firebase.json (محدث)
- lib/features/quran/presentation/screens/settings_screen.dart
- DATA_DELETION_SYSTEM_DOCUMENTATION.md (NEW - شامل)

### 2) عالي: نظام التحديث يسمح بمصدر خارجي غير Play (حسب الإعداد)

الحالة الآن: مكتمل (تم تقليل الخطر بشكل مباشر)

- تم قفل مسار Android بحيث أي رابط تحديث غير Play Store يتم رفضه والتحويل إلى رابط Play الرسمي للتطبيق.
- Dialog التحديث على Android أصبح يفتح Play Store فقط (market:// أو رابط Play web) عند fallback.
- تم تحديث توثيق Remote Config ليؤكد أن Android يجب أن يستخدم Play Store فقط.

ملفات مرتبطة:

- lib/core/services/app_update_service_firebase.dart
- lib/core/widgets/app_update_dialog_premium.dart
- lib/core/widgets/app_update_dialog.dart
- firebase_remote_config_template.yaml

### 3) عالي: Foreground Service (تم تصحيح dataSync إلى specialUse)

الحالة الآن: مكتمل تقنيًا (يتبقى إعلان Play Console)

- تم استبدال النوع من dataSync إلى specialUse مع subtype واضح في AndroidManifest.
- تم إزالة سلوك الإجبار على عدم الإزالة (FLAG_NO_CLEAR) وإزالة إعادة التثبيت القسري بعد السحب.
- تم إضافة إجراء إيقاف مباشر من الإشعار نفسه لزيادة تحكم المستخدم.
- تم تجهيز مسودة نص إعلان Play Console في ملف PLAY_CONSOLE_FGS_DECLARATION.md.
- يتبقى فقط ملء إعلان Foreground Service في Play Console بنفس الوصف الفعلي.

ملفات مرتبطة:

- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/nooraliman/quran/PrayerTimesService.kt

## نتائج متوسطة

### 4) متوسط: أذونات حساسة تحتاج ضبط ممتاز في Play Console + UX واضح

الحالة الآن: مكتمل تقنيًا وتوثيقيًا (يتبقى الإدخال داخل Play Console)

- التصاريح الحساسة موجودة ومفهومة وظيفيًا، لكنها تحتاج صياغة دقيقة في Play Console.
- تجربة طلب الصلاحيات تم تحسينها لتكون أوضح وأقل إلزامًا (Runtime أولًا ثم Settings كخيار).
- تم إزالة صلاحية `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` من AndroidManifest.
- تم تعديل التدفق ليكتفي بفتح إعدادات البطارية العامة بدون طلب إعفاء مباشر داخل التطبيق.
- تم تجهيز نصوص Play Console الجاهزة للصلاحيات الحساسة في `PLAY_CONSOLE_SENSITIVE_PERMISSIONS_DECLARATION.md`.

ملفات مرتبطة:

- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/nooraliman/quran/MainActivity.kt
- lib/features/islamic/presentation/screens/adhan_settings_screen.dart
- lib/features/islamic/presentation/screens/adhan_diagnostics_screen.dart
- PLAY_CONSOLE_SENSITIVE_PERMISSIONS_DECLARATION.md

## نقاط مطمئنة

- لا توجد مؤشرات على أذونات شديدة الخطورة المعتادة للرفض مثل:
  - MANAGE_EXTERNAL_STORAGE
  - QUERY_ALL_PACKAGES
  - REQUEST_INSTALL_PACKAGES
- targetSdk محدث ومناسب للرفع الحالي.

## نتائج المراجعة الشاملة (2026-04-17)

### 5) متوسط: Cloud Function — حد Batch و XSS و HTML

الحالة الآن: ✅ تم إصلاحه

- **باج حرج:** Firestore batch كان بلا حد — لو المستخدم عنده أكتر من 500 document، الحذف كان هيفشل. تم تقسيم العمليات لـ chunked batches (حد 499 لكل batch).
- **XSS:** حقل `reason` في إيميل الأدمن كان بيتحط بدون escaping — ممكن حقن HTML. تم إضافة `escapeHtml()`.
- **HTML:** عناصر القائمة في إيميل التأكيد كانت بدون `<li>` tags داخل `<ul>`. تم الإصلاح.
- **TypeScript:** تمت إضافة `@types/nodemailer` للـ devDependencies.

ملفات معدّلة:
- functions/src/index.ts
- functions/package.json

### 6) متوسط: إعدادات النسخ الاحتياطي (Backup) غير محددة

الحالة الآن: ✅ تم إصلاحه

- `android:allowBackup` لم يكن محدد صراحةً في AndroidManifest — Android يفعّله افتراضياً بدون ضوابط.
- تم إضافة `android:allowBackup="true"` مع `backup_rules.xml` (API 23-30) و `data_extraction_rules.xml` (API 31+).
- البيانات الحساسة (FlutterSecureStorage) مستبعدة من النسخ الاحتياطي.
- Cache والملفات الخارجية مستبعدة.

ملفات جديدة/معدّلة:
- android/app/src/main/AndroidManifest.xml (محدث)
- android/app/src/main/res/xml/backup_rules.xml (جديد)
- android/app/src/main/res/xml/data_extraction_rules.xml (جديد)

### 7) منخفض: ملفات حساسة في مجلد المشروع

الحالة: ⚠️ يحتاج مراجعة يدوية

- `service-account.json` (Firebase Admin SDK private key) موجود في root المشروع — مش متعمله commit بس وجوده خطر.
- `android/key.properties` فيه كلمات سر التوقيع بنص واضح — مش متعمله commit بس الأفضل استخدام environment variables.
- **التوصية:** نقل `service-account.json` خارج مجلد المشروع أو استخدام Secret Manager.

### 8) منخفض: بث إذاعة القرآن عبر HTTP

الحالة: ℹ️ مقبول — لا يحتاج إجراء

- بعض روابط إذاعة القرآن تستخدم HTTP (مش HTTPS) لأن المصادر الخارجية لا توفر HTTPS.
- `network_security_config.xml` يسمح بـ cleartext فقط للدومينات المحددة (sec.gov.eg, radiojar.com, etc).
- لا يتم إرسال بيانات مستخدم حساسة عبر هذه الاتصالات.

## الخلاصة العملية قبل الرفع

- [x] توصيل صفحة حذف البيانات بـ Backend فعلي (Firestore + Cloud Functions).
- [x] إغلاق احتمال APK خارجي على Android وجعل fallback إلى Play Store فقط.
- [x] مراجعة توصيف Foreground Service (خصوصًا dataSync) وسلوك الإشعار الدائم.
- [x] رفع Play Console declarations (الصياغات جاهزة في PLAY_CONSOLE_GUIDE_AR.md + PLAY_CONSOLE_FGS_DECLARATION.md + PLAY_CONSOLE_SENSITIVE_PERMISSIONS_DECLARATION.md).
- [ ] نشر Cloud Functions (تشغيل `firebase deploy --only functions` من المجلد الرئيسي)

### النقطة الأخيرة: نشر Cloud Functions

**الأمر:**
```bash
cd e:\Quraan\quraan
firebase deploy --only functions
```

**المتوقع:**
```
✓ functions deployed successfully
✓ data-deletion-requests collection is now monitored
✓ Email notifications will start working automatically
```
