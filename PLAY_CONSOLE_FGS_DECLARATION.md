# Play Console FGS Declaration (Draft)

Last updated: 2026-04-16

## Scope

This draft is for the optional prayer-times foreground notification implemented by:

- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/nooraliman/quran/PrayerTimesService.kt
- lib/features/islamic/presentation/screens/adhan_settings_screen.dart

## Foreground Service Type

- Type: `specialUse`
- Subtype (manifest property): `user_enabled_persistent_prayer_times_notification`

## Suggested Declaration Text (English)

Our app provides an optional, user-enabled persistent prayer-times notification.
When enabled by the user from in-app settings, a foreground service displays the
next prayer and remaining time in real time.

This service is not used for data sync, file transfer, or hidden background work.
It is purely user-visible religious reminder functionality.

Users can disable it at any time from:

- In-app settings toggle (Persistent Prayer Times)
- Notification action button (Stop)

If disabled, scheduled prayer alarms and regular reminders still work, but the
live persistent countdown notification is not shown.

## Suggested Declaration Text (Arabic)

يوفر التطبيق إشعارًا ثابتًا اختياريًا لمواقيت الصلاة، ويتم تفعيله فقط إذا قام
المستخدم بتشغيله من الإعدادات داخل التطبيق. عند التفعيل، تعرض خدمة أمامية
الصلاة القادمة والوقت المتبقي بشكل مرئي للمستخدم.

هذه الخدمة لا تُستخدم لمزامنة البيانات أو نقل الملفات أو أي نشاط خفي في الخلفية،
وإنما لوظيفة تذكير ديني ظاهرة للمستخدم فقط.

يمكن للمستخدم إيقافها في أي وقت عبر:

- مفتاح الإعداد داخل التطبيق
- زر "إيقاف" الموجود داخل الإشعار

عند الإيقاف، تظل منبّهات الصلاة المجدولة والتنبيهات العادية تعمل، لكن الإشعار
الثابت للعدّ التنازلي لا يظهر.

## Submission Notes

- Keep the declaration wording aligned with the exact app behavior above.
- Do not describe this feature as data sync.
- Ensure screenshots in review material show:
  - the settings toggle
  - the notification with the Stop action
