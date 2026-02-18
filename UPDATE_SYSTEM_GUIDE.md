# نظام تحديث التطبيق / App Update System

## نظرة عامة / Overview

تم إضافة نظام متكامل لتحديث التطبيق يسمح لك بإشعار المستخدمين بالتحديثات الجديدة وإمكانية تحديد ما إذا كان التحديث إلزامياً أو اختيارياً.

An integrated app update system has been added that allows you to notify users of new updates and specify whether the update is mandatory or optional.

---

## المكونات / Components

### 1. **AppUpdateInfo Model** 
📁 `lib/core/models/app_update_info.dart`

نموذج البيانات الذي يحتوي على معلومات التحديث:
- `latestVersion`: آخر إصدار متاح
- `minimumVersion`: الحد الأدنى المطلوب من الإصدار
- `isMandatory`: هل التحديث إلزامي
- `downloadUrl`: رابط التحميل (Play Store / App Store)
- `changelogByLanguage`: التغييرات الجديدة بعدة لغات

### 2. **AppUpdateService**
📁 `lib/core/services/app_update_service.dart`

الخدمة المسؤولة عن:
- فحص التحديثات من الخادم
- مقارنة الإصدارات
- حفظ حالة التحديثات المتجاهلة
- التحكم في وتيرة الفحص

### 3. **AppUpdateDialog Widget**
📁 `lib/core/widgets/app_update_dialog.dart`

واجهة عرض التحديث التي تدعم:
- العربية والإنجليزية
- عرض التحديثات الإلزامية والاختيارية
- منع إغلاق النافذة للتحديثات الإلزامية
- عرض قائمة التغييرات

---

## كيفية الاستخدام / How to Use

### الخطوة 1: تحديث الـ Dependencies

قم بتشغيل الأمر التالي لتحديث المكتبات:

```bash
flutter pub get
```

### الخطوة 2: إنشاء ملف التحديث على الخادم

قم بإنشاء ملف `update-config.json` واستضافته على خادمك أو GitHub:

**مثال على الملف:**

```json
{
  "latestVersion": "1.1.0",
  "minimumVersion": "1.0.0",
  "isMandatory": false,
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.yourcompany.quraan",
  "releaseDate": "2026-02-18T00:00:00.000Z",
  "changelog": {
    "ar": "التحديثات الجديدة:\n• تحسينات في الأداء\n• إصلاح مشاكل الصوت",
    "en": "What's New:\n• Performance improvements\n• Audio fixes"
  }
}
```

### الخطوة 3: تحديث رابط الفحص

في ملف `lib/core/services/app_update_service.dart` line 12:

```dart
static const String _updateCheckUrl = 
    'https://YOUR-SERVER.com/update-config.json';
```

استبدل الرابط برابط ملف JSON الخاص بك.

**خيارات الاستضافة:**

#### أ) GitHub (مجاني)
1. أنشئ مستودع عام على GitHub
2. ارفع ملف `update-config.json`
3. استخدم رابط Raw:
   ```
   https://raw.githubusercontent.com/USERNAME/REPO/main/update-config.json
   ```

#### ب) Firebase Hosting
```
https://your-project.web.app/update-config.json
```

#### ج) خادمك الخاص
```
https://your-domain.com/api/update-config.json
```

### الخطوة 4: تحديث رابط التحميل

قم بتحديث `downloadUrl` في ملف JSON ليشير إلى:
- **Android**: `https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME`
- **iOS**: `https://apps.apple.com/app/idYOUR_APP_ID`

---

## سيناريوهات الاستخدام / Usage Scenarios

### 1. تحديث اختياري (Optional Update)

```json
{
  "latestVersion": "1.1.0",
  "minimumVersion": "1.0.0",
  "isMandatory": false,
  "downloadUrl": "..."
}
```

- المستخدم يمكنه اختيار "لاحقاً" وتجاهل التحديث
- سيتم فحص التحديث مرة كل 24 ساعة

### 2. تحديث إلزامي (Mandatory Update)

```json
{
  "latestVersion": "2.0.0",
  "minimumVersion": "2.0.0",
  "isMandatory": true,
  "downloadUrl": "..."
}
```

- المستخدم **يجب** أن يحدّث قبل الاستمرار
- لا يمكن إغلاق نافذة التحديث
- لا يوجد زر "لاحقاً"

### 3. فرض التحديث لإصدارات قديمة

```json
{
  "latestVersion": "2.5.0",
  "minimumVersion": "2.0.0",
  "isMandatory": false
}
```

- المستخدمون بإصدار أقل من 2.0.0 **يجب** أن يحدثوا
- المستخدمون بإصدار 2.0.0 أو أعلى يمكنهم التأجيل

---

## API Reference

### AppUpdateService Methods

```dart
// فحص التحديثات العادي (يحترم الفترة الزمنية)
Future<AppUpdateInfo?> checkForUpdate()

// فحص إجباري (يتجاهل الفترة الزمنية والتحديثات المتجاهلة)
Future<AppUpdateInfo?> forceCheckForUpdate()

// تجاهل إصدار معين
Future<void> skipVersion(String version)

// مسح الإصدارات المتجاهلة
Future<void> clearSkippedVersion()

// التحقق من ضرورة الفحص
Future<bool> shouldCheckForUpdate({Duration minInterval})
```

### عرض التحديث يدوياً

يمكنك إضافة زر في الإعدادات للتحقق من التحديثات يدوياً:

```dart
import 'package:quraan/core/services/app_update_service.dart';
import 'package:quraan/core/widgets/app_update_dialog.dart';
import 'package:quraan/core/di/injection_container.dart' as di;

// في الـ Widget الخاص بك
Future<void> _manualUpdateCheck() async {
  final updateService = di.sl<AppUpdateService>();
  final updateInfo = await updateService.forceCheckForUpdate();
  
  if (updateInfo != null && mounted) {
    AppUpdateDialog.show(
      context: context,
      updateInfo: updateInfo,
      updateService: updateService,
      languageCode: 'ar', // أو حسب لغة التطبيق
    );
  } else {
    // عرض رسالة "لا توجد تحديثات"
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أنت تستخدم أحدث إصدار')),
    );
  }
}
```

---

## الأمان / Security

⚠️ **ملاحظات مهمة:**

1. **HTTPS فقط**: استخدم روابط HTTPS لملف التحديث
2. **التحقق**: تأكد من صحة ملف JSON قبل رفعه
3. **النسخ الاحتياطي**: احتفظ بنسخة من ملف JSON في أكثر من مكان

---

## استكشاف الأخطاء / Troubleshooting

### المشكلة: التحديث لا يظهر

**الحلول:**
1. تحقق من رابط الـ API في `app_update_service.dart`
2. تأكد من صحة بنية ملف JSON
3. تحقق من الاتصال بالإنترنت
4. تأكد من مرور 24 ساعة من آخر فحص

### المشكلة: التحديث يظهر باستمرار

**الحل:**
- تأكد من أن `latestVersion` في JSON أحدث من `version` في `pubspec.yaml`

### المشكلة: الضغط على "تحديث" لا يفعل شيء

**الحل:**
- تحقق من صحة `downloadUrl` في ملف JSON
- تأكد من إضافة package `url_launcher` بشكل صحيح

---

## مثال كامل للتكامل

إضافة زر في شاشة الإعدادات:

```dart
ListTile(
  leading: const Icon(Icons.system_update),
  title: const Text('فحص التحديثات'),
  subtitle: const Text('البحث عن إصدار جديد'),
  onTap: () async {
    final updateService = di.sl<AppUpdateService>();
    
    // عرض مؤشر تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    final updateInfo = await updateService.forceCheckForUpdate();
    
    // إخفاء مؤشر التحميل
    if (mounted) Navigator.pop(context);
    
    if (updateInfo != null && mounted) {
      AppUpdateDialog.show(
        context: context,
        updateInfo: updateInfo,
        updateService: updateService,
        languageCode: 'ar',
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 أنت تستخدم أحدث إصدار'),
        ),
      );
    }
  },
),
```

---

## الخلاصة / Summary

✅ **تم إضافة:**
- نظام فحص تحديثات تلقائي
- دعم التحديثات الإلزامية والاختيارية
- واجهة عربية/إنجليزية
- نظام تخزين مؤقت للفحوصات
- إمكانية تجاهل التحديثات الاختيارية

📝 **الخطوات التالية:**
1. تحديث رابط الـ API في `app_update_service.dart`
2. رفع ملف `update-config.json` على خادمك
3. تحديث رابط التحميل في JSON
4. اختبار النظام قبل النشر

---

بالتوفيق! 🚀
Good luck! 🚀
