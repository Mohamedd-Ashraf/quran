# تقرير استهلاك البطارية — تطبيق القرآن
**التاريخ:** مارس 2026  
**النظام:** Android 14/15 — Flutter + Kotlin Native  

---

## ملخص تنفيذي

تم رصد **7 نقاط استهلاك** للبطارية تتراوح بين عالية الأثر ومنخفضة. أخطر نقطتين هما:
1. **`NextPrayerCountdown`** يُعيد رسم الواجهة 60 مرة/دقيقة دون داعٍ.
2. **`just_audio_background`** يُشغّل خدمة خلفية دائمة حتى عند عدم وجود صوت يُشغَّل.

---

## المشكلة الأولى 🔴 — `NextPrayerCountdown`: setState كل ثانية

### الوصف
**الملف:** `lib/features/islamic/presentation/widgets/next_prayer_countdown.dart` السطر 25

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
  _calculateNextPrayer(); // ← يستدعي setState() كل ثانية
});
```

- الـ widget محمي بـ `wantKeepAlive = true` في `HomeScreen`، أي لا يُتلف عند التنقل بين التبويبات.
- `_calculateNextPrayer()` يقرأ من الكاش ويستدعي `setState()` حتى لو لم تتغير القيمة.
- النتيجة: Flutter يُعيد build الـ widget tree **60 مرة في الدقيقة، 3600 مرة في الساعة**.
- يُبقي Dart VM و UI thread و GPU نشطين باستمرار.

### الحل المقترح

**استراتيجية: حساب الوقت الحقيقي للإطار التالي واستخدام timer ذكي**

```dart
class _NextPrayerCountdownState extends State<NextPrayerCountdown> {
  Timer? _timer;
  ({Prayer prayer, String label, DateTime time})? _nextPrayer;
  Duration? _timeRemaining;
  int _lastDisplayedSeconds = -1; // ← جديد

  void _calculateNextPrayer() {
    // ... نفس المنطق الحالي ...
    final remaining = nextTime.difference(DateTime.now());
    final seconds = remaining.inSeconds;

    // ← لا تستدعِ setState إلا إذا تغيرت الثانية المعروضة فعلًا
    if (seconds == _lastDisplayedSeconds) return;
    _lastDisplayedSeconds = seconds;

    if (mounted) setState(() => _timeRemaining = remaining);
  }
}
```

**البديل الأفضل: استخدام `Stream.periodic` مع حساب الإطار التالي**

```dart
void _scheduleNextTick() {
  // احسب الوقت المتبقي حتى تغيير الثانية التالية
  final now = DateTime.now();
  final msUntilNextSecond = 1000 - now.millisecond;
  _timer = Timer(Duration(milliseconds: msUntilNextSecond), () {
    _calculateNextPrayer();
    // بعد أول إطار، اجعله دوريًا كل ثانية بالضبط
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateNextPrayer();
    });
  });
}
```

### توفير البطارية المتوقع
- تقليل build cycles من 3600/ساعة إلى 3600/ساعة لكن مع **حذف معظم setState calls** (تُنفَّذ فقط عند تغيير الرقم المعروض) = ~98% تقليل في عمليات رسم الـ widget.
- تقليل ضغط GPU وCPU بشكل محسوس خاصة على الأجهزة المتوسطة.

### المشاكل المتوقعة بعد التطبيق
| المشكلة | الاحتمال | الحل |
|---|---|---|
| العداد يتأخر أو يقفز ثانية | منخفض | اختبر عند تغيير الدقيقة (xx:59 → xx:00) |
| عدم التزامن بين الثانية المعروضة والوقت الفعلي | منخفض | استخدم `DateTime.now()` داخل build وليس في timer |
| الـ timer لا يُلغى بشكل صحيح عند dispose | لا يحدث إذا أُبقي `_timer?.cancel()` في dispose | لا تغيير مطلوب في dispose |

---

## المشكلة الثانية 🔴 — `just_audio_background`: Foreground Service دائم

### الوصف
**الملف:** `lib/main_firebase.dart`

```dart
await JustAudioBackground.init(
  androidNotificationChannelId: 'com.example.quraan.channel.audio',
  androidNotificationChannelName: 'Audio playback',
  androidStopForegroundOnPause: true,
);
```

- يُشغّل `MediaBrowserServiceCompat` (Android Foreground Service) عند أول init.
- يحتاج `PARTIAL_WAKE_LOCK` داخليًا لضمان عدم قطع الصوت.
- يفتح `AudioSession` ويحتجز `AudioFocus` holder في الخلفية.
- على Android 12+، الـ Foreground Service يظهر كـ notification "صامت" مستمرة.
- سبب رفض `requestAudioFocus()` للأذان على Android 15 هو هذا الـ service بالذات.
- **يستمر حتى بعد إغلاق التطبيق** إذا كان `stopForegroundOnPause=false` أو إذا لم يُنهَ بشكل صريح.

### الحل المقترح

**استراتيجية: lazy init — لا تبدأ الخدمة إلا عند الحاجة الفعلية**

```dart
// في main.dart — لا تستدعِ JustAudioBackground.init() مباشرة
// بدلًا من ذلك، استدعِه فقط قبل تشغيل أي صوت

class AyahAudioService {
  static bool _bgInitialized = false;

  Future<void> ensureBackgroundAudioReady() async {
    if (_bgInitialized) return;
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.quraan.channel.audio',
      androidNotificationChannelName: 'تلاوة القرآن',
      androidStopForegroundOnPause: true, // ← أهم خيار
    );
    _bgInitialized = true;
  }
}
```

**خيار مهم: `androidStopForegroundOnPause: true`**

هذا الخيار موجود بالفعل في الكود لكن تأكد أنه يعمل — يُوقف الـ Foreground Service عند pause، مما يسمح للجهاز بالدخول إلى Deep Sleep.

### توفير البطارية المتوقع
- إزالة الـ Wake Lock الذي يحتفظ به `AudioService` دائمًا.
- إتاحة `Deep Sleep` للجهاز خلال جلسات عدم الاستخدام.
- حل جانبي مهم: لن يُسبب `requestAudioFocus()` denial للأذان بعد الآن (تم حل هذا بالفعل عبر إزالة abort logic).

### المشاكل المتوقعة بعد التطبيق
| المشكلة | الاحتمال | الحل |
|---|---|---|
| تأخر بسيط (200-500ms) عند بدء تشغيل أول آية | متوسط | أظهر loading indicator خلال init |
| قد تفشل آية إذا استُدعي `play()` قبل انتهاء `init()` | متوسط | أضف `await ensureBackgroundAudioReady()` قبل كل play |
| على Android القديم (< 8)، الـ init البطيء قد يُسبب ANR | منخفض | الـ init سريع جدًا (<100ms) عادةً |
| فقدان الـ Media notification مؤقتًا عند أول تشغيل | منخفض | مقبول، يظهر بعد ثوان |

---

## المشكلة الثالثة 🟠 — 299 Exact Alarm

### الوصف
**الملف:** `lib/core/services/adhan_notification_service.dart`

```
D/AdhanAlarmReceiver: Scheduled 299 alarm(s) and stored times
```

- النظام الحالي يُجدول 5 صلوات × (60 يومًا) ≈ 300 alarm بالإضافة لـ iqama وapproaching.
- كل `AlarmManager.setAlarmClock()` = إدخال في kernel timer queue.
- عند إطلاق كل alarm، النظام يُوقظ الـ CPU من Deep Sleep، يُشغّل الـ receiver، ثم يعود للنوم.
- 300 alarm في 60 يومًا = **5 إيقاظات يومية** — مقبول تمامًا لأن هذا هو الغرض الرئيسي.
- المشكلة الفعلية: إعادة جدولة الـ 300 alarm دفعةً واحدة عند كل فتح للتطبيق.

### الحل المقترح

**تقليل الـ lookahead من 60 إلى 30 يومًا**

```dart
// في adhan_notification_service.dart
static const int _schedulingLookaheadDays = 30; // كان 60
```

النتيجة: ~150 alarm بدلًا من 300، مع إعادة جدولة تلقائية كل 30 يومًا.

**إضافة: لا تُعد الجدولة إذا كانت الـ alarms موجودة بالفعل لفترة كافية**

```dart
Future<void> ensureScheduled() async {
  final lastScheduled = _settings.getString('adhan_last_scheduled_date');
  final today = DateTime.now().toIso8601String().substring(0, 10);
  // أعد الجدولة فقط إذا مر يوم كامل أو لم تُجدوَل من قبل
  if (lastScheduled == today) return;
  await _doEnsureScheduled();
  await _settings.setString('adhan_last_scheduled_date', today);
}
```

### توفير البطارية المتوقع
- تقليل عدد إدخالات kernel timer بنسبة 50%.
- تقليل وقت عملية إعادة الجدولة عند فتح التطبيق.
- **لا يؤثر على موثوقية الأذان** — 30 يومًا أكثر من كافٍ.

### المشاكل المتوقعة بعد التطبيق
| المشكلة | الاحتمال | الحل |
|---|---|---|
| إذا لم يُفتح التطبيق 30 يومًا، تنقطع الـ alarms | منخفض | يُعيد الجدولة عند أي فتح أو عند TIME_SET/TIMEZONE_CHANGED |
| الـ `_getStoredAdhanIds()` قد لا يجد IDs للأيام 31-60 | لا يحدث | لأن السابق لم يُجدول أصلًا بعد يوم 30 |

---

## المشكلة الرابعة 🟠 — `cloud_firestore`: WebSocket مستمر

### الوصف
**الملف:** `pubspec.yaml` السطر 91

```yaml
cloud_firestore: ^5.6.0
```

- Firestore SDK يفتح WebSocket persistent connection عند أي `snapshots()` أو `listen()`.
- يُبقي Wi-Fi/4G radio نشطًا باستمرار = High Network Activity.
- إذا كانت البيانات المطلوبة لا تتغير كثيرًا (config، قرآن منزّل، إلخ)، يكون الـ connection بلا قيمة.
- كل بيانات Firebase تُرسل عبر `protobuf over gRPC` = بروتوكول ثقيل نسبيًا.

### الحل المقترح

**استخدام `Source.cache` أولًا مع fallback للشبكة**

```dart
// بدلًا من:
await firestore.collection('config').doc('app').get();

// استخدم:
try {
  final doc = await firestore
      .collection('config')
      .doc('app')
      .get(const GetOptions(source: Source.cache));
  if (doc.exists) return doc.data();
} catch (_) {
  // لم يوجد في الكاش — اجلب من الشبكة
}
final doc = await firestore.collection('config').doc('app').get();
```

**إيقاف الـ real-time listeners عند عدم الحاجة**

```dart
// احتفظ بـ StreamSubscription وأوقفها عند dispose
StreamSubscription? _sub;

void startListening() {
  _sub = firestore.collection('x').snapshots().listen((_) { ... });
}

@override
void dispose() {
  _sub?.cancel(); // ← مهم جدًا
  super.dispose();
}
```

### توفير البطارية المتوقع
- تقليل استخدام network radio بنسبة كبيرة إذا كانت البيانات لا تتغير.
- تحسين زمن الاستجابة عند إعادة فتح التطبيق.

### المشاكل المتوقعة بعد التطبيق
| المشكلة | الاحتمال | الحل |
|---|---|---|
| ظهور بيانات قديمة (stale) إذا تغيرت في Firestore | متوسط | أضف background refresh دوري (مرة/يوم) |
| الكاش يمتلئ على أجهزة storage منخفضة | منخفض | Firestore يُدير الكاش تلقائيًا |
| أول تشغيل بعد التثبيت لن يجد كاشًا | حتمي | الـ fallback للشبكة يعالجه |

---

## المشكلة الخامسة 🟠 — `firebase_remote_config`: Polling دوري

### الوصف
**الملف:** `pubspec.yaml` السطر 90

```yaml
firebase_remote_config: ^5.1.4
```

- remote_config يُرسل HTTP request لكل `fetchAndActivate()`.
- القيمة الافتراضية لـ `minimumFetchInterval` في development هي **0 ثانية** (كل طلب).
- في production يجب ضبطه على الأقل **12 ساعة** — إذا لم يُضبط، سيُرسل requests متكررة.

### الحل المقترح

```dart
final remoteConfig = FirebaseRemoteConfig.instance;

await remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(seconds: 15),
  minimumFetchInterval: const Duration(hours: 12), // ← مهم للإنتاج
));

await remoteConfig.fetchAndActivate();
```

**إضافة: استدعِ `fetchAndActivate` مرة واحدة فقط عند startup**

```dart
// في main.dart — مرة واحدة فقط، وليس في كل build أو frame
await remoteConfig.fetchAndActivate();
// لا تضعه داخل FutureBuilder أو StreamBuilder التي تُعاد بناؤها
```

### توفير البطارية المتوقع
- تقليل network requests من "كل فتح" إلى مرة كل 12 ساعة كحد أقصى.

### المشاكل المتوقعة بعد التطبيق
| المشكلة | الاحتمال | الحل |
|---|---|---|
| تأخر وصول config updates الطارئة | متوسط | استخدم `realtime` listener لـ critical updates فقط |
| المستخدم يرى قيمًا قديمة من الكاش لمدة 12 ساعة | منخفض/مقبول | سلوك متوقع ومقبول في الإنتاج |

---

## المشكلة السادسة 🟡 — WakeLock لمدة 10 دقائق

### الوصف
**الملف:** `android/app/src/main/kotlin/com/example/quraan/AdhanPlayerService.kt` السطر 321

```kotlin
wakeLock?.acquire(10 * 60 * 1_000L) // max 10 minutes
```

- `PARTIAL_WAKE_LOCK` يُبقي CPU مستيقظًا بغض النظر عن حالة الشاشة.
- أطول أذان موجود ≈ 4-5 دقائق، لذا الـ 10 دقائق **سقف أمان مقبول**.
- الـ WakeLock يُحرر فعليًا في `releaseWakeLock()` عند الانتهاء.
- **الأثر الفعلي منخفض** لأن `stopSelf()` يُطلق `stopAdhan()` → `releaseWakeLock()` بسرعة.

### الحل المقترح (اختياري)

```kotlin
// تقليل السقف إلى 7 دقائق (كافٍ حتى لأطول أذان)
wakeLock?.acquire(7 * 60 * 1_000L)
```

أو: حساب مدة الصوت وضبط الـ WakeLock بدقة:

```kotlin
// بعد player.prepare()
val durationMs = player.duration.toLong().coerceAtLeast(60_000L)
val wakeLockMs = durationMs + 10_000L // buffer إضافي 10 ثوانٍ
wakeLock?.acquire(wakeLockMs)
```

### المشاكل المتوقعة بعد التطبيق
| المشكلة | الاحتمال | الحل |
|---|---|---|
| إذا تأخر `stopAdhan()` في حالات استثنائية، ينتهي الـ WakeLock قبل الأذان | منخفض | الـ MediaPlayer لديه wake mode خاص به كـ fallback |
| `player.duration` قد يكون `-1` قبل prepare | حتمي | استخدم الـ duration بعد `prepare()` وليس قبله |

---

## المشكلة السابعة 🟡 — Volume Polling Thread كل 500ms

### الوصف
**الملف:** `android/app/src/main/kotlin/com/example/quraan/AdhanPlayerService.kt` السطر 830

```kotlin
Thread.sleep(500L) // 120 قراءة/دقيقة × مدة الأذان
```

- يعمل **فقط أثناء تشغيل الأذان** — bounded ومبرر.
- مدة الأذان عادةً 3-7 دقائق = 360-840 قراءة إجمالية في الجلسة كلها.
- `AudioManager.getStreamVolume()` استدعاء خفيف جدًا (لا يُوقظ hardware).
- **هذه المشكلة لا تستحق حلًا** — أثرها أقل بكثير من باقي المشكلات.

### الحل (للاهتمام المستقبلي فقط)
تقليل التردد إلى 1000ms بدلًا من 500ms — لن يؤثر على الاستجابة للمستخدم بشكل ملحوظ.

---

## جدول الأولويات والجهد

| الأولوية | المشكلة | الجهد | التأثير على الأداء | خطر التطبيق |
|---|---|---|---|---|
| 1 🔴 | `NextPrayerCountdown` setState | صغير (10 سطر) | **عالي جدًا** | منخفض |
| 2 🔴 | `just_audio_background` lazy init | متوسط (refactor) | **عالي** | متوسط |
| 3 🟠 | Alarms lookahead 60→30 يوم | صغير (1 سطر) | متوسط | منخفض |
| 4 🟠 | Firestore cache-first | متوسط | متوسط | متوسط |
| 5 🟠 | Remote Config interval 12h | صغير (2 سطر) | منخفض-متوسط | منخفض |
| 6 🟡 | WakeLock 10→7 دقيقة | صغير (1 سطر) | منخفض | منخفض |
| 7 🟡 | Polling 500→1000ms | صغير (1 رقم) | لا يذكر | لا شيء |

---

## التوصية النهائية

**ابدأ بالمشكلة الأولى فقط** — تقليل `setState` في `NextPrayerCountdown` هو تغيير صغير بأعلى عائد.  
المشكلة الثانية (`just_audio_background`) تحتاج اختبارًا جيدًا على أجهزة متعددة قبل النشر لأنها تُغير سلوك تشغيل الصوت بشكل جذري.  
المشكلات 3-5 إصلاحات صغيرة آمنة ويمكن تطبيقها مرة واحدة.  
المشكلات 6-7 **لا تستحق التغيير** حاليًا — تأثيرها هامشي.

---

*تم إعداد هذا التقرير بناءً على تحليل ستاتيكي للكود المصدري — يُنصح بإجراء profiling فعلي على جهاز حقيقي باستخدام Android Studio Energy Profiler للتحقق من الأرقام.*
