/// Ruqyah Shariah content data — Quranic verses for spiritual healing & protection.
library;

enum RuqyahAudioType {
  /// Play the full surah.
  fullSurah,

  /// Play a specific verse range within a surah.
  ayahRange,
}

class RuqyahAudioConfig {
  final RuqyahAudioType type;
  final int surahNumber;

  /// Only used when [type] == [RuqyahAudioType.fullSurah].
  final int? numberOfAyahs;

  /// Only used when [type] == [RuqyahAudioType.ayahRange].
  final int? startAyah;
  final int? endAyah;

  const RuqyahAudioConfig.fullSurah({
    required this.surahNumber,
    required this.numberOfAyahs,
  })  : type = RuqyahAudioType.fullSurah,
        startAyah = null,
        endAyah = null;

  const RuqyahAudioConfig.ayahRange({
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
  })  : type = RuqyahAudioType.ayahRange,
        numberOfAyahs = null;
}

class RuqyahSection {
  final String id;
  final String titleAr;
  final String titleEn;
  final String benefitAr;
  final String benefitEn;
  final String arabicText;
  final String translationEn;
  final String referenceAr;
  final String referenceEn;
  final RuqyahAudioConfig audio;

  const RuqyahSection({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.benefitAr,
    required this.benefitEn,
    required this.arabicText,
    required this.translationEn,
    required this.referenceAr,
    required this.referenceEn,
    required this.audio,
  });
}

class RuqyahData {
  RuqyahData._();

  static const List<RuqyahSection> sections = [
    RuqyahSection(
      id: 'fatiha',
      titleAr: 'سورة الفاتحة',
      titleEn: 'Surah Al-Fatiha',
      benefitAr: 'أمّ الكتاب وشفاء من كل داء',
      benefitEn: 'Mother of the Book — a cure for every ailment',
      arabicText:
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ﴿١﴾ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ﴿٢﴾'
          ' الرَّحْمَٰنِ الرَّحِيمِ ﴿٣﴾ مَالِكِ يَوْمِ الدِّينِ ﴿٤﴾'
          ' إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ﴿٥﴾'
          ' اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ﴿٦﴾'
          ' صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ ﴿٧﴾',
      translationEn:
          'In the name of Allah, the Most Gracious, the Most Merciful. '
          'All praise is due to Allah, Lord of all the worlds. '
          'The Most Gracious, the Most Merciful. '
          'Master of the Day of Judgment. '
          'You alone we worship, and You alone we ask for help. '
          'Guide us to the straight path — '
          'the path of those You have blessed, not of those who have incurred Your anger, '
          'nor of those who have gone astray.',
      referenceAr: 'سورة الفاتحة (١–٧)',
      referenceEn: 'Surah Al-Fatiha (1:1–7)',
      audio: RuqyahAudioConfig.fullSurah(surahNumber: 1, numberOfAyahs: 7),
    ),

    RuqyahSection(
      id: 'ayat_kursi',
      titleAr: 'آية الكرسي',
      titleEn: 'Ayat Al-Kursi',
      benefitAr: 'أعظم آية في القرآن — حماية من الشيطان',
      benefitEn: 'Greatest verse in the Quran — protection from Shaytan',
      arabicText:
          'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ'
          ' لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ'
          ' مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ'
          ' يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ'
          ' وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ'
          ' وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ'
          ' وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ ﴿٢٥٥﴾',
      translationEn:
          'Allah — there is no deity except Him, the Ever-Living, the Sustainer of all existence. '
          'Neither drowsiness overtakes Him nor sleep. '
          'To Him belongs whatever is in the heavens and whatever is on the earth. '
          'Who could intercede with Him except by His permission? '
          'He knows what is presently before them and what will be after them, '
          'and they encompass not a thing of His knowledge except for what He wills. '
          'His Kursi extends over the heavens and the earth, '
          'and their preservation tires Him not. '
          'And He is the Most High, the Most Great.',
      referenceAr: 'سورة البقرة (٢٥٥)',
      referenceEn: 'Surah Al-Baqara (2:255)',
      audio: RuqyahAudioConfig.ayahRange(
          surahNumber: 2, startAyah: 255, endAyah: 255),
    ),

    RuqyahSection(
      id: 'khatima_baqara',
      titleAr: 'خاتمة سورة البقرة',
      titleEn: 'End of Al-Baqara',
      benefitAr: 'من قرأهما في ليلة كفتاه — كفاية وحفظ',
      benefitEn: 'Whoever recites them at night, they will suffice him',
      arabicText:
          'آمَنَ الرَّسُولُ بِمَا أُنزِلَ إِلَيْهِ مِن رَّبِّهِ وَالْمُؤْمِنُونَ ۚ'
          ' كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ'
          ' لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِّن رُّسُلِهِ ۚ وَقَالُوا سَمِعْنَا وَأَطَعْنَا ۖ'
          ' غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ ﴿٢٨٥﴾\n'
          'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا ۚ'
          ' لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ ۗ'
          ' رَبَّنَا لَا تُؤَاخِذْنَا إِن نَّسِينَا أَوْ أَخْطَأْنَا ۚ'
          ' رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِن قَبْلِنَا ۚ'
          ' رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ ۖ'
          ' وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا ۚ أَنتَ مَوْلَانَا'
          ' فَانصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ ﴿٢٨٦﴾',
      translationEn:
          'The Messenger has believed in what was revealed to him from his Lord, and so have the believers. '
          'All of them have believed in Allah and His angels and His books and His messengers, '
          '"We make no distinction between any of His messengers." '
          'And they say, "We hear and we obey. [We seek] Your forgiveness, our Lord, and to You is the [final] destination." '
          'Allah does not burden a soul beyond that it can bear. '
          'It will have what it has gained, and it will bear what it has earned. '
          '"Our Lord, do not impose blame upon us if we forget or err. '
          'Our Lord, lay not upon us a burden like that which You laid upon those before us. '
          'Our Lord, burden us not with that which we have no ability to bear. '
          'And pardon us; and forgive us; and have mercy upon us. '
          'You are our protector, so give us victory over the disbelieving people."',
      referenceAr: 'سورة البقرة (٢٨٥–٢٨٦)',
      referenceEn: 'Surah Al-Baqara (2:285–286)',
      audio: RuqyahAudioConfig.ayahRange(
          surahNumber: 2, startAyah: 285, endAyah: 286),
    ),

    RuqyahSection(
      id: 'araf_sihr',
      titleAr: 'آيات إبطال السحر — الأعراف',
      titleEn: 'Verses against Magic — Al-A\'raf',
      benefitAr: 'إبطال السحر والتحصن من الشعوذة',
      benefitEn: 'Nullification of magic and protection from sorcery',
      arabicText:
          'وَأَوْحَيْنَا إِلَىٰ مُوسَىٰ أَنْ أَلْقِ عَصَاكَ ۖ'
          ' فَإِذَا هِيَ تَلْقَفُ مَا يَأْفِكُونَ ﴿١١٧﴾'
          ' فَوَقَعَ الْحَقُّ وَبَطَلَ مَا كَانُوا يَعْمَلُونَ ﴿١١٨﴾'
          ' فَغُلِبُوا هُنَالِكَ وَانقَلَبُوا صَاغِرِينَ ﴿١١٩﴾'
          ' وَأُلْقِيَ السَّحَرَةُ سَاجِدِينَ ﴿١٢٠﴾'
          ' قَالُوا آمَنَّا بِرَبِّ الْعَالَمِينَ ﴿١٢١﴾'
          ' رَبِّ مُوسَىٰ وَهَارُونَ ﴿١٢٢﴾',
      translationEn:
          'And We inspired to Moses, "Throw your staff," and at once it devoured what they were falsifying. '
          'So the truth was established, and abolished was what they were doing. '
          'And they [i.e., Pharaoh and his people] were overcome right there and became debased. '
          'And the magicians fell down in prostration. '
          'They said, "We have believed in the Lord of the worlds — '
          'the Lord of Moses and Aaron."',
      referenceAr: 'سورة الأعراف (١١٧–١٢٢)',
      referenceEn: 'Surah Al-A\'raf (7:117–122)',
      audio: RuqyahAudioConfig.ayahRange(
          surahNumber: 7, startAyah: 117, endAyah: 122),
    ),

    RuqyahSection(
      id: 'yunus_shifa',
      titleAr: 'آية الشفاء — يونس',
      titleEn: 'Verse of Healing — Yunus',
      benefitAr: 'شفاء لما في الصدور وهدى ورحمة للمؤمنين',
      benefitEn: 'A healing for what is in the hearts, guidance and mercy for believers',
      arabicText:
          'يَا أَيُّهَا النَّاسُ قَدْ جَاءَتْكُم مَّوْعِظَةٌ مِّن رَّبِّكُمْ'
          ' وَشِفَاءٌ لِّمَا فِي الصُّدُورِ وَهُدًى وَرَحْمَةٌ لِّلْمُؤْمِنِينَ ﴿٥٧﴾',
      translationEn:
          'O mankind, there has come to you instruction from your Lord, '
          'and healing for what is in the hearts, '
          'and guidance and mercy for the believers.',
      referenceAr: 'سورة يونس (٥٧)',
      referenceEn: 'Surah Yunus (10:57)',
      audio: RuqyahAudioConfig.ayahRange(
          surahNumber: 10, startAyah: 57, endAyah: 57),
    ),

    RuqyahSection(
      id: 'yunus_sihr',
      titleAr: 'إبطال السحر — يونس',
      titleEn: 'Against Magic — Yunus',
      benefitAr: 'إبطال السحر وإحقاق الحق',
      benefitEn: 'Nullification of magic and establishment of truth',
      arabicText:
          'وَقَالَ فِرْعَوْنُ ائْتُونِي بِكُلِّ سَاحِرٍ عَلِيمٍ ﴿٧٩﴾'
          ' فَلَمَّا جَاءَ السَّحَرَةُ قَالَ لَهُم مُّوسَىٰ أَلْقُوا مَا أَنتُم مُّلْقُونَ ﴿٨٠﴾'
          ' فَلَمَّا أَلْقَوْا قَالَ مُوسَىٰ مَا جِئْتُم بِهِ السِّحْرُ ۖ'
          ' إِنَّ اللَّهَ سَيُبْطِلُهُ ۖ إِنَّ اللَّهَ لَا يُصْلِحُ عَمَلَ الْمُفْسِدِينَ ﴿٨١﴾'
          ' وَيُحِقُّ اللَّهُ الْحَقَّ بِكَلِمَاتِهِ وَلَوْ كَرِهَ الْمُجْرِمُونَ ﴿٨٢﴾',
      translationEn:
          'And Pharaoh said, "Bring to me every learned magician." '
          'So when the magicians came, Moses said to them, "Throw down what you will throw." '
          'And when they had thrown, Moses said, "What you have brought is [only] magic. '
          'Indeed, Allah will make it worthless. Indeed, Allah does not amend the work of corrupters. '
          'And Allah will establish the truth by His words, even if the criminals dislike it."',
      referenceAr: 'سورة يونس (٧٩–٨٢)',
      referenceEn: 'Surah Yunus (10:79–82)',
      audio: RuqyahAudioConfig.ayahRange(
          surahNumber: 10, startAyah: 79, endAyah: 82),
    ),

    RuqyahSection(
      id: 'isra_shifa',
      titleAr: 'القرآن شفاء — الإسراء',
      titleEn: 'Quran as Healing — Al-Isra',
      benefitAr: 'شاهد على أن القرآن شفاء ورحمة للمؤمنين',
      benefitEn: 'Testimony that the Quran is a healing and mercy for believers',
      arabicText:
          'وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِّلْمُؤْمِنِينَ ۙ'
          ' وَلَا يَزِيدُ الظَّالِمِينَ إِلَّا خَسَارًا ﴿٨٢﴾',
      translationEn:
          'And We send down of the Quran that which is a healing and a mercy for the believers, '
          'but it does not increase the wrongdoers except in loss.',
      referenceAr: 'سورة الإسراء (٨٢)',
      referenceEn: 'Surah Al-Isra (17:82)',
      audio: RuqyahAudioConfig.ayahRange(
          surahNumber: 17, startAyah: 82, endAyah: 82),
    ),

    RuqyahSection(
      id: 'kafiroon',
      titleAr: 'سورة الكافرون',
      titleEn: 'Surah Al-Kafiroon',
      benefitAr: 'براءة من الشرك وحماية من الكفر',
      benefitEn: 'Declaration of monotheism — protection from disbelief',
      arabicText:
          'قُلْ يَا أَيُّهَا الْكَافِرُونَ ﴿١﴾'
          ' لَا أَعْبُدُ مَا تَعْبُدُونَ ﴿٢﴾'
          ' وَلَا أَنتُمْ عَابِدُونَ مَا أَعْبُدُ ﴿٣﴾'
          ' وَلَا أَنَا عَابِدٌ مَّا عَبَدتُّمْ ﴿٤﴾'
          ' وَلَا أَنتُمْ عَابِدُونَ مَا أَعْبُدُ ﴿٥﴾'
          ' لَكُمْ دِينُكُمْ وَلِيَ دِينِ ﴿٦﴾',
      translationEn:
          'Say, "O disbelievers, '
          'I do not worship what you worship. '
          'Nor are you worshippers of what I worship. '
          'Nor will I be a worshipper of what you worship. '
          'Nor will you be worshippers of what I worship. '
          'For you is your religion, and for me is my religion."',
      referenceAr: 'سورة الكافرون (١٠٩)',
      referenceEn: 'Surah Al-Kafiroon (109)',
      audio:
          RuqyahAudioConfig.fullSurah(surahNumber: 109, numberOfAyahs: 6),
    ),

    RuqyahSection(
      id: 'ikhlas',
      titleAr: 'سورة الإخلاص',
      titleEn: 'Surah Al-Ikhlas',
      benefitAr: 'تعدل ثلث القرآن — توحيد الله وإثبات وحدانيته',
      benefitEn: 'Equals one-third of the Quran — pure monotheism',
      arabicText:
          'قُلْ هُوَ اللَّهُ أَحَدٌ ﴿١﴾'
          ' اللَّهُ الصَّمَدُ ﴿٢﴾'
          ' لَمْ يَلِدْ وَلَمْ يُولَدْ ﴿٣﴾'
          ' وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ ﴿٤﴾',
      translationEn:
          'Say, "He is Allah, [who is] One. '
          'Allah, the Eternal Refuge. '
          'He neither begets nor is born. '
          'Nor is there to Him any equivalent."',
      referenceAr: 'سورة الإخلاص (١١٢)',
      referenceEn: 'Surah Al-Ikhlas (112)',
      audio:
          RuqyahAudioConfig.fullSurah(surahNumber: 112, numberOfAyahs: 4),
    ),

    RuqyahSection(
      id: 'falaq',
      titleAr: 'سورة الفلق',
      titleEn: 'Surah Al-Falaq',
      benefitAr: 'التعوذ بالله من شر الخلق والسحر والحاسد',
      benefitEn: 'Seeking refuge from evil of creation, magic, and envy',
      arabicText:
          'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ﴿١﴾'
          ' مِن شَرِّ مَا خَلَقَ ﴿٢﴾'
          ' وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ﴿٣﴾'
          ' وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ﴿٤﴾'
          ' وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ ﴿٥﴾',
      translationEn:
          'Say, "I seek refuge in the Lord of daybreak '
          'from the evil of that which He created '
          'and from the evil of darkness when it settles '
          'and from the evil of the blowers in knots '
          'and from the evil of an envier when he envies."',
      referenceAr: 'سورة الفلق (١١٣)',
      referenceEn: 'Surah Al-Falaq (113)',
      audio:
          RuqyahAudioConfig.fullSurah(surahNumber: 113, numberOfAyahs: 5),
    ),

    RuqyahSection(
      id: 'nas',
      titleAr: 'سورة الناس',
      titleEn: 'Surah An-Nas',
      benefitAr: 'التعوذ بالله من الوسواس والشيطان',
      benefitEn: 'Seeking refuge from the whisperer and Shaytan',
      arabicText:
          'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ﴿١﴾'
          ' مَلِكِ النَّاسِ ﴿٢﴾'
          ' إِلَٰهِ النَّاسِ ﴿٣﴾'
          ' مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ﴿٤﴾'
          ' الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ﴿٥﴾'
          ' مِنَ الْجِنَّةِ وَالنَّاسِ ﴿٦﴾',
      translationEn:
          'Say, "I seek refuge in the Lord of mankind, '
          'the Sovereign of mankind, '
          'the God of mankind, '
          'from the evil of the retreating whisperer — '
          'who whispers in the breasts of mankind — '
          'from among the jinn and mankind."',
      referenceAr: 'سورة الناس (١١٤)',
      referenceEn: 'Surah An-Nas (114)',
      audio:
          RuqyahAudioConfig.fullSurah(surahNumber: 114, numberOfAyahs: 6),
    ),
  ];

  /// The minimal essential Ruqyah queue (full surahs only, for sequential play).
  static const List<({int surahNumber, int numberOfAyahs})> essentialQueue = [
    (surahNumber: 1, numberOfAyahs: 7),
    (surahNumber: 109, numberOfAyahs: 6),
    (surahNumber: 112, numberOfAyahs: 4),
    (surahNumber: 113, numberOfAyahs: 5),
    (surahNumber: 114, numberOfAyahs: 6),
  ];
}
