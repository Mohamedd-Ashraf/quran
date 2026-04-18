# دليل الخطوات اليدوية — Google Play Console
## تطبيق: نور الإيمان — قرآن وأذان (`com.nooraliman.quran`)

> **ابدأ من هنا:** افتح الـ Dashboard اللي في الصورة، ثم اتبع الخطوات بالترتيب.  
> كل خطوة فيها رابط مباشر أو مسار تنقل من اللوحة.

---

## ⚡ ترتيب الأولوية

| الأولوية | الخطوة | وقت تقريبي |
|----------|--------|-------------|
| 🔴 1 | Data Safety (أمان البيانات) | 15-20 دقيقة |
| 🔴 2 | Foreground Services Declaration | 5 دقائق |
| 🔴 3 | Sensitive Permissions Declaration | 5 دقائق |
| 🟡 4 | Privacy Policy في Store Listing | 2 دقائق |
| 🟡 5 | إلغاء مفتاح Firebase Admin القديم | 3 دقائق |
| 🟡 6 | إلغاء مفتاح BlazeAI القديم | 2 دقائق |

---

## 🔴 الخطوة 1 — Data Safety (أمان البيانات)

**لماذا؟** Google تطلب شفافية كاملة عن البيانات اللي تجمعها — رفض التطبيق إذا لم يُكتمل.

### التنقل:
```
Dashboard → القائمة اليسرى → (اسحب للأسفل) → Policy → Data safety
```

**رابط مباشر** (استبدل YOUR_APP_ID بـ ID التطبيق من الـ URL الحالي):
```
https://play.google.com/console/u/0/developers/YOUR_DEV_ID/app/YOUR_APP_ID/data-safety
```

### الإجابات الصحيحة:

#### القسم 1: Data Collection and Security
- **Does your app collect or share any of the required user data types?** → ✅ **Yes**
- **Is all of the user data collected by your app encrypted in transit?** → ✅ **Yes**
- **Do you provide a way for users to request that their data is deleted?** → ✅ **Yes**
  - URL: `https://quraan-dd543.web.app/data-deletion-request`

#### القسم 2: Data Types — Location
- ✅ اختر **"Approximate location"** (موقع تقريبي)
- **Collection:** Collected
- **Purpose:** App functionality (أوقات الصلاة واتجاه القبلة)
- **Is this data shared with third parties?** → ❌ **No**
- **Is this data required?** → ✅ **Yes — app functionality**

#### القسم 3: Data Types — Personal info
- ✅ اختر **"Name"** و **"Email address"**
- **Collection:** Collected
- **Purpose:** Account management
- **Shared?** → ❌ No (بس مع Firebase Auth — Google-owned، مش third party)
- **Required?** → No (optional — يقدر يستخدم بدون حساب)

#### القسم 4: Data Types — App activity
- ✅ اختر **"Other user-generated content"** (الآيات المحفوظة، الورد، الإشارات)
- **Collection:** Collected
- **Purpose:** App functionality (cloud sync)
- **Shared?** → ❌ No
- **Ephemeral?** → ❌ No (محفوظة في Firestore)

#### القسم 5: باقي الأنواع
- ❌ **لا تختار:** Health, Financial, Messages, Photos, Contacts
- ❌ Device identifiers — لا يُجمع

---

## 🔴 الخطوة 2 — Foreground Services Declaration

**لماذا؟** التطبيق يستخدم Foreground Services (أذان + تلاوة) — targetSdk=36 يعني Android 14+ requirements إجبارية.

### التنقل (من الصفحة الحالية في الصورة):
```
انت الآن على صفحة App content الصح ✅
1. اضغط على تاب "Need attention (1)" (مش "Actioned")
2. هتلاقي بند Foreground services هناك
3. اضغط "Manage" أو "Start declaration"
```

**رابط مباشر:**
```
https://play.google.com/console/app/app-content/foreground-services
```
> مسار الصفحة رسمياً: **Monitor and improve → App content** (مش Policy)

### ⚠️ مطلوب: فيديو لكل FGS type
Google تطلب رابط فيديو (YouTube أو أي رابط عام) يوضح خطوات تشغيل الـ feature.
- افتح الكاميرا على موبايلك، سجل 30 ثانية بتوضح:
  - `mediaPlayback`: افتح التطبيق → ادخل على تلاوة → اضغط play → اخرج من التطبيق (الصوت كمل)
  - `specialUse`: افتح إعدادات الأذان → شوف وقت صلاة → لما الأذان يشتغل
- ارفع الفيديو على YouTube (unlisted) واحتفظ بالرابط

### الحقول المطلوبة لكل FGS type:

**Type 1 — `TYPE_MEDIA_PLAYBACK` (أذان وتلاوة)**

| الحقل | ما تكتبه |
|-------|----------|
| Use case | **Media Playback** |
| Description | انسخ النص أدناه |
| User impact if deferred | انسخ النص أدناه |
| User impact if interrupted | انسخ النص أدناه |
| Video link | رابط الفيديو اللي سجلته |

```
Description:
This app plays the Adhan (Islamic call to prayer) at the five daily
prayer times using a foreground service of type mediaPlayback. It also
continues Quran recitation audio when the app moves to the background,
allowing users to listen while using other apps.

User impact if deferred (not starting immediately):
The Adhan would play late or not at all, causing users to miss the
prayer time notification. This is unacceptable for a religious app
where timing is spiritually significant.

User impact if interrupted (paused/restarted):
The Adhan audio would be cut off mid-play, providing a jarring
experience. Quran recitation would restart from the beginning instead
of resuming, disrupting the user's listening session.
```

---

## 🔴 الخطوة 3 — SCHEDULE_EXACT_ALARM و ACCESS_NOTIFICATION_POLICY

> ⚠️ **تصحيح مهم:** هاتان الإذنان **ليس لهما form منفصل في Play Console**.  
> Google تراجعهم تلقائياً أثناء مراجعة التطبيق بناءً على الـ manifest والكود.

### ما عليك فعله:

#### أ) `SCHEDULE_EXACT_ALARM` — إجراء في Play Console
لو ظهر بند في الـ App content يطلب منك تبرير هذه الإذن، اكتب:
```
Justification (English):
This permission schedules the Adhan (Islamic call to prayer) at exact 
pray times. Prayer times are calculated to the minute per the user's 
location. An inexact alarm (setWindow) would cause the Adhan to fire 
late, which is spiritually unacceptable. Alternative APIs (WorkManager, 
setWindow) were evaluated and rejected due to minimum 10-15 minute 
window constraints.
```

#### ب) `SCHEDULE_EXACT_ALARM` — تحقق من الكود (مطلوب)
بعد رفع الـ APK، تأكد أن الكود يفحص الصلاحية قبل الجدولة:
```kotlin
// في AdhanScheduler.kt
val alarmManager = context.getSystemService(AlarmManager::class.java)
if (alarmManager.canScheduleExactAlarms()) {
    alarmManager.setExactAndAllowWhileIdle(...)
} else {
    // fallback: اعرض للمستخدم طلب الإذن
    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
    context.startActivity(intent)
}
```
لو الكود مش بيعمل هذا الفحص، Google ممكن ترفض التطبيق.

#### ج) `ACCESS_NOTIFICATION_POLICY` — لا تحتاج إجراء
هذه الإذن تُمنح عند الطلب من المستخدم. Play Console لا يطلب form منفصل لها.

#### د) `USE_EXACT_ALARM` (بديل أفضل — اختياري)
تطبيقات المواقيت والمنبهات تستطيع استخدام `USE_EXACT_ALARM` بدلاً من `SCHEDULE_EXACT_ALARM`:
- **الميزة:** تُمنح تلقائياً عند التثبيت (مستخدم مش محتاج يوافق)
- **الشرط:** يجب الإعلان عنها في الـ manifest + Google تراجع التطبيق
- **الإضافة في manifest:**
```xml
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```
> تطبيقات أوقات الصلاة مؤهلة لهذا الإذن. لو أردت التبديل، راجعني.

---

## 🟡 الخطوة 4 — Privacy Policy في Store Listing

**لماذا؟** رابط Privacy Policy مطلوب في صفحة التطبيق على الـ Store.

### التنقل:
```
Dashboard → القائمة اليسرى → Grow users → Store presence → Main store listing
```

ثم scroll لأسفل لـ **"App details"** أو **"Privacy policy"**.

### القيم:
- **Privacy policy URL:** `https://quraan-dd543.web.app/privacy`
- **Terms of Service (إن طُلب):** `https://quraan-dd543.web.app/terms`

---

## 🟡 الخطوة 5 — إلغاء مفتاح Firebase Admin القديم

**لماذا؟** مفتاح `service-account.json` اتعمله commit قديم في git — لازم يتلغى.

### التنقل:
```
1. افتح: https://console.firebase.google.com/project/quraan-dd543/settings/serviceaccounts/adminsdk
2. (أو: Firebase Console → quraan-dd543 → ⚙️ Project settings → Service accounts)
3. شوف قائمة المفاتيح الموجودة
4. أي مفتاح تاريخه قبل النهاردة (18 أبريل 2026) → اضغط عليه → Delete key
```

> ⚠️ بعد الحذف، اعمل مفتاح جديد واحتفظ بيه في مكان آمن (مش في الـ repo).

---

## 🟡 الخطوة 6 — إلغاء مفتاح BlazeAI القديم

**لماذا؟** المفتاح `sk-blaze-OxwlQJtbCj...` اتحط في `stream_blaze.py` اللي اتعمله commit.

### التنقل:
```
1. افتح: https://blazeai.com (أو المنصة اللي اشتريت منها المفتاح)
2. Settings → API Keys
3. ابحث عن المفتاح اللي يبدأ بـ sk-blaze-OxwlQJt...
4. اضغط Revoke / Delete
5. اعمل مفتاح جديد لو محتاجه
```

---

## ✅ Checklist نهائي قبل النشر

```
□ Data Safety form مكتمل ومحفوظ
□ فيديو FGS مسجل ومرفوع على YouTube (unlisted)
□ Foreground Services (TYPE_MEDIA_PLAYBACK) declaration مكتمل
✅ canScheduleExactAlarms() check موجود في الكود (تم التحقق)
□ Privacy Policy URL محطوط في Store Listing
□ مفتاح Firebase Admin القديم متلغي
□ مفتاح BlazeAI القديم متلغي
□ APK/AAB جديد متبنيّ (flutter build appbundle --release)
□ Internal Testing release متقدم وموافق عليه
□ Need attention tab في App content فارغ (مفيش حاجة pending)
```

---

## 🔗 روابط مفيدة

| الصفحة | الرابط |
|--------|--------|
| Play Console — Apps | https://play.google.com/console/u/0/developers |
| Firebase Console | https://console.firebase.google.com/project/quraan-dd543 |
| Firebase Service Accounts | https://console.firebase.google.com/project/quraan-dd543/settings/serviceaccounts/adminsdk |
| Privacy Policy (الموقع) | https://quraan-dd543.web.app/privacy |
| Terms of Service (الموقع) | https://quraan-dd543.web.app/terms |
| Data Deletion (الموقع) | https://quraan-dd543.web.app/data-deletion-request |
| Play Policy Center | https://play.google.com/about/developer-content-policy/ |

---

> **ملاحظة:** لو Play Console طلب منك تحديد **target audience** أو **content rating** — الإجابة: 13+ (تطبيق ديني للعموم، محتوى قرآني فقط).
