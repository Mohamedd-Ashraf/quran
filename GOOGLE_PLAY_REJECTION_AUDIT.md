# Google Play Store — تقرير مراجعة الرفض الشامل
### تطبيق نور الإيمان | com.nooraliman.quran | v1.1.0+2015

> **تاريخ المراجعة:** 18 أبريل 2026  
> **الحالة العامة:** التطبيق سليم معماريًا لكن توجد **11 مشكلة** تحتاج معالجة قبل النشر

---

## 🔴 حرج — رفض تلقائي لو متحلوش (4 مشاكل)

---

### C1 — ملف `stream_blaze.py` فيه API Key مكشوف

**الملف:** `stream_blaze.py` (في جذر المشروع)

**المشكلة:**
ملف Python اختباري مكتوب فيه مباشرةً مفتاح API لخدمة BlazeAI:
```python
api_key="sk-blaze-OxwlQJtbCjqHzfOuBT8vbq1GJPKhqma6kIIkPI7Qf3VXuuZN"
```
لو الملف ده موجود في الـ repository ومتشالش من تاريخ الـ git، أي شخص يقدر يستخدم المفتاح ده.

**الخطر على Play Store:** مباشر — Google Play بيفحص الكود عشان يشوف مفاتيح API ظاهرة في APKs المرفوعة.

**الحل المطلوب:**
1. احذف الملف `stream_blaze.py` من الـ repo
2. احذفه من تاريخ git: `git filter-branch` أو `git filter-repo`
3. ألغِ (Revoke) المفتاح فورًا من حساب BlazeAI
4. أضف `*.py` للـ `.gitignore` الرئيسي

---

### C2 — `service-account.json` فيه مفتاح Firebase Admin خاص

**الملف:** `service-account.json` (في جذر المشروع)

**المشكلة:**
الملف ده بيحتوي على RSA Private Key لـ Firebase Admin SDK بالكامل. أي شخص يحصل عليه يقدر يقرأ ويكتب كل بيانات Firestore، يعمل users، يرسل notifications، وكل صلاحيات الـ Admin.

```json
{
  "type": "service_account",
  "project_id": "quraan-dd543",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n..."
}
```

**الحل المطلوب:**
1. امسح الملف من الـ repo (`git rm service-account.json`)
2. احذفه من تاريخ git
3. اذهب لـ Firebase Console → Project settings → Service accounts → وأعمل Revoke للـ key الحالي
4. ولّد key جديد فقط لما تحتاجه

> ملاحظة: الملف موجود أصلاً في `.gitignore` لكن ده مش كافي لو هو اتعمل له `git add` قبل كده.

---

### C3 — Play Console: لازم تملأ إعلان الـ Foreground Service

**المشكلة:**
التطبيق بيستخدم نوعين من الـ Foreground Services:
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — لتشغيل الأذان وصوت القرآن

لو ملقتش النموذج ده في Play Console قبل الرفع، هيتم الرفض التلقائي.

**الإجراء المطلوب (يدوي في Play Console):**
- اذهب إلى: Play Console → App content → Foreground service permissions
- الوثيقة الجاهزة للنص: [PLAY_CONSOLE_FGS_DECLARATION.md](PLAY_CONSOLE_FGS_DECLARATION.md)

**التفاصيل التقنية:**
```xml
<!-- AndroidManifest.xml -->
<service
    android:name=".AdhanPlayerService"
    android:foregroundServiceType="mediaPlayback" />

<service
    android:name=".PrayerTimesService"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="user_enabled_persistent_prayer_times_notification" />
</service>
```

---

### C4 — Play Console: لازم تملأ إعلان الأذونات الحساسة

**المشكلة:**
التطبيق بيستخدم أذونين حساسين يحتاجوا إعلان صريح في Play Console:

| الإذن | الاستخدام |
|-------|-----------|
| `SCHEDULE_EXACT_ALARM` | جدولة أذان الصلاة في وقتها بالضبط |
| `ACCESS_NOTIFICATION_POLICY` | تفعيل وضع الصامت تلقائيًا وقت الصلاة (DND) |

**الإجراء المطلوب (يدوي في Play Console):**
- اذهب إلى: Play Console → App content → Sensitive permissions declarations
- الوثيقة الجاهزة للنص: [PLAY_CONSOLE_SENSITIVE_PERMISSIONS_DECLARATION.md](PLAY_CONSOLE_SENSITIVE_PERMISSIONS_DECLARATION.md)

---

## 🟠 عالي — ممكن يسبب تأخير أو طلب توضيح (4 مشاكل)

---

### H1 — HTTP (Cleartext) Traffic مسموح لـ 4 دومينات

**الملف:** `android/app/src/main/res/xml/network_security_config.xml`

**المشكلة:**
جوجل بلاي بيشيل التطبيقات اللي بتسمح بـ HTTP غير مشفر. حاليًا التطبيق بيسمح بـ cleartext لـ:
```xml
<domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="true">sec.gov.eg</domain>
    <domain includeSubdomains="true">quranradio.eg</domain>
    <domain includeSubdomains="true">radiojar.com</domain>
    <domain includeSubdomains="true">radioways.com</domain>
</domain-config>
```

**الأسباب:** هذه دومينات بث إذاعي قديمة بعضها لا يدعم HTTPS.

**البديل الأفضل:**
- اتصل بـ streaming providers وتحقق من توافر HTTPS — بعضها بيدعمه
- لو مش متاح: وثّق في Play Console submission notes إن هذه endpoints للبث الصوتي المباشر (live radio streaming) وليس للبيانات الحساسة

---

### H2 — مفيش Terms of Service (شروط الاستخدام)

**المشكلة:**
سياسة الخصوصية (`public/privacy.html`) موجودة وممتازة، لكن مفيش Terms of Service أو EULA.

**الحل المطلوب:** أنشئ `public/terms.html` يغطي:
- حقوق الاستخدام والقيود
- إخلاء مسؤولية دقة مواقيت الصلاة
- إخلاء مسؤولية المحتوى الإسلامي (الترجمات والتفسيرات)
- حدود المسؤولية القانونية
- أضف rewrite في `firebase.json` للـ path `/terms`
- أضف رابط له في `public/privacy.html`

---

### H3 — تعارض رقم الإصدار في update-config.json

**الملف:** `assets/update-config.json`

**المشكلة:**
```json
{ "latestVersion": "1.0.11" }   ← في الملف
```
```yaml
version: 1.1.0+2015              ← في pubspec.yaml
```

الإصدار المنشور هو `1.1.0` لكن الملف بيقول `1.0.11`. هذا يسبب:
- مشكلة في آلية التحديث (المستخدمين مش هيعرفوا إن في تحديث)
- مخالفة للسياسة لو الـ minimum version أكتر من الـ latest version

**الحل:** ✅ تم التعديل تلقائيًا — `latestVersion` و `changelog` محدّثين لـ `1.1.0`

---

### H4 — Data Safety Questionnaire لازم يتملأ بدقة في Play Console

**المشكلة:** إعلان البيانات في Play Console لازم يطابق ما بيجمعه التطبيق فعلًا.

**البيانات المجموعة فعليًا:**

| نوع البيانات | الغرض | مشارك مع طرف ثالث؟ |
|-------------|-------|---------------------|
| الموقع الجغرافي (coarse) | حساب مواقيت الصلاة واتجاه القبلة | لا |
| اسم وإيميل Google | تسجيل الدخول | لا (Google OAuth فقط) |
| Bookmarks / Wird / Settings | المزامنة السحابية عبر Firestore | لا |

**الإجراء المطلوب (يدوي في Play Console):**
- Play Console → App content → Data safety
- رابط حذف البيانات: `https://quraan-dd543.web.app/data-deletion-request`
- رابط سياسة الخصوصية: `https://quraan-dd543.web.app/privacy`

---

## 🟡 متوسط — يُفضل يتحل قبل النشر (3 مشاكل)

---

### M1 — الأذان ممكن يشتغل فوق المكالمة على بعض الأجهزة

**الملف:** `android/app/src/main/kotlin/com/nooraliman/quran/AdhanPlayerService.kt`

**المشكلة:**
الكود الحالي بيتجاهل `AUDIOFOCUS_LOSS_TRANSIENT`:
```kotlin
AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
    Log.d(TAG, "Transient focus loss — ignored, adhan continues")
    // ← لا يوقف الأذان
}
```

بعض الأجهزة (Samsung / Xiaomi) بيبعتوا `TRANSIENT_LOSS` بدل `LOSS` عند إستلام مكالمة، فالأذان بيشتغل فوق المكالمة.

**البديل الأفضل:**
```kotlin
AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
    val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
    if (tm?.callState != TelephonyManager.CALL_STATE_IDLE) {
        stopAdhan()  // وقّف الأذان لو في مكالمة
    }
}
```

---

### M2 — `google-services.json` مش في الـ .gitignore الرئيسي

**الملف:** `.gitignore` (جذر المشروع)

**المشكلة:**
`google-services.json` بيحتوي على OAuth client IDs وإعدادات Firebase. مش لازم يكون في version control.

**الحل:** ✅ تم إضافة `**/google-services.json` للـ `.gitignore` تلقائيًا

---

### M3 — تحقق من Target SDK Version

**الملف:** `android/app/build.gradle.kts`

**المشكلة:**
الـ build بيستخدم `flutter.targetSdkVersion` (مش مثبّت hardcoded). جوجل بلاي بيطلب API 34+ في 2025.

**التحقق:**
```
الإصدار الحالي من Flutter: محدّد في E:\flutter
targetSdkVersion: مُستخلص من SDK تلقائيًا
```

**الإجراء:** تأكد إن Flutter SDK المستخدم بيحدد targetSdk = 34 أو أعلى. افحص في `build/app/outputs/apk/` بعد البناء أو شوف `flutter doctor`.

---

## ✅ ممتاز — لا يحتاج تعديل

| المجال | الملف | الحالة |
|--------|-------|--------|
| سياسة الخصوصية | `public/privacy.html` | ✅ ثنائية اللغة، شاملة |
| حذف البيانات | `public/data-deletion-request.html` | ✅ نموذج كامل + Cloud Functions |
| حذف الحساب | `lib/features/auth/presentation/cubit/auth_cubit.dart` | ✅ داخل التطبيق + ويب |
| قواعد Firestore | `firestore.rules` | ✅ عزل المستخدمين + anti-cheat |
| الـ Boot Receivers | `AndroidManifest.xml` | ✅ كل الأنواع: BOOT + TIME_SET + TIMEZONE |
| الـ Foreground Services | `AndroidManifest.xml` | ✅ mediaPlayback + specialUse بـ property صحيح |
| الـ Backup Rules | `res/xml/backup_rules.xml` | ✅ FlutterSecureStorage مستثنى |
| ProGuard/R8 | `android/app/proguard-rules.pro` | ✅ يغطي Firebase, Credentials, ExoPlayer |
| Permission Flow | `lib/core/widgets/permission_flow_screen.dart` | ✅ UI لكل إذن مع شرح |
| بدون إعلانات | — | ✅ خالٍ من أي ad SDK |
| بدون Analytics | — | ✅ لا crash reporting ولا tracking |
| أصول المتجر | `play_store_assets/` | ✅ Screenshots, icon, feature graphic جاهزة |
| الخريطة | `lib/features/islamic/presentation/screens/qiblah_map_widget.dart` | ✅ خريطة بدون أسماء — لا توجد مشكلة |

---

## قائمة إجراءات Play Console (يدوية عند الرفع)

```
1. App content → Privacy policy URL:
   https://quraan-dd543.web.app/privacy

2. App content → Data safety:
   - Location: Coarse — for prayer times & Qibla (not shared)
   - Personal info (name/email): from Google Sign-In (not shared)
   - App activity (bookmarks, wird, settings): cloud sync (not shared)
   - Data deletion URL: https://quraan-dd543.web.app/data-deletion-request

3. App content → Foreground service permissions:
   - Type: mediaPlayback (Adhan audio + Quran background playback)
   - Type: specialUse — user_enabled_persistent_prayer_times_notification

4. App content → Sensitive permissions:
   - SCHEDULE_EXACT_ALARM: exact prayer time scheduling
   - ACCESS_NOTIFICATION_POLICY: silence phone during prayer (user-controlled)

5. Content rating → Complete IARC questionnaire:
   - Category: Education / Reference
   - Islamic/Religious educational content

6. Store listing → Category: Books & Reference

7. Target audience → All ages (no child-directed features)
```

---

## الملفات الحساسة — ملخص

| الملف | المشكلة | الإجراء |
|-------|---------|---------|
| `stream_blaze.py` | API Key مكشوف | ❌ احذف فورًا + ألغِ المفتاح |
| `service-account.json` | Firebase Admin Private Key | ❌ احذف + ألغِ + ولّد مفتاح جديد |
| `android/key.properties` | باسوردات الـ keystore | ✅ موجود في `.gitignore` |
| `android/app/google-services.json` | OAuth client IDs | ✅ تم إضافته للـ `.gitignore` |
