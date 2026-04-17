import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../../../core/utils/tutorial_builder.dart';
import '../../../../core/services/tutorial_service.dart';

class HomeTutorialKeys {
  static final searchButton = GlobalKey();
  static final darkModeButton = GlobalKey();
  static final prayerCountdown = GlobalKey();
  static final categoriesSection = GlobalKey();
  static final firstSurahCard = GlobalKey();
  static final firstPlayButton = GlobalKey();
}

class HomeTutorial {
  static List<TutorialStep> steps() {
    return [
      TutorialStep(
        key: HomeTutorialKeys.prayerCountdown,
        titleAr: 'العد التنازلي للصلاة',
        titleEn: 'Prayer Countdown',
        descriptionAr: 'يعرض الوقت المتبقي على موعد الصلاة القادمة مع اسمها',
        descriptionEn:
            'Shows the remaining time until the next prayer with its name',
        align: ContentAlign.bottom,
      ),
      TutorialStep(
        key: HomeTutorialKeys.searchButton,
        titleAr: 'البحث في القرآن',
        titleEn: 'Search the Quran',
        descriptionAr: 'ابحث عن أي كلمة أو آية في القرآن الكريم كاملاً',
        descriptionEn:
            'Search for any word or verse across the entire Holy Quran',
        align: ContentAlign.bottom,
        shape: ShapeLightFocus.Circle,
      ),
      TutorialStep(
        key: HomeTutorialKeys.darkModeButton,
        titleAr: 'الوضع الليلي',
        titleEn: 'Dark Mode',
        descriptionAr: 'غيّر بين الوضع الليلي والنهاري لراحة العين',
        descriptionEn: 'Toggle between dark and light mode for eye comfort',
        align: ContentAlign.bottom,
        shape: ShapeLightFocus.Circle,
      ),
      TutorialStep(
        key: HomeTutorialKeys.categoriesSection,
        titleAr: 'الوصول السريع',
        titleEn: 'Quick Access',
        descriptionAr:
            'اختصارات سريعة للأذكار، الأجزاء، الصوت، والقبلة. اضغط "المزيد" لعرض جميع الأقسام',
        descriptionEn:
            'Quick shortcuts for Adhkar, Juz, Audio, and Qibla. Tap "More" to see all sections',
        align: ContentAlign.bottom,
      ),
      TutorialStep(
        key: HomeTutorialKeys.firstSurahCard,
        titleAr: 'قائمة السور',
        titleEn: 'Surah List',
        descriptionAr:
            'اضغط على أي سورة لفتحها وقراءة آياتها مع الترجمة والتفسير',
        descriptionEn:
            'Tap any surah to open it and read its verses with translation and tafsir',
        align: ContentAlign.top,
      ),
      TutorialStep(
        key: HomeTutorialKeys.firstPlayButton,
        titleAr: 'تشغيل السورة',
        titleEn: 'Play Surah',
        descriptionAr: 'اضغط لتشغيل السورة كاملة بصوت القارئ المختار',
        descriptionEn:
            'Tap to play the full surah audio with your selected reciter',
        align: ContentAlign.top,
        shape: ShapeLightFocus.Circle,
      ),
    ];
  }

  static void show({
    required BuildContext context,
    required TutorialService tutorialService,
    required bool isArabic,
    required bool isDark,
  }) {
    if (tutorialService.isTutorialComplete(TutorialService.homeScreen)) return;

    // TutorialBuilder.show() internally awaits appReady, so we only need
    // a minimal delay for the widget tree to settle after layout changes.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (context.mounted) {
        TutorialBuilder.show(
          context: context,
          steps: steps(),
          isArabic: isArabic,
          isDark: isDark,
          onFinish: () {
            tutorialService.markComplete(TutorialService.homeScreen);
          },
        );
      }
    });
  }
}
