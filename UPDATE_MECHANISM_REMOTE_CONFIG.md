# نظام التحديثات و Firebase Remote Config

## الملخص

التطبيق يستخدم نظامين للتحديثات:

1. **Firebase Remote Config** — يدير بيانات الإصدارات (أحدث نسخة، الحد الأدنى، سجل التغييرات، إلزامية التحديث)
2. **Google Play In-App Update API** — يتعامل مع التنزيل والتثبيت الفعلي عبر Google Play

## كيف يعمل النظام

```
بداية التطبيق
    ↓
تهيئة Remote Config (جلب القيم كل 12 ساعة)
    ↓
مقارنة النسخة الحالية مع latest_version و minimum_version
    ↓
إذا يوجد تحديث:
    ├── إلزامي → حظر التطبيق + تحديث فوري (Immediate Update)
    └── اختياري → إشعار + تحديث في الخلفية (Flexible Update)
```

## ملفات النظام الأساسية

| الملف | الوظيفة |
|-------|---------|
| `lib/core/services/app_update_service_firebase.dart` | الخدمة الرئيسية — يقرأ Remote Config ويتحقق من الإصدارات |
| `lib/core/services/app_update_manager.dart` | يتتبع تقدم التنزيل للشريط المستمر في الواجهة |
| `lib/core/models/app_update_info.dart` | نموذج البيانات مع مقارنة الإصدارات |
| `lib/core/widgets/app_update_dialog_premium.dart` | حوار التحديث — يدعم التنزيل في الخلفية والحظر الإلزامي |
| `firebase_remote_config_template.yaml` | قالب مفاتيح Remote Config |

## مفاتيح Remote Config

| المفتاح | النوع | الوظيفة |
|---------|-------|---------|
| `latest_version` | String | أحدث إصدار متاح (مثل `"1.0.11"`) |
| `minimum_version` | String | الحد الأدنى — المستخدمون تحته يُجبرون على التحديث |
| `is_mandatory` | Boolean | علامة إلزامية التحديث |
| `changelog_ar` | String | سجل التغييرات بالعربية |
| `changelog_en` | String | سجل التغييرات بالإنجليزية |
| `release_date` | String | تاريخ الإصدار |
| `enable_in_app_update` | Boolean | مفتاح تشغيل/إيقاف التحديث داخل التطبيق |

## ما الذي يقدمه Remote Config ولا يوفره in_app_update وحده؟

| الميزة | in_app_update فقط | مع Remote Config |
|--------|-------------------|------------------|
| اكتشاف وجود تحديث على Play Store | ✅ | ✅ |
| إجبار تحديث نسخة قديمة جداً (minimum_version) | ❌ | ✅ |
| التحكم بإلزامية التحديث عن بُعد | ❌ | ✅ |
| عرض سجل تغييرات ثنائي اللغة | ❌ | ✅ |
| إيقاف التحديثات عن بُعد في حالة مشكلة | ❌ | ✅ |

## هل يسبب Remote Config رفض من Google Play؟

**لا — الخطر منخفض جداً** للأسباب التالية:

1. **لا يوجد sideloading**: الكود يفرض أن روابط التحديث على Android تشير فقط إلى صفحة Play Store (`_sanitizeDownloadUrl`)
2. **يستخدم API الرسمي**: Google Play In-App Updates هو الآلية المعتمدة من Google
3. **Remote Config منتج Google**: استخدامه لبيانات الإصدار نمط شائع ومقبول
4. **لا يوجد تنفيذ كود عن بُعد**: Remote Config يرسل فقط نصوص وقيم boolean — لا feature flags ولا كود ديناميكي

## التوصية: هل نبقي Remote Config أم نلغيه؟

### ✅ أبقِه — للأسباب التالية:

1. **لا يوجد خطر رفض** — Remote Config منتج Google رسمي ولا يخالف سياسات Play Store
2. **ميزة `minimum_version` مهمة** — بدونها لا يمكنك إجبار مستخدمي النسخ القديمة على التحديث
3. **التحكم عن بُعد ضروري** — يمكنك إيقاف التحديثات أو جعلها إلزامية بدون نشر نسخة جديدة
4. **سجل التغييرات** — يعرض للمستخدم ما الجديد بالعربية والإنجليزية
5. **الاستخدام الحالي بسيط ونظيف** — مفاتيح بيانات فقط، لا feature flags معقدة

### إذا أردت تبسيطه:

- يمكنك حذف المفاتيح المهملة (`download_url_arm64_v8a`, `download_url_armeabi_v7a`, `download_url_x86_64`, `mandatory_update`, `use_in_app_update`)
- لكن لا تحذف Remote Config بالكامل — فائدته تفوق تكلفته
