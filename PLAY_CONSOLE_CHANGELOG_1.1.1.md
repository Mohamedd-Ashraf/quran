# ملاحظات إصدار 1.1.1 – Google Play Console

> الحد الأقصى لحقل "ما الجديد" في Play Console هو **500 حرف** لكل لغة.
> انسخ النصوص أدناه مباشرةً إلى الحقل المناسب.

---

## العربية (ar) — انسخ النص التالي:

```
🌟 الجديد في نور الإيمان 1.1.1:
• أداة التقويم الهجري الشهرية على الشاشة الرئيسية
• توسعة مكتبة الأذكار بأقسام جديدة (الوضوء، الاستخارة، القنوت والمزيد)
• دعم القراءات العشر والروايات في التلاوة الصوتية
• تحديد نقطة بداية الورد اليومي في القرآن
• التحدي اليومي يحفظ إجابتك بدون إنترنت
• إشعار الأذان يفتح شاشة مواقيت الصلاة مباشرة
• إصلاحات وتحسينات عامة في الأداء
```

---

## English (en-US) — Copy the following:

```
🌟 What's New in Noor Al-Iman 1.1.1:
• Monthly Hijri Calendar home-screen widget
• Expanded adhkar library with new sections (Wudu, Istikhara, Qunut & more)
• Ten Qira'at & recitation variants support in audio playback
• Set a custom starting point for your daily Wird
• Daily Challenge saves answers offline and syncs when connected
• Adhan notification opens Prayer Times directly
• Bug fixes and general performance improvements
```

---

## ملاحظات للناشر

| الملف | التغيير |
|-------|---------|
| `pubspec.yaml` | `version: 1.1.1+2022` |
| `whats_new_screen.dart` | تم دمج 1.0.11-1.0.13 في مدخل `'1.1.1'` واحد (8 بطاقات) |
| `CHANGELOG.md` | أُضيفت فقرة [1.1.1] ثنائية اللغة |
| `firebase_remote_config_template.yaml` | `latest_version: "1.1.1"` + changelog محدّث |
| `assets/update-config.json` | `latestVersion: "1.1.1"` + إصلاح خطأ الفاصلة المفقودة + changelog محدّث |
