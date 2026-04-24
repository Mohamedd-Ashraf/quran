# ملاحظات إصدار 1.1.2 – Google Play Console

> الحد الأقصى لحقل "ما الجديد" في Play Console هو **500 حرف** لكل لغة.
> انسخ النصوص أدناه مباشرةً إلى الحقل المناسب.

---

## العربية (ar) — انسخ النص التالي:

```
✨ الجديد في نور الإيمان 1.1.2:
• الخصوصية على لوحة المتصدرين (إخفاء صفحتك)
• خدمة القراء المفضلين للوصول السريع
• تحسينات التلاوة الصوتية ومعالجة الأخطاء
• أدوات تغيير حجم خط التفسير
• نظام إرسال الملاحظات والمقترحات
• تحسين اختيار القارئ في صفحة المصحف
• إصلاحات وتحسينات عامة في الأداء
```

---

## English (en-US) — Copy the following:

```
✨ What's New in Noor Al-Iman 1.1.2:
• Leaderboard privacy (hide your profile)
• Favorite reciters service for quick access
• Improved audio recitation and error handling
• Tafsir font size controls
• Feedback submission system
• Improved reciter selection in Mushaf page
• General fixes and performance improvements
```

---

## ملاحظات للناشر

| الملف | التغيير |
|-------|---------|
| `pubspec.yaml` | `version: 1.1.2+2022` |
| `whats_new_screen.dart` | أُضيفت فقرة `'1.1.2'` (7 بطاقات) |
| `CHANGELOG.md` | أُضيفت فقرة [1.1.2] ثنائية اللغة |
| `firebase_remote_config_template.yaml` | `latest_version: "1.1.2"` + changelog محدّث |
| `assets/update-config.json` | `latestVersion: "1.1.2"` + changelog محدّث |