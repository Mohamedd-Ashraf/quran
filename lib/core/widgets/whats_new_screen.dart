import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_colors.dart';
import '../settings/app_settings_cubit.dart';
import '../services/whats_new_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single "change" entry
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsNewEntry {
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final Color color;

  const _WhatsNewEntry({
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Changelog per version  (add a new entry when you bump pubspec version)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<_WhatsNewEntry>> _changelog = {
  '1.0.5': [
    _WhatsNewEntry(
      icon: Icons.auto_stories_rounded,
      titleAr: 'التفسير بالضغط المطوّل',
      titleEn: 'Tafsir on Long Press',
      descAr: 'اضغط مطولاً على أي آية لفتح شاشة تفسيرها فوراً.',
      descEn:
          'Long-press any verse to instantly open its detailed explanation.',
      color: const Color(0xFF6A1B9A),
    ),
    _WhatsNewEntry(
      icon: Icons.wb_twilight_rounded,
      titleAr: 'ورد يومي',
      titleEn: 'Daily Wird',
      descAr:
          'حدد تلاوتك اليومية وتابع تقدمك لتختم القرآن الكريم بانتظام.',
      descEn:
          'Set your daily recitation target and track your progress to complete the Quran.',
      color: Color(0xFF0277BD),
    ),
    _WhatsNewEntry(
      icon: Icons.menu_book_rounded,
      titleAr: 'واجهة المصحف المصوّرة',
      titleEn: 'Mushaf Page View',
      descAr:
          'تصميم إسلامي كامل مع نقوش هندسية وزخارف ذهبية تُحاكي المصاحف الأصيلة.',
      descEn:
          'Full Islamic design with geometric patterns and golden ornaments inspired by classic Mushafs.',
      color: AppColors.primary,
    ),
    _WhatsNewEntry(
      icon: Icons.rate_review_rounded,
      titleAr: 'شاركنا رأيك',
      titleEn: 'Share Your Feedback',
      descAr:
          'سجل اقتراحك من صفحة المزيد ثم اقتراحات ومشاركات - اقتراحك يصنع فارقاً!',
      descEn:
          'We welcome your suggestions and feedback to improve the app — your voice makes a difference.',
      color: const Color(0xFF00838F),
    ),
    _WhatsNewEntry(
      icon: Icons.notifications_active_rounded,
      titleAr: 'تنبيه الورد',
      titleEn: 'Wird Reminder',
      descAr:
          'استلم التذكيرات يومياً حتى لا يمر يوم بدون قراءة.',
      descEn:
          'Get daily reminders so you never miss your Quran recitation.',
      color: Color(0xFFE65100),
    ),
    _WhatsNewEntry(
      icon: Icons.text_fields_rounded,
      titleAr: 'خطوط وأحجام متعددة',
      titleEn: 'Custom Fonts & Sizes',
      descAr: 'اختر خط المصحف المناسب وخصّص حجم الخط حسب رغبتك.',
      descEn: 'Choose your preferred Quran font and adjust text size freely.',
      color: const Color(0xFF00695C),
    ),
    _WhatsNewEntry(
      icon: Icons.volume_up_rounded,
      titleAr: 'تلاوة صوتية',
      titleEn: 'Audio Recitation',
      descAr: 'استمع لكل آية على حدة أو شغّل الصفحة كاملة بضغطة واحدة.',
      descEn: 'Listen to individual ayahs or play the whole page with one tap.',
      color: const Color(0xFF1565C0),
    ),
    _WhatsNewEntry(
      icon: Icons.bookmark_rounded,
      titleAr: 'الإشارات المرجعية',
      titleEn: 'Bookmarks',
      descAr: 'احفظ آياتك وصفحاتك المفضلة وعُد إليها بسهولة.',
      descEn: 'Save your favourite ayahs and pages and revisit them anytime.',
      color: AppColors.secondary,
    ),
    _WhatsNewEntry(
      icon: Icons.nightlight_round,
      titleAr: 'الوضع الليلي',
      titleEn: 'Dark Mode',
      descAr: 'لحماية عينيك أثناء القراءة ليلاً بتصميم هادئ ومريح.',
      descEn: 'Eye-friendly dark theme for a comfortable night-time reading.',
      color: const Color(0xFF37474F),
    ),
    _WhatsNewEntry(
      icon: Icons.access_time_rounded,
      titleAr: 'أوقات الصلاة والأذان',
      titleEn: 'Prayer Times & Adhan',
      descAr: 'تنبيهات الأذان التلقائية حسب موقعك الجغرافي بدقة عالية.',
      descEn:
          'Accurate automatic adhan notifications based on your location.',
      color: const Color(0xFF2E7D32),
    ),
    _WhatsNewEntry(
      icon: Icons.translate_rounded,
      titleAr: 'دعم العربية والإنجليزية',
      titleEn: 'Arabic & English UI',
      descAr: 'واجهة كاملة باللغتين مع دعم RTL وLTR تلقائياً.',
      descEn:
          'Full bilingual interface with automatic RTL/LTR layout support.',
      color: const Color(0xFFAD1457),
    ),
    
  ],

  // ─── v1.0.8 ──────────────────────────────────────────────────────────────
  '1.0.8': [
    // 1 ── البحث (أبرز ميزة جديدة)
    _WhatsNewEntry(
      icon: Icons.search_rounded,
      titleAr: 'البحث في القرآن الكريم',
      titleEn: 'Quran Search',
      descAr: 'ابحث عن أي كلمة أو آية في القرآن الكريم كاملاً بسرعة ودقة.',
      descEn: 'Search for any word or verse across the entire Quran instantly.',
      color: const Color(0xFF00838F),
    ),
    // 2 ── تفسير ابن كثير
    _WhatsNewEntry(
      icon: Icons.menu_book_rounded,
      titleAr: 'تفسير ابن كثير',
      titleEn: 'Ibn Kathir Tafsir',
      descAr: 'اضغط مطوّلاً على أي آية لفتح تفسير ابن كثير الشامل — متاح بالكامل بدون إنترنت.',
      descEn: 'Long-press any verse to open the full Ibn Kathir tafsir — completely offline.',
      color: const Color(0xFF6A1B9A),
    ),
    // 3 ── علي عبد الله جابرتلاوة الشيخ كامل
    _WhatsNewEntry(
      icon: Icons.record_voice_over_rounded,
      titleAr: 'تلاوة الشيخ علي عبد الله جابر كامل',
      titleEn: 'Sheikh Abdullah Kamel Recitation',
      descAr: 'استمع لتلاوة الشيخ علي عبد الله جابر كامل وحمّل السور للاستماع بدون إنترنت.',
      descEn: 'Listen to Sheikh Abdullah Kamel and download surahs for offline playback.',
      color: const Color(0xFF0277BD),
    ),
    // 4 ── تلاوة كلمة بكلمة
    _WhatsNewEntry(
      icon: Icons.text_fields_rounded,
      titleAr: 'تلاوة كلمة بكلمة',
      titleEn: 'Word-by-Word Playback',
      descAr: 'شغّل القرآن الكريم كلمةً بكلمة مع تظليل كل كلمة أثناء التلاوة.',
      descEn: 'Play the Quran word by word with each word highlighted as it is recited.',
      color: AppColors.primary,
    ),
    // 5 ── تشغيل القرآن كاملاً من المزيد
    _WhatsNewEntry(
      icon: Icons.queue_music_rounded,
      titleAr: 'تشغيل القرآن كاملاً من صفحة المزيد',
      titleEn: 'Full Quran Playback from More',
      descAr: 'يمكنك الآن تشغيل القرآن الكريم كاملاً من صفحة المزيد بضغطة واحدة.',
      descEn: 'Play the entire Quran from the More page with a single tap.',
      color: const Color(0xFF2E7D32),
    ),
        _WhatsNewEntry(
      icon: Icons.favorite_rounded,
      titleAr: 'تذكير بالصلاة على النبي ﷺ',
      titleEn: 'Salah upon the Prophet ﷺ',
      descAr: 'تذكير يومي بالصلاة على سيدنا محمد ﷺ لا ينقطع في أي وقت من اليوم.',
      descEn: 'A daily reminder to send blessings upon the Prophet Muhammad ﷺ throughout your day.',
      color: const Color(0xFFAD1457),
    ),
      // 8 ── ورد القضاء والورد اليومي
    _WhatsNewEntry(
      icon: Icons.bookmark_add_rounded,
      titleAr: 'ورد القضاء وتحسين الورد اليومي',
      titleEn: 'Qada Wird & Enhanced Daily Wird',
      descAr: 'احفظ موضع ورد القضاء، وإشعارات الورد اليومي تُجدَّد تلقائياً كل يوم جديد.',
      descEn: 'Bookmark your Qada wird position and get daily wird reminders that reset automatically.',
      color: AppColors.secondary,
    ),
    // 7 ── التمرير العمودي للمصحف
    _WhatsNewEntry(
      icon: Icons.swipe_vertical_rounded,
      titleAr: 'تمرير عمودي لصفحات المصحف',
      titleEn: 'Vertical Mushaf Scrolling',
      descAr: 'تصفّح صفحات المصحف الشريف بالتمرير العمودي لتجربة قراءة أكثر طبيعية.',
      descEn: 'Browse Mushaf pages with vertical scroll for a more natural reading experience.',
      color: const Color(0xFF00695C),
    ),
  
    // 9 ── تخصيصات الأذان
    _WhatsNewEntry(
      icon: Icons.tune_rounded,
      titleAr: 'تخصيصات الأذان والأذان المصغر',
      titleEn: 'Adhan Customization & Mini Adhan',
      descAr: 'خصّص صوت كل أذان باستقلالية، واختر الأذان المصغر لتنبيه أخف.',
      descEn: 'Customize each prayer adhan independently and choose the mini adhan for a subtle alert.',
      color: const Color(0xFF37474F),
    ),
    // 6 ── تحسين مشغّل الصوت
    _WhatsNewEntry(
      icon: Icons.play_circle_rounded,
      titleAr: 'تحسين مشغّل الصوت',
      titleEn: 'Improved Audio Player',
      descAr: 'مشغّل صوتي أسرع وأبسط مع شريط تقدم دقيق يعمل مع السور الطويلة.',
      descEn: 'Faster and cleaner audio player with accurate progress even for long surahs.',
      color: const Color(0xFF1565C0),
    ),
    // 10 ── تذكير باقتراب الصلاة والإقامة
    _WhatsNewEntry(
      icon: Icons.alarm_rounded,
      titleAr: 'تذكير باقتراب الصلاة والإقامة',
      titleEn: 'Pre-Prayer & Iqama Reminders',
      descAr: 'استلم تنبيهاً قبل الأذان بـ 10 دقائق، وتنبيهاً آخر عند وقت الإقامة.',
      descEn: 'Get notified 10 minutes before the adhan and again at iqama time.',
      color: const Color(0xFFE65100),
    ),
    // 11 ── الصلاة على النبي ﷺ

  ],

  // ─── v1.0.9 ────────────────────────────────────────────────────
  '1.0.9': [
    _WhatsNewEntry(
      icon: Icons.explore_rounded,
      titleAr: 'شاشة القبلة',
      titleEn: 'Qiblah Compass',
      descAr: 'تحديد اتجاه القبلة بدقة بوصلة حية وخريطة تفاعلية، مع تنبيه فوري عند استقبال القبلة.',
      descEn: 'Find the Qibla direction with a live compass and interactive map, with instant haptic feedback when aligned.',
      color: AppColors.primary,
    ),
    _WhatsNewEntry(
      icon: Icons.notifications_active_rounded,
      titleAr: 'إصلاح جدولة الأذان والإشعارات',
      titleEn: 'Fixed Adhan & Notification Scheduling',
      descAr: 'تم إصلاح جدولة الأذان والإشعارات بشكل كامل — التنبيهات تصلك أخيراً في الوقت الصحيح دون انقطاع.',
      descEn: 'Adhan and notification scheduling is now fully fixed — alerts arrive on time, every time.',
      color: const Color(0xFF2E7D32),
    ),
    _WhatsNewEntry(
      icon: Icons.sensors_rounded,
      titleAr: 'تنبيه معايرة البوصلة',
      titleEn: 'Compass Calibration Alert',
      descAr: 'يظهر تنبيه تلقائي عند انخفاض دقة بوصلة جهازك مع خطوات واضحة لإعادة المعايرة.',
      descEn: 'An automatic prompt appears when compass accuracy is low, with step-by-step calibration instructions.',
      color: Colors.amber,
    ),
    _WhatsNewEntry(
      icon: Icons.auto_fix_high_rounded,
      titleAr: 'إصلاحات عامة',
      titleEn: 'General Fixes',
      descAr: 'حذف البسملة المكررة من بداية السور، ورقم الصفحة لم يعد يختبئ خلف شريط تنقل الأندرويد، وتحسينات في الوضع الليلي.',
      descEn: 'Duplicate Basmala removed from verse 1, page numbers no longer hidden on 3-button nav devices, and dark mode improvements.',
      color: const Color(0xFF00695C),
    ),
    _WhatsNewEntry(
      icon: Icons.record_voice_over_rounded,
      titleAr: 'الشيخ علي عبدالله جابر القارئ الافتراضي',
      titleEn: 'Ali Abdullah Jaber — New Default Reciter',
      descAr: 'صوت الشيخ علي عبدالله جابر العذب أصبح القارئ الافتراضي للتطبيق — يمكنك تغييره في أي وقت من الإعدادات.',
      descEn: 'Sheikh Ali Abdullah Jaber\'s beautiful voice is now the app\'s default reciter — change it anytime in Settings.',
      color: const Color(0xFF6A1B9A),
    ),
    _WhatsNewEntry(
      icon: Icons.radio_rounded,
      titleAr: 'إذاعة القرآن الكريم',
      titleEn: 'Quran Radio',
      descAr: 'استمع لبث القرآن الكريم المباشر من إذاعة القرآن الكريم المصرية بجودة عالية ومنخفضة داخل التطبيق.',
      descEn: 'Stream live Quran radio from the Egyptian Quran Broadcasting station in high or low quality, right inside the app.',
      color: const Color(0xFF00838F),
    ),
    _WhatsNewEntry(
      icon: Icons.scatter_plot_rounded,
      titleAr: 'السبحة الإلكترونية',
      titleEn: 'Digital Tasbeeh Counter',
      descAr: 'سبّح واذكر الله بسهولة مع سبحة إلكترونية تدعم الاهتزاز، وتنبّه عند الوصول لـ 33 و100، مع إمكانية الضبط اليدوي.',
      descEn: 'Count your dhikr effortlessly with a digital tasbih that vibrates, alerts at 33 & 100 counts, with manual adjustment.',
      color: AppColors.secondary,
    ),
    _WhatsNewEntry(
      icon: Icons.map_rounded,
      titleAr: 'خريطة القبلة التفاعلية',
      titleEn: 'Interactive Qiblah Map',
      descAr: 'شاهد اتجاه القبلة على خريطة تفاعلية حية بجانب البوصلة — مع خط رسومي واضح من موقعك إلى مكة المكرمة.',
      descEn: 'View the Qibla direction on a live interactive map alongside the compass — with a clear visual line from your location to Mecca.',
      color: AppColors.primary,
    ),
    _WhatsNewEntry(
      icon: Icons.share_rounded,
      titleAr: 'مشاركة الآيات كبطاقات جميلة',
      titleEn: 'Share Ayahs as Beautiful Cards',
      descAr: 'شارك أي آية كصورة بطاقة أنيقة من شاشة التفسير — تتضمن النص والسورة والرقم تلقائياً.',
      descEn: 'Share any verse as a beautiful image card from the Tafsir screen — with text, surah name, and number included automatically.',
      color: const Color(0xFFAD1457),
    ),
    _WhatsNewEntry(
      icon: Icons.headphones_rounded,
      titleAr: 'التلاوة تعمل في الخلفية',
      titleEn: 'Audio Plays in Background',
      descAr: 'استمر في الاستماع للتلاوة حتى وأنت تستخدم تطبيقات أخرى — مع إشعار التشغيل في شريط الإشعارات.',
      descEn: 'Keep listening to recitation even while using other apps — with a playback notification in the status bar.',
      color: const Color(0xFF1565C0),
    ),
  ],

  // ─── v1.0.10 ─────────────────────────────────────────────────────────────
  '1.0.10': [
    _WhatsNewEntry(
      icon: Icons.alarm_on_rounded,
      titleAr: 'الأذان على صوت المنبه الآن 🔔',
      titleEn: 'Adhan Now Uses Alarm Sound 🔔',
      descAr:
          'الأذان هيشتغل دلوقتي حتى لو التليفون على الصامت أو وضع DND — زي المنبه تماماً. تقدر تغيّر ده من إعدادات الأذان.',
      descEn:
          'Adhan now plays even in Silent or DND mode — just like an alarm clock. You can change this anytime in Adhan Settings.',
      color: const Color(0xFF2E7D32),
    ),
    _WhatsNewEntry(
      icon: Icons.lock_clock_rounded,
      titleAr: 'الأذان يُفعَّل في الوقت الصحيح دائماً',
      titleEn: 'Adhan Fires On Time — Always',
      descAr:
          'تم الترقية لأعلى أولوية تنبيه في Android — الأذان يشتغل بدقة حتى وإنت نايم أو الشاشة مقفولة أو التطبيق في الخلفية.',
      descEn:
          'Upgraded to the highest Android alarm priority — Adhan fires accurately even while you sleep, screen locked, or app in background.',
      color: AppColors.primary,
    ),
    _WhatsNewEntry(
      icon: Icons.healing_rounded,
      titleAr: 'الرقية الشرعية داخل التطبيق',
      titleEn: 'Ruqyah Shariah Inside the App',
      descAr:
          'أضفنا شاشة رقية شرعية متكاملة تضم آيات الشفاء والحماية مع عرض جميل للنص القرآني، وترجمة، وتشغيل صوتي للسور والآيات الأساسية.',
      descEn:
          'A dedicated Ruqyah Shariah screen is now available with healing and protection verses, polished Quran text rendering, translations, and audio playback for the essential recitations.',
      color: const Color(0xFF8E6C1F),
    ),
    _WhatsNewEntry(
      icon: Icons.feedback_outlined,
      titleAr: 'نظام اقتراحات ومشاركات جديد',
      titleEn: 'New Feedback & Suggestions System',
      descAr:
          'يمكنك الآن إرسال اقتراحاتك وملاحظاتك من داخل التطبيق بسهولة، مع نافذة تذكير ذكية تظهر في الوقت المناسب دون إزعاج.',
      descEn:
          'You can now send feedback and suggestions directly from inside the app, with a smart reminder prompt that appears at the right time without being intrusive.',
      color: const Color(0xFF00838F),
    ),
    _WhatsNewEntry(
      icon: Icons.widgets_rounded,
      titleAr: 'ويدجت مواقيت الصلاة للشاشة الرئيسية',
      titleEn: 'Prayer Times Home-Screen Widget',
      descAr:
          'أضفنا ويدجت لمواقيت الصلاة يعرض الصلاة الحالية والقادمة وتاريخ اليوم، مع أكثر من شكل ليتناسب مع واجهة هاتفك.',
      descEn:
          'A new Prayer Times home-screen widget shows the current and upcoming prayer along with today''s date, with multiple styles to match your device theme.',
      color: const Color(0xFF5D4037),
    ),
  ],
  // ─── v1.0.11 ─────────────────────────────────────────────────────────────────
  '1.0.11': [
 
    _WhatsNewEntry(
      icon: Icons.widgets_rounded,
      titleAr: 'ويدجت مواقيت الصلاة',
      titleEn: 'Prayer Times Widget',
      descAr:
          'تم تحسين ويدجت عرض مواقيت الصلاة والصلاة القادمة التي من الممكن إضافتها الآن في الصفحة الرئيسية للهاتف.',
      descEn:
          'Improved the prayer times and next prayer widget that can now be added to your phone\'s home screen.',
      color: const Color(0xFF5D4037),
    ),
    _WhatsNewEntry(
      icon: Icons.download_for_offline_rounded,
      titleAr: 'تحميل التفسير بدون إنترنت',
      titleEn: 'Offline Tafsir Download',
      descAr:
          'تم إضافة صفحة لتحميل تفاسير القرآن الكريم لتعمل بدون اتصال إنترنت.',
      descEn:
          'Added a page to download Quran Tafsirs to work offline without an internet connection.',
      color: const Color(0xFF00838F),
    ),
    _WhatsNewEntry(
      icon: Icons.healing_rounded,
      titleAr: 'إصلاحات الرقية الشرعية',
      titleEn: 'Ruqyah Shariah Fixes',
      descAr:
          'تم إصلاح بعض المشاكل في صفحة الرقية الشرعية لضمان تجربة أفضل.',
      descEn:
          'Fixed issues in the Ruqyah screen to ensure a seamless experience.',
      color: const Color(0xFF8E6C1F),
    ),
    _WhatsNewEntry(
      icon: Icons.sync_problem_rounded,
      titleAr: 'معالجة صلاحيات التنبيهات',
      titleEn: 'Enhanced Notifications Permission',
      descAr:
          'تم تطوير معالجة التنبيهات المستمرة في الخلفية لضمان وصول الأذان في الوقت المحدد ودون انقطاع من النظام.',
      descEn:
          'Advanced handling for background processing and permissions to keep Adhan and continuous notifications uninterrupted.',
      color: const Color(0xFFD84315),
    ),
  ],

  // ─── v1.0.12 ─────────────────────────────────────────────────────────────────
  '1.0.12': [
    _WhatsNewEntry(
      icon: Icons.scatter_plot_rounded,
      titleAr: 'ويدجت المسبحة للشاشة الرئيسية',
      titleEn: 'Tasbeeh Home-Screen Widget',
      descAr:
          'أضف ويدجت المسبحة على شاشتك الرئيسية لتسبيح سريع مع عداد ذكي واهتزاز عند الوصول للهدف.',
      descEn:
          'Add the Tasbeeh widget to your home screen for quick dhikr counting with smart counter and haptic feedback at goals.',
      color: AppColors.secondary,
    ),
    _WhatsNewEntry(
      icon: Icons.do_not_disturb_on_rounded,
      titleAr: 'وضع الصمت أثناء الصلاة',
      titleEn: 'Silent Mode During Prayer',
      descAr:
          'يُفعَّل وضع الصمت تلقائياً عند دخول وقت الصلاة لتجنب الإزعاج أثناء صلاتك — يمكنك ضبطه من إعدادات الأذان.',
      descEn:
          'Silent mode activates automatically at prayer time to avoid interruptions — customize it in Adhan Settings.',
      color: const Color(0xFF37474F),
    ),
    _WhatsNewEntry(
      icon: Icons.timer_rounded,
      titleAr: 'وقت إقامة مخصص لكل صلاة',
      titleEn: 'Customizable Iqama Time Per Prayer',
      descAr:
          'اضبط وقت الإقامة لكل صلاة على حدة — الفجر 20 دقيقة، الظهر 15، المغرب 5... كما تريد.',
      descEn:
          'Set iqama time for each prayer individually — Fajr 20 min, Dhuhr 15, Maghrib 5... as you prefer.',
      color: const Color(0xFFE65100),
    ),
    _WhatsNewEntry(
      icon: Icons.play_circle_outline_rounded,
      titleAr: 'استكمال التلاوة تلقائياً',
      titleEn: 'Auto-Continue Recitation',
      descAr:
          'عند الضغط على آية، يمكن تشغيل السورة أو الصفحة كاملة بدلاً من آية واحدة — فعّلها من إعدادات المصحف.',
      descEn:
          'Tap an ayah to play the entire surah or page instead of just one verse — enable it in Mushaf Settings.',
      color: const Color(0xFF0277BD),
    ),
    _WhatsNewEntry(
      icon: Icons.calendar_today_rounded,
      titleAr: 'تعديل التاريخ الهجري',
      titleEn: 'Hijri Date Adjustment',
      descAr:
          'إذا كان التاريخ الهجري في التطبيق يختلف عن تاريخ بلدك، يمكنك الآن تعديله يدوياً من إعدادات مواقيت الصلاة.',
      descEn:
          'If the Hijri date differs from your country, you can now adjust it manually in Prayer Times Settings.',
      color: const Color(0xFF6A1B9A),
    ),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// What's New Screen
// ─────────────────────────────────────────────────────────────────────────────
class WhatsNewScreen extends StatefulWidget {
  final WhatsNewService whatsNewService;
  final VoidCallback onDismiss;
  final String version;
  /// The version the user last saw the What's New screen for.
  /// If null (new install), the app showcase is shown with all features.
  /// If set, all entries from versions AFTER this one up to [version] are shown
  /// so users who skipped intermediate updates see everything they missed.
  final String? lastSeenVersion;

  const WhatsNewScreen({
    super.key,
    required this.whatsNewService,
    required this.onDismiss,
    required this.version,
    this.lastSeenVersion,
  });

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen>
    with SingleTickerProviderStateMixin {
  late final List<_WhatsNewEntry> _entries;
  late final String _displayVersion;
  late final bool _isShowcaseMode;
  late final int _totalMs;
  late final AnimationController _animController;

  String _resolveVersion(String version) {
    final normalized = WhatsNewService.normalizeVersionForChangelog(version);
    if (_changelog.containsKey(normalized)) {
      return normalized;
    }
    if (_changelog.containsKey(version)) {
      return version;
    }
    return _changelog.keys.last;
  }

  List<_WhatsNewEntry> _entriesThroughVersion(String version) {
    final result = <_WhatsNewEntry>[];
    for (final entry in _changelog.entries) {
      result.addAll(entry.value);
      if (entry.key == version) {
        return result;
      }
    }
    return _changelog.values.expand((items) => items).toList(growable: false);
  }

  List<_WhatsNewEntry> _entriesAfterVersion({
    required String lastSeen,
    required String current,
  }) {
    final result = <_WhatsNewEntry>[];
    bool collect = false;

    for (final entry in _changelog.entries) {
      if (collect) {
        result.addAll(entry.value);
      }

      if (entry.key == lastSeen) {
        collect = true;
      }

      if (entry.key == current) {
        break;
      }
    }

    return result;
  }

  /// Returns every changelog entry the user hasn’t seen yet.
  ///
  /// - [lastSeen] null  → first launch, show the full app feature showcase.
  /// - [lastSeen] known → collect entries from all versions AFTER [lastSeen].
  /// - [lastSeen] not found in map → fallback to current version’s entries.
  List<_WhatsNewEntry> _buildEntries(String? lastSeen) {
    final currentVersion = _resolveVersion(widget.version);

    if (lastSeen == null) {
      return _entriesThroughVersion(currentVersion);
    }

    final normalizedLastSeen = _resolveVersion(lastSeen);
    if (!_changelog.containsKey(normalizedLastSeen)) {
      return _changelog[currentVersion] ?? _changelog.values.last;
    }

    final result = _entriesAfterVersion(
      lastSeen: normalizedLastSeen,
      current: currentVersion,
    );

    return result.isNotEmpty
        ? result
        : (_changelog[currentVersion] ?? _changelog.values.last);
  }

  @override
  void initState() {
    super.initState();
    _displayVersion = _resolveVersion(widget.version);
    _isShowcaseMode = widget.lastSeenVersion == null;
    _entries = _buildEntries(widget.lastSeenVersion);
    // 300ms base + 100ms per card stagger + 500ms card animation window
    _totalMs = 300 + _entries.length * 100 + 500;
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await widget.whatsNewService.markAsSeen();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isDark = settings.darkMode;
    final isAr = settings.appLanguageCode.toLowerCase().startsWith('ar');

    final entries = _entries;

    final bgColors = isDark
        ? [const Color(0xFF0E1A12), const Color(0xFF131F16)]
        : [const Color(0xFFFFF9ED), const Color(0xFFFFF4D8)];

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        // Transparent so the gradient fills behind the system status bar too
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgColors,
            ),
          ),
          child: Stack(
            children: [
              // Background Islamic geometric pattern
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PatternPainter(color: AppColors.primary),
                  ),
                ),
              ),
              // Decorative border overlay
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BorderPainter(color: AppColors.primary),
                  ),
                ),
              ),
              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // ── Animated header entrance ──────────────────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final t = CurvedAnimation(
                          parent: _animController,
                          curve: const Interval(0.0, 0.30,
                              curve: Curves.easeOut),
                        ).value;
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * -20),
                            child: child,
                          ),
                        );
                      },
                      child: _WhatsNewHeader(
                        version: _displayVersion,
                        isShowcaseMode: _isShowcaseMode,
                        isAr: isAr,
                        isDark: isDark,
                      ),
                    ),
                    // ── Scrollable feature list ───────────────────────────
                    Expanded(
                      child: ListView.separated(
                        // Bottom padding so the last card is not hidden by
                        // the button area
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _FeatureCard(
                            entry: entries[index],
                            isAr: isAr,
                            isDark: isDark,
                            index: index,
                            totalMs: _totalMs,
                            parentAnimation: _animController,
                          );
                        },
                      ),
                    ),
                    // ── CTA button ────────────────────────────────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final t = CurvedAnimation(
                          parent: _animController,
                          curve: const Interval(0.65, 1.0,
                              curve: Curves.easeOut),
                        ).value;
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 14),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 4, 24, 28),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleDismiss,
                            borderRadius: BorderRadius.circular(20),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isAr
                                          ? Icons.arrow_back_ios_rounded
                                          : Icons
                                              .arrow_forward_ios_rounded,
                                      size: 16,
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.85),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isAr
                                          ? 'ابدأ الاستخدام'
                                          : 'Get Started',
                                      // Use default Directionality-aware font
                                      // so Arabic letters are never split.
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onPrimary,
                                        letterSpacing: 0,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      isAr
                                          ? Icons.arrow_back_ios_rounded
                                          : Icons
                                              .arrow_forward_ios_rounded,
                                      size: 16,
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.85),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header widget – full-width app-store-style banner
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsNewHeader extends StatelessWidget {
  final String version;
  final bool isShowcaseMode;
  final bool isAr;
  final bool isDark;

  const _WhatsNewHeader({
    required this.version,
    required this.isShowcaseMode,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ─ Banner background ─────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 22,
            bottom: 24,
            left: isAr ? 20 : 20,
            right: isAr ? 20 : 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0A3D1F),
                      const Color(0xFF0D5E3A),
                      const Color(0xFF0A3D1F),
                    ]
                  : [
                      AppColors.primary,
                      const Color(0xFF1B7A4A),
                      AppColors.primary,
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─ Text side ─
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "What's new" label chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color:
                            AppColors.secondary.withValues(alpha: 0.22),
                        border: Border.all(
                          color:
                              AppColors.secondary.withValues(alpha: 0.55),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isAr ? 'ما الجديد' : "What's New",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                              height: 1.4,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Big version line
                    Text(
                      isShowcaseMode
                        ? (isAr
                          ? 'أهم مميزات التطبيق'
                          : 'Explore the App')
                        : (isAr
                          ? 'الإصدار $version'
                          : 'Version $version'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      isShowcaseMode
                        ? (isAr
                          ? 'نظرة سريعة على أبرز ما يقدمه التطبيق بالكامل'
                          : 'A quick look at the app\'s full feature set')
                        : (isAr
                          ? 'كل ما تم تطويره وإضافته في هذا التحديث'
                          : 'Everything added in this update'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.70),
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // ─ Decorative icon side ─
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size(72, 72),
                  painter: _StarBurstPainter(
                    ringColor: AppColors.secondary.withValues(alpha: 0.25),
                    starColor: AppColors.secondary.withValues(alpha: 0.18),
                  ),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Center(
                      child: Icon(
                        Icons.mosque_rounded,
                        size: 34,
                        color:
                            AppColors.secondary.withValues(alpha: 0.90),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─ Bottom wave divider ───────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.0),
                  AppColors.secondary.withValues(alpha: 0.6),
                  AppColors.secondary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature card widget
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final _WhatsNewEntry entry;
  final bool isAr;
  final bool isDark;
  final int index;
  final int totalMs;
  final AnimationController parentAnimation;

  const _FeatureCard({
    required this.entry,
    required this.isAr,
    required this.isDark,
    required this.index,
    required this.totalMs,
    required this.parentAnimation,
  });

  @override
  Widget build(BuildContext context) {
    // Each card starts at 300 + index×100 ms; animates over a 500ms window.
    final startFraction = (300 + index * 100) / totalMs;
    final endFraction =
        ((300 + index * 100 + 500) / totalMs).clamp(0.0, 1.0);

    final cardBg = isDark
        ? const Color(0xFF182218).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.82);
    final borderColor =
        entry.color.withValues(alpha: isDark ? 0.28 : 0.20);

    return AnimatedBuilder(
      animation: parentAnimation,
      builder: (context, child) {
        final t = CurvedAnimation(
          parent: parentAnimation,
          curve: Interval(startFraction, endFraction, curve: Curves.easeOutCubic),
        ).value;
        final dx = (1 - t) * (isAr ? 32.0 : -32.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : entry.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        entry.color.withValues(alpha: 0.9),
                        entry.color.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _IconBubble(color: entry.color, icon: entry.icon),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isAr ? entry.titleAr : entry.titleEn,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.93)
                                      : AppColors.textPrimary,
                                  height: 1.3,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isAr ? entry.descAr : entry.descEn,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  letterSpacing: 0,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon bubble – extracted so the child cache works cleanly
// ─────────────────────────────────────────────────────────────────────────────
class _IconBubble extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _IconBubble({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star-burst painter for the header icon area
// ─────────────────────────────────────────────────────────────────────────────
class _StarBurstPainter extends CustomPainter {
  final Color ringColor;
  final Color starColor;

  const _StarBurstPainter(
      {required this.ringColor, required this.starColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 8-point star
    final path = Path();
    const numPoints = 8;
    final outer = size.width / 2;
    final inner = size.width / 3.8;
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi / numPoints) - math.pi / 2;
      final r = i.isEven ? outer : inner;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, starPaint);

    // Outer ring
    canvas.drawCircle(center, outer - 2, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter old) =>
      old.ringColor != ringColor || old.starColor != starColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters – same visual style as mushaf_page_view
// ─────────────────────────────────────────────────────────────────────────────
class _PatternPainter extends CustomPainter {
  final Color color;

  const _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const patternSize = 40.0;
    for (double x = 0; x < size.width; x += patternSize) {
      for (double y = 0; y < size.height; y += patternSize) {
        final path = Path()
          ..moveTo(x + patternSize / 2, y)
          ..lineTo(x + patternSize, y + patternSize / 2)
          ..lineTo(x + patternSize / 2, y + patternSize)
          ..lineTo(x, y + patternSize / 2)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(
          Offset(x + patternSize / 2, y + patternSize / 2),
          patternSize / 4,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.color != color;
}

class _BorderPainter extends CustomPainter {
  final Color color;

  const _BorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      paint,
    );
    // Corner star ornaments
    _drawStar(canvas, const Offset(10, 10), 14, paint);
    _drawStar(canvas, Offset(size.width - 10, 10), 14, paint);
    _drawStar(canvas, Offset(10, size.height - 10), 14, paint);
    _drawStar(canvas, Offset(size.width - 10, size.height - 10), 14, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const numPoints = 8;
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi / numPoints) - math.pi / 2;
      final r = i.isEven ? size / 2 : size / 4;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderPainter old) => old.color != color;
}

