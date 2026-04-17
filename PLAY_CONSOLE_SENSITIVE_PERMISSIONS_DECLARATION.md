# Play Console Sensitive Permissions Declaration (Draft)

Last updated: 2026-04-16

## Scope

This draft covers sensitive Android permissions still used by the app:

- `SCHEDULE_EXACT_ALARM`
- `ACCESS_NOTIFICATION_POLICY`
- `POST_NOTIFICATIONS` (runtime permission UX)

Reference files:

- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/nooraliman/quran/MainActivity.kt
- android/app/src/main/kotlin/com/nooraliman/quran/AdhanAlarmReceiver.kt
- lib/features/islamic/presentation/screens/adhan_settings_screen.dart
- lib/features/islamic/presentation/screens/adhan_diagnostics_screen.dart

## 1) SCHEDULE_EXACT_ALARM

### Suggested declaration text (English)

The app schedules Islamic prayer-time alerts (Adhan) at exact real-world times.
Prayer alerts are time-sensitive, and delayed/inexact alarms can miss the valid
prayer window.

Exact alarm access is used only for this time-critical reminder function.

### Suggested declaration text (Arabic)

يستخدم التطبيق صلاحية المنبهات الدقيقة لتشغيل تنبيهات الأذان في أوقاتها الشرعية
بدقة. لأن التنبيه مرتبط بوقت محدد، فإن التأخير أو الجدولة غير الدقيقة قد يؤدي إلى
تفويت وقت التنبيه.

تُستخدم هذه الصلاحية فقط لوظيفة التذكير الزمني الحساس.

### Technical evidence

- Alarm scheduling uses `AlarmManager.setAlarmClock(...)` in `AdhanAlarmReceiver`.
- The app exposes a user-facing exact-alarm settings shortcut only when needed.

## 2) ACCESS_NOTIFICATION_POLICY

### Suggested declaration text (English)

This permission is used only for the optional "Silent During Prayer" feature.
When the user explicitly enables this feature, the app can temporarily switch
ringer mode during configured prayer windows and then restore the original mode.

The feature is optional and can be disabled at any time.

### Suggested declaration text (Arabic)

تُستخدم هذه الصلاحية فقط في ميزة "الصمت أثناء الصلاة" الاختيارية.
عند تفعيل المستخدم لهذه الميزة، يمكن للتطبيق تغيير وضع الرنين مؤقتًا خلال
النافذة المحددة ثم إعادة الوضع الأصلي تلقائيًا.

الميزة اختيارية ويمكن إيقافها في أي وقت.

### Technical evidence

- DND access is checked before enabling the feature.
- The UI explains this is feature-specific and optional.

## 3) POST_NOTIFICATIONS (runtime UX)

### Suggested review note (English)

Notification permission is requested using a best-effort runtime flow first.
If not granted, the app continues to function, while explaining that Adhan alert
delivery may be unreliable without notification permission.

The app offers settings navigation as an optional follow-up step.

### Suggested review note (Arabic)

يتم طلب صلاحية الإشعارات أولاً عبر مسار صلاحية وقت التشغيل.
إذا لم يمنحها المستخدم، يستمر التطبيق بالعمل مع توضيح أن موثوقية تنبيهات الأذان
قد تتأثر بدون هذه الصلاحية.

فتح الإعدادات يتم كخيار إضافي وليس كإجبار.

## Reviewer Validation Steps

1. Open Adhan settings and try enabling Adhan with notifications denied.
2. Confirm runtime permission request appears before app-settings fallback.
3. Open "Silent During Prayer" and verify DND permission prompt is optional and feature-scoped.
4. Open Diagnostics and verify permission action labels are explicit and non-coercive.
5. Verify removed permission:
   - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is not present in manifest.
