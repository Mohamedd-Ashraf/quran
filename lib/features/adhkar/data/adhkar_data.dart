import 'package:flutter/material.dart';
import 'models/adhkar_category.dart';
import 'models/adhkar_item.dart';
export 'models/adhkar_category.dart' show AdhkarGroup;

class AdhkarData {
  static List<AdhkarCategory> get categories => [
        // ── اليومية الأساسية ──
        _morningAdhkar,
        _eveningAdhkar,
        _afterPrayerAdhkar,
        _sleepAdhkar,
        _wakeUpAdhkar,
        // ── الطهارة والصلاة ──
        _wuduAdhkar,
        _istikharaAdhkar,
        _qunutAdhkar,
        _quranicDuas,
        // ── المنزل والسفر ──
        _homeMosqueAdhkar,
        _travelAdhkar,
        // ── الطعام والشراب ──
        _eatingDrinkingAdhkar,
        _fastingAdhkar,
        // ── الصحة والأحوال ──
        _distressAdhkar,
        _illnessAdhkar,
        _weatherAdhkar,
        // ── المناسبات والمجتمع ──
        _miscDuas,
        _majlisAdhkar,
        _janazaAdhkar,
        _hajjAdhkar,
      ];

  // ─── أذكار الصباح ─────────────────────────────────────────────────
  static AdhkarCategory get _morningAdhkar => AdhkarCategory(
        id: 'morning',
        titleAr: 'أذكار الصباح',
        titleEn: 'Morning Adhkar',
        subtitleAr: 'من الفجر حتى الضحى',
        subtitleEn: 'From Fajr until mid-morning',
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFD4AF37),
        group: AdhkarGroup.featured,
        items: [
          const AdhkarItem(
            id: 'morning_1',
            arabicText: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n'
                'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ '
                'لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ '
                'يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ '
                'وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
            translationEn:
                'Allah – there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who could intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great. (Ayat al-Kursi)',
            reference: 'البقرة: 255',
            repeatCount: 1,
            virtue:
                'من قالها حين يصبح أُجير من الجن حتى يمسي، ومن قالها حين يمسي أُجير من الجن حتى يصبح',
          ),
          const AdhkarItem(
            id: 'morning_2',
            arabicText:
                'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
            translationEn:
                'Say: He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent. (Surat Al-Ikhlas)',
            reference: 'سورة الإخلاص – قراءة ثلاث مرات',
            repeatCount: 3,
            virtue: 'من قالهن ثلاثاً حين يصبح وحين يمسي كفته من كل شيء',
          ),
          const AdhkarItem(
            id: 'morning_3',
            arabicText:
                'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
            translationEn:
                'Say: I seek refuge in the Lord of daybreak, from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies. (Surat Al-Falaq)',
            reference: 'سورة الفلق – قراءة ثلاث مرات',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'morning_4',
            arabicText:
                'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
            translationEn:
                'Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the whisperer who withdraws, who whispers in the breasts of mankind, among jinn and among people. (Surat An-Nas)',
            reference: 'سورة الناس – قراءة ثلاث مرات',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'morning_5',
            arabicText:
                'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
            translationEn:
                'We have reached the morning and at this very time all sovereignty belongs to Allah. Praise is to Allah. None has the right to be worshipped except Allah, alone, without partner; to Him belongs all sovereignty and praise and He is over all things omnipotent. My Lord, I ask You for the good of this day and the good of what follows it, and I seek refuge in You from the evil of this day and the evil of what follows it. My Lord, I seek refuge in You from laziness and the evil of old age. My Lord, I seek refuge in You from torment in the Fire and torment in the grave.',
            reference: 'مسلم 2723',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'morning_6',
            arabicText:
                'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
            translationEn:
                'O Allah, by Your leave we have reached the morning and by Your leave we reach the evening, by Your leave we live and die and unto You is our resurrection.',
            reference: 'أبو داود 5068، الترمذي 3391',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'morning_7',
            arabicText:
                'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
            translationEn:
                'O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide to Your covenant and promise as best I can. I take refuge in You from the evil of which I have committed. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for verily none can forgive sins except You.',
            reference: 'البخاري 6306 – سيد الاستغفار',
            repeatCount: 1,
            virtue:
                'من قالها موقناً بها فمات من يومه دخل الجنة، وكذلك من قالها من الليل',
          ),
          const AdhkarItem(
            id: 'morning_8',
            arabicText:
                'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَٰهَ إِلَّا أَنْتَ',
            translationEn:
                'O Allah, grant my body health, O Allah, grant my hearing health, O Allah, grant my sight health. None has the right to be worshipped except You.',
            reference: 'أبو داود 5090',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'morning_9',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي',
            translationEn:
                'O Allah, I ask You for pardon and well-being in this life and the next. O Allah, I ask You for pardon and well-being in my religious and worldly affairs, and my family and my wealth. O Allah, conceal my faults and calm my fears.',
            reference: 'ابن ماجه 3871',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'morning_10',
            arabicText:
                'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
            translationEn:
                'O Allah, I take refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debts and from being oppressed by men.',
            reference: 'البخاري 6369',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'morning_11',
            arabicText:
                'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
            translationEn:
                'How perfect Allah is and I praise Him.',
            reference: 'مسلم 2692',
            repeatCount: 100,
            virtue:
                'من قالها مئة مرة غُفرت ذنوبه وإن كانت مثل زبد البحر',
          ),
          const AdhkarItem(
            id: 'morning_12',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            translationEn:
                'None has the right to be worshipped except Allah, alone, without partner, to Him belongs all sovereignty and praise and He is over all things omnipotent.',
            reference: 'البخاري 3293',
            repeatCount: 10,
            virtue:
                'من قالها عشر مرات حين يصبح كانت له كعِدل أربع رقاب',
          ),
          const AdhkarItem(
            id: 'morning_13',
            arabicText:
                'رَضِيتُ بِاللَّهِ رَبًّا وَبِالْإِسْلَامِ دِينًا وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
            translationEn:
                'I am pleased with Allah as my Lord, with Islam as my religion, and with Muhammad (peace be upon him) as my prophet.',
            reference: 'أبو داود 5072',
            repeatCount: 3,
            virtue: 'كان حقاً على الله أن يرضيه يوم القيامة',
          ),
          const AdhkarItem(
            id: 'morning_14',
            arabicText:
                'حَسْبِيَ اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
            translationEn:
                'Allah is sufficient for me; none has the right to be worshipped except Him. Upon Him I rely and He is Lord of the Magnificent Throne.',
            reference: 'أبو داود 5081',
            repeatCount: 7,
            virtue: 'كفاه الله ما أهمه من أمر الدنيا والآخرة',
          ),
          const AdhkarItem(
            id: 'morning_15',
            arabicText:
                'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
            translationEn:
                'O Allah, what blessing I or any of Your creation have reached the morning with, is from You alone, without partner. So all praise and thanks are Yours.',
            reference: 'أبو داود 5073',
            repeatCount: 1,
            virtue: 'أدّى شُكر يومه',
          ),
          const AdhkarItem(
            id: 'morning_16',
            arabicText:
                'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ أَنَّكَ أَنْتَ اللَّهُ لَا إِلَٰهَ إِلَّا أَنْتَ وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
            translationEn:
                'O Allah, I have reached the morning and call on You, the bearers of Your throne, Your angels and all of Your creation to witness that You are Allah, none has the right to be worshipped except You alone, without partner, and that Muhammad is Your servant and messenger.',
            reference: 'أبو داود 5069',
            repeatCount: 4,
            virtue: 'أعتق الله ربعه من النار عن كل قائل',
          ),
          const AdhkarItem(
            id: 'morning_17',
            arabicText:
                'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
            translationEn:
                'I take refuge in the perfect words of Allah from the evil of what He has created.',
            reference: 'مسلم 2709',
            repeatCount: 3,
            virtue: 'لم تضره حُمة تلك الليلة',
          ),
          const AdhkarItem(
            id: 'morning_18',
            arabicText:
                'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
            translationEn:
                'In the name of Allah with whose name nothing is harmed on earth or in the heavens, and He is the All-Hearing, the All-Knowing.',
            reference: 'أبو داود 5088، الترمذي 3388',
            repeatCount: 3,
            virtue: 'لم تصبه فجأة بلاء',
          ),
          const AdhkarItem(
            id: 'morning_19',
            arabicText:
                'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
            translationEn:
                'O Ever-Living, O Self-Sustaining Sustainer of all, by Your mercy I call for help. Correct all of my affairs and do not leave me to myself, even for the blink of an eye.',
            reference: 'الحاكم 1/730، النسائي في الكبرى 10402',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'morning_20',
            arabicText:
                'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
            translationEn:
                'O Allah, send blessings and peace upon our Prophet Muhammad.',
            reference: 'الطبراني 7:22 – صحيح الجامع 6357',
            repeatCount: 10,
            virtue: 'من صلى علي حين يصبح عشراً وحين يمسي عشراً أدركته شفاعتي يوم القيامة',
          ),
        ],
      );

  // ─── أذكار المساء ─────────────────────────────────────────────────
  static AdhkarCategory get _eveningAdhkar => AdhkarCategory(
        id: 'evening',
        titleAr: 'أذكار المساء',
        titleEn: 'Evening Adhkar',
        subtitleAr: 'من العصر حتى المغرب',
        subtitleEn: 'From Asr until Maghrib',
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF3F51B5),
        group: AdhkarGroup.featured,
        items: [
          const AdhkarItem(
            id: 'evening_1',
            arabicText:
                'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ '
                'لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ '
                'يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ '
                'وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
            translationEn:
                'Allah – there is no deity except Him, the Ever-Living, the Sustainer of existence. (Ayat al-Kursi)',
            reference: 'البقرة: 255',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'evening_2',
            arabicText:
                'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
            translationEn:
                'We have reached the evening and at this very time all sovereignty belongs to Allah. My Lord, I ask You for the good of this night and the good of what follows it, and I seek refuge in You from the evil of this night and evil of what follows it. My Lord, I seek refuge in You from laziness and the evil of old age. My Lord, I seek refuge from torment in the Fire and torment in the grave.',
            reference: 'مسلم 2723',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'evening_3',
            arabicText:
                'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
            translationEn:
                'O Allah, by Your leave we have reached the evening and by Your leave we reach the morning; by Your leave we live and die and unto You is our return.',
            reference: 'أبو داود 5068، الترمذي 3391',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'evening_4',
            arabicText:
                'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
            translationEn:
                'O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide to Your covenant and promise as best I can. I take refuge in You from the evil of what I have committed. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for verily none can forgive sins except You. (Sayyid Al-Istighfar)',
            reference: 'البخاري 6306',
            repeatCount: 1,
            virtue:
                'من قالها موقناً بها فمات من ليلته دخل الجنة',
          ),
          const AdhkarItem(
            id: 'evening_5',
            arabicText:
                'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ أَنَّكَ أَنْتَ اللَّهُ لَا إِلَٰهَ إِلَّا أَنْتَ وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
            translationEn:
                'O Allah, I have reached the evening and call on You, the bearers of Your throne, Your angels, and all Your creation to witness that You are Allah, none has the right to be worshipped except You, and that Muhammad is Your servant and messenger.',
            reference: 'أبو داود 5069',
            repeatCount: 4,
            virtue: 'أعتق الله ربعه من النار عن كل قائل',
          ),
          const AdhkarItem(
            id: 'evening_6',
            arabicText:
                'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
            translationEn:
                'O Allah, what blessing I or any of Your creation have reached the evening with, is from You alone. You have no partner. All praise and thanks are for You.',
            reference: 'أبو داود 5073',
            repeatCount: 1,
            virtue: 'أدّى شُكر يومه',
          ),
          const AdhkarItem(
            id: 'evening_7',
            arabicText:
                'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَٰهَ إِلَّا أَنْتَ',
            translationEn:
                'O Allah, grant my body health. O Allah, grant my hearing health. O Allah, grant my sight health. None has the right to be worshipped except You.',
            reference: 'أبو داود 5090',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'evening_8',
            arabicText:
                'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
            translationEn:
                'I take refuge in the perfect words of Allah from the evil of what He has created.',
            reference: 'مسلم 2709',
            repeatCount: 3,
            virtue: 'لم تضره حُمة تلك الليلة',
          ),
          const AdhkarItem(
            id: 'evening_9',
            arabicText:
                'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
            translationEn:
                'In the name of Allah with whose name nothing is harmed on earth or in the heavens, and He is the All-Hearing, the All-Knowing.',
            reference: 'أبو داود 5088',
            repeatCount: 3,
            virtue: 'لم تصبه فجأة بلاء',
          ),
          const AdhkarItem(
            id: 'evening_10',
            arabicText:
                'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
            translationEn:
                'How perfect Allah is and I praise Him.',
            reference: 'مسلم 2692',
            repeatCount: 100,
            virtue: 'من قالها مئة مرة غُفرت ذنوبه وإن كانت مثل زبد البحر',
          ),
          const AdhkarItem(
            id: 'evening_11',
            arabicText:
                'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
            translationEn:
                'Say: He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent. (Surat Al-Ikhlas)',
            reference: 'سورة الإخلاص – قراءة ثلاث مرات مساءً',
            repeatCount: 3,
            virtue: 'من قالهن ثلاثاً حين يصبح وحين يمسي كفته من كل شيء',
          ),
          const AdhkarItem(
            id: 'evening_12',
            arabicText:
                'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
            translationEn:
                'Say: I seek refuge in the Lord of daybreak. (Surat Al-Falaq)',
            reference: 'سورة الفلق – قراءة ثلاث مرات مساءً',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'evening_13',
            arabicText:
                'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
            translationEn:
                'Say: I seek refuge in the Lord of mankind. (Surat An-Nas)',
            reference: 'سورة الناس – قراءة ثلاث مرات مساءً',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'evening_14',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            translationEn:
                'None has the right to be worshipped except Allah, alone, without partner. To Him belongs all sovereignty and praise and He is over all things omnipotent.',
            reference: 'البخاري 3293',
            repeatCount: 10,
            virtue: 'من قالها عشر مرات حين يمسي كانت له كعِدل أربع رقاب',
          ),
          const AdhkarItem(
            id: 'evening_15',
            arabicText:
                'حَسْبِيَ اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
            translationEn:
                'Allah is sufficient for me; none has the right to be worshipped except Him. Upon Him I rely and He is Lord of the Magnificent Throne.',
            reference: 'أبو داود 5081',
            repeatCount: 7,
            virtue: 'كفاه الله ما أهمه من أمر الدنيا والآخرة',
          ),
          const AdhkarItem(
            id: 'evening_16',
            arabicText:
                'رَضِيتُ بِاللَّهِ رَبًّا وَبِالْإِسْلَامِ دِينًا وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
            translationEn:
                'I am pleased with Allah as my Lord, with Islam as my religion, and with Muhammad (peace be upon him) as my prophet.',
            reference: 'أبو داود 5072',
            repeatCount: 3,
            virtue: 'كان حقاً على الله أن يرضيه يوم القيامة',
          ),
          const AdhkarItem(
            id: 'evening_17',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي',
            translationEn:
                'O Allah, I ask You for pardon and well-being in this life and the next. O Allah, I ask You for pardon and well-being in my religious and worldly affairs, and my family and my wealth. O Allah, conceal my faults and calm my fears.',
            reference: 'ابن ماجه 3871',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'evening_18',
            arabicText:
                'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
            translationEn:
                'O Allah, I take refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debts and from being oppressed by men.',
            reference: 'البخاري 6369',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'evening_19',
            arabicText:
                'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
            translationEn:
                'O Ever-Living, O Self-Sustaining Sustainer of all, by Your mercy I call for help. Correct all of my affairs and do not leave me to myself, even for the blink of an eye.',
            reference: 'الحاكم 1/730، النسائي في الكبرى 10402',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'evening_20',
            arabicText:
                'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
            translationEn:
                'O Allah, send blessings and peace upon our Prophet Muhammad.',
            reference: 'الطبراني 7:22 – صحيح الجامع 6357',
            repeatCount: 10,
            virtue: 'من صلى علي حين يصبح عشراً وحين يمسي عشراً أدركته شفاعتي يوم القيامة',
          ),
        ],
      );

  // ─── أذكار بعد الصلاة ─────────────────────────────────────────────
  static AdhkarCategory get _afterPrayerAdhkar => AdhkarCategory(
        id: 'after_prayer',
        titleAr: 'أذكار بعد الصلاة',
        titleEn: 'After Prayer',
        subtitleAr: 'بعد كل صلاة مكتوبة',
        subtitleEn: 'After each obligatory prayer',
        icon: Icons.mosque_rounded,
        color: const Color(0xFF0D5E3A),
        group: AdhkarGroup.featured,
        items: [
          const AdhkarItem(
            id: 'after_1',
            arabicText: 'أَسْتَغْفِرُ اللَّهَ',
            translationEn: 'I seek forgiveness from Allah.',
            reference: 'مسلم 591',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'after_2',
            arabicText:
                'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
            translationEn:
                'O Allah, You are As-Salam (Peace) and from You is peace. Blessed are You, O Owner of Majesty and Honour.',
            reference: 'مسلم 591',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'after_3',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ وَلَا مُعْطِيَ لِمَا مَنَعْتَ وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ',
            translationEn:
                'None has the right to be worshipped except Allah, alone without partner. To Him belongs all sovereignty and praise and He is over all things omnipotent. O Allah, none can withhold what You give, and none can give what You withhold, and no wealth or majesty can benefit anyone, as from You is all wealth and majesty.',
            reference: 'البخاري 844',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'after_4',
            arabicText:
                'سُبْحَانَ اللَّهِ',
            translationEn: 'How perfect Allah is.',
            reference: 'مسلم 595',
            repeatCount: 33,
          ),
          const AdhkarItem(
            id: 'after_5',
            arabicText: 'الْحَمْدُ لِلَّهِ',
            translationEn: 'Praise is to Allah.',
            reference: 'مسلم 595',
            repeatCount: 33,
          ),
          const AdhkarItem(
            id: 'after_6',
            arabicText: 'اللَّهُ أَكْبَرُ',
            translationEn: 'Allah is the greatest.',
            reference: 'مسلم 595',
            repeatCount: 33,
          ),
          const AdhkarItem(
            id: 'after_7',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            translationEn:
                'None has the right to be worshipped except Allah, alone without partner. To Him belongs all sovereignty and praise, and He is over all things omnipotent.',
            reference: 'مسلم 597',
            repeatCount: 1,
            virtue: 'غُفرت له خطاياه وإن كانت مثل زبد البحر',
          ),
          const AdhkarItem(
            id: 'after_8',
            arabicText:
                'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ',
            translationEn:
                'Allah! There is no god ˹worthy of worship˺ except Him, the Ever-Living, All-Sustaining. (Ayat al-Kursi)',
            reference: 'النسائي 1336 – من قرأها دبر كل صلاة لم يمنعه من دخول الجنة إلا أن يموت',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'after_9',
            arabicText:
                'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
            translationEn:
                'O Allah, help me to remember You, to give thanks to You, and to worship You in an excellent manner.',
            reference: 'أبو داود 1522',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'after_10',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا وَرِزْقًا طَيِّبًا وَعَمَلًا مُتَقَبَّلًا',
            translationEn:
                'O Allah, I ask You for knowledge that is of benefit, a good provision and deeds that will be accepted.',
            reference: 'ابن ماجه 925 – بعد صلاة الفجر',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار النوم ──────────────────────────────────────────────────
  static AdhkarCategory get _sleepAdhkar => AdhkarCategory(
        id: 'sleep',
        titleAr: 'أذكار النوم',
        titleEn: 'Sleep Adhkar',
        subtitleAr: 'قبل النوم',
        subtitleEn: 'Before going to sleep',
        icon: Icons.bedtime_rounded,
        color: const Color(0xFF512DA8),
        group: AdhkarGroup.featured,
        items: [
          const AdhkarItem(
            id: 'sleep_1',
            arabicText:
                'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
            translationEn:
                'In Your name, O Allah, I die and I live.',
            reference: 'البخاري 6324',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'sleep_2',
            arabicText:
                'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
            translationEn:
                'O Allah, protect me from Your punishment on the Day You resurrect Your servants.',
            reference: 'أبو داود 5045',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'sleep_3',
            arabicText:
                'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَاغْفِرْ لَهَا وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ',
            translationEn:
                'In Your name my Lord, I lie down and in Your name I rise, so if You should take my soul then have mercy upon it, and if You should return my soul then protect it as You protect Your righteous servants.',
            reference: 'البخاري 6320',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'sleep_4',
            arabicText:
                'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ وَفَوَّضْتُ أَمْرِي إِلَيْكَ وَوَجَّهْتُ وَجْهِيَ إِلَيْكَ وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ رَغْبَةً وَرَهْبَةً إِلَيْكَ لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ',
            translationEn:
                'O Allah, I submit my soul unto You and I entrust my affair unto You and I turn my face towards You, and I totally rely on You, in hope and fear of You. There is no fleeing from You, and there is no place of protection and safety except with You. I believe in Your Book which You have revealed and in Your Prophet whom You have sent.',
            reference: 'البخاري 247',
            repeatCount: 1,
            virtue: 'من قالها فمات تلك الليلة مات على الفطرة',
          ),
          const AdhkarItem(
            id: 'sleep_5',
            arabicText:
                'سُبْحَانَ اللَّهِ',
            translationEn: 'How perfect Allah is.',
            reference: 'البخاري 3113 – تسبيح فاطمة رضي الله عنها',
            repeatCount: 33,
            virtue: 'خيرٌ لك مما سألت',
          ),
          const AdhkarItem(
            id: 'sleep_6',
            arabicText: 'الْحَمْدُ لِلَّهِ',
            translationEn: 'All praise is for Allah.',
            reference: 'البخاري 3113',
            repeatCount: 33,
          ),
          const AdhkarItem(
            id: 'sleep_7',
            arabicText: 'اللَّهُ أَكْبَرُ',
            translationEn: 'Allah is the greatest.',
            reference: 'البخاري 3113',
            repeatCount: 34,
          ),
          const AdhkarItem(
            id: 'sleep_8',
            arabicText:
                'اللَّهُمَّ رَبَّ السَّمَوَاتِ وَرَبَّ الْأَرْضِ وَرَبَّ الْعَرْشِ الْعَظِيمِ رَبَّنَا وَرَبَّ كُلِّ شَيْءٍ، فَالِقَ الْحَبِّ وَالنَّوَى وَمُنْزِلَ التَّوْرَاةِ وَالْإِنْجِيلِ وَالْقُرْآنِ، أَعُوذُ بِكَ مِنْ شَرِّ كُلِّ شَيْءٍ أَنْتَ آخِذٌ بِنَاصِيَتِهِ، اللَّهُمَّ أَنْتَ الْأَوَّلُ فَلَيْسَ قَبْلَكَ شَيْءٌ وَأَنْتَ الْآخِرُ فَلَيْسَ بَعْدَكَ شَيْءٌ وَأَنْتَ الظَّاهِرُ فَلَيْسَ فَوْقَكَ شَيْءٌ وَأَنْتَ الْبَاطِنُ فَلَيْسَ دُونَكَ شَيْءٌ، اقْضِ عَنَّا الدَّيْنَ وَأَغْنِنَا مِنَ الْفَقْرِ',
            translationEn:
                'O Allah, Lord of the heavens and Lord of the earth and Lord of the Magnificent Throne. Our Lord and Lord of all things. Splitter of the grain and seed. Revealer of the Torah, the Gospel and the Quran. I take refuge in You from the evil of all things You shall seize by the forlock. O Allah, You are Al-Awwal (the First) and nothing is before You; You are Al-Akhir (the Last) and nothing is after You; You are Az-Zahir (the One above all) and nothing is above You; You are Al-Batin (the Hidden) and nothing is beyond You. Settle our debt for us and spare us from poverty.',
            reference: 'مسلم 2713',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الاستيقاظ ──────────────────────────────────────────────
  static AdhkarCategory get _wakeUpAdhkar => AdhkarCategory(
        id: 'wakeup',
        titleAr: 'أذكار الاستيقاظ',
        titleEn: 'Waking Up',
        subtitleAr: 'عند الاستيقاظ من النوم',
        subtitleEn: 'Upon waking from sleep',
        icon: Icons.light_mode_rounded,
        color: const Color(0xFFE65100),
        group: AdhkarGroup.featured,
        items: [
          const AdhkarItem(
            id: 'wakeup_1',
            arabicText:
                'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
            translationEn:
                'All praise is for Allah who gave us life after having taken it from us, and unto Him is the resurrection.',
            reference: 'البخاري 6312',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'wakeup_2',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَٰهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ',
            translationEn:
                'None has the right to be worshipped except Allah, alone without partner. To Him belongs all sovereignty and praise, and He is over all things omnipotent. Glory is to Allah, praise is to Allah, none has the right to be worshipped except Allah, Allah is the greatest, there is no might and no power except by Allah the Exalted, the Magnificent.',
            reference: 'البخاري 1154',
            repeatCount: 1,
            virtue: 'غُفرت له ذنوبه ولو كانت مثل زبد البحر',
          ),
          const AdhkarItem(
            id: 'wakeup_3',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهِ وَشَرِّ مَا بَعْدَهُ',
            translationEn:
                'O Allah, I ask You for the goodness of this day, its openings, its victories, its light, its blessings, and its guidance, and I take refuge in You from the evil of what is in it and the evil of what follows it.',
            reference: 'أبو داود 5084',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'wakeup_4',
            arabicText:
                'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ وَعَلَى كَلِمَةِ الْإِخْلَاصِ وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
            translationEn:
                'We rise upon the fitrah (natural disposition) of Islam, and the word of sincerity, and upon the religion of our Prophet Muhammad ﷺ, and upon the nation of our father Ibrahim who was a Hanif (monotheist) and was not of the polytheists.',
            reference: 'أحمد 15436',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أدعية قرآنية ─────────────────────────────────────────────────
  static AdhkarCategory get _quranicDuas => AdhkarCategory(
        id: 'quran',
        titleAr: 'أدعية قرآنية',
        titleEn: 'Quranic Duas',
        subtitleAr: 'أدعية من القرآن الكريم',
        subtitleEn: 'Supplications from the Holy Quran',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF00695C),
        group: AdhkarGroup.prayer,
        items: [
          const AdhkarItem(
            id: 'quran_1',
            arabicText:
                'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
            translationEn:
                'Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.',
            reference: 'البقرة: 201',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_2',
            arabicText:
                'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً ۚ إِنَّكَ أَنْتَ الْوَهَّابُ',
            translationEn:
                'Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.',
            reference: 'آل عمران: 8',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_3',
            arabicText:
                'رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا وَانصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ',
            translationEn:
                'Our Lord, forgive us our sins and the excess [committed] in our affairs and plant firmly our feet and give us victory over the disbelieving people.',
            reference: 'آل عمران: 147',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_4',
            arabicText:
                'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِّن لِّسَانِي يَفْقَهُوا قَوْلِي',
            translationEn:
                'My Lord, expand for me my breast [with assurance] and ease for me my task and untie the knot from my tongue, that they may understand my speech. (Dua of Moses)',
            reference: 'طه: 25-28',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_5',
            arabicText:
                'رَبِّ إِنِّي لِمَا أَنزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ',
            translationEn:
                'My Lord, indeed I am, for whatever good You would send down to me, in need. (Dua of Moses)',
            reference: 'القصص: 24',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_6',
            arabicText:
                'لَا إِلَٰهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ',
            translationEn:
                'There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers. (Dua of Yunus)',
            reference: 'الأنبياء: 87',
            repeatCount: 1,
            virtue:
                'ما دعا بها مسلم في شيء قط إلا استجاب الله له',
          ),
          const AdhkarItem(
            id: 'quran_7',
            arabicText:
                'رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ وَعَلَىٰ وَالِدَيَّ وَأَنْ أَعْمَلَ صَالِحًا تَرْضَاهُ وَأَدْخِلْنِي بِرَحْمَتِكَ فِي عِبَادِكَ الصَّالِحِينَ',
            translationEn:
                'My Lord, enable me to be grateful for Your favour which You have bestowed upon me and upon my parents and to do righteousness of which You approve. And admit me by Your mercy into [the ranks of] Your righteous servants.',
            reference: 'النمل: 19',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_8',
            arabicText:
                'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
            translationEn:
                'Our Lord, grant us from among our wives and offspring comfort to our eyes and make us an example for the righteous.',
            reference: 'الفرقان: 74',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_9',
            arabicText:
                'رَبِّ زِدْنِي عِلْمًا',
            translationEn: 'My Lord, increase me in knowledge.',
            reference: 'طه: 114',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'quran_10',
            arabicText:
                'رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ',
            translationEn:
                'Our Lord, forgive me and my parents and the believers the Day the account is established.',
            reference: 'إبراهيم: 41',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الأكل والشرب ───────────────────────────────────────────
  static AdhkarCategory get _eatingDrinkingAdhkar => AdhkarCategory(
        id: 'eating',
        titleAr: 'أذكار الطعام والشراب',
        titleEn: 'Eating & Drinking',
        subtitleAr: 'قبل الطعام وبعده',
        subtitleEn: 'Before and after meals',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF8B4513),
        group: AdhkarGroup.food,
        items: [
          const AdhkarItem(
            id: 'eating_1',
            arabicText: 'بِسْمِ اللَّهِ',
            translationEn: 'In the name of Allah.',
            reference: 'أبو داود 3767، الترمذي 1858',
            repeatCount: 1,
            virtue: 'من ذكر اسم الله على طعامه لم يجد الشيطان في طعامه',
          ),
          const AdhkarItem(
            id: 'eating_2',
            arabicText:
                'بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ',
            translationEn:
                'In the name of Allah at its beginning and at its end. (If one forgets at the beginning)',
            reference: 'أبو داود 3767',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'eating_3',
            arabicText:
                'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ',
            translationEn:
                'Praise is to Allah Who has fed me this and provided it for me without any might or power on my part.',
            reference: 'أبو داود 4023، الترمذي 3458',
            repeatCount: 1,
            virtue: 'غُفر له ما تقدم من ذنبه',
          ),
          const AdhkarItem(
            id: 'eating_4',
            arabicText:
                'الْحَمْدُ لِلَّهِ حَمْدًا كَثِيرًا طَيِّبًا مُبَارَكًا فِيهِ غَيْرَ مَكْفِيٍّ وَلَا مُوَدَّعٍ وَلَا مُسْتَغْنًى عَنْهُ رَبَّنَا',
            translationEn:
                'All praise is to Allah, praise that is abundant, pure and full of blessing, that is not offered to show independence from Him, nor the kind offered when bidding farewell, nor the kind that can be done without, O our Lord.',
            reference: 'البخاري 5458',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'eating_5',
            arabicText:
                'اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَأَطْعِمْنَا خَيْرًا مِنْهُ',
            translationEn:
                'O Allah, bless us in it and feed us with what is better than it. (When drinking milk)',
            reference: 'الترمذي 3455',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'eating_6',
            arabicText:
                'اللَّهُمَّ أَطْعِمْ مَنْ أَطْعَمَنِي وَاسْقِ مَنْ سَقَانِي',
            translationEn:
                'O Allah, feed the one who fed me and give drink to the one who gave me drink.',
            reference: 'مسلم 2055',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الدخول والخروج ──────────────────────────────────────────
  static AdhkarCategory get _homeMosqueAdhkar => AdhkarCategory(
        id: 'home_mosque',
        titleAr: 'أذكار الدخول والخروج',
        titleEn: 'Entering & Leaving',
        subtitleAr: 'دخول المنزل والمسجد والخروج',
        subtitleEn: 'Home, mosque, and going out',
        icon: Icons.home_rounded,
        color: const Color(0xFF1565C0),
        group: AdhkarGroup.homeTavel,
        items: [
          const AdhkarItem(
            id: 'entry_1',
            arabicText:
                'بِسْمِ اللَّهِ وَلَجْنَا وَبِسْمِ اللَّهِ خَرَجْنَا وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا',
            translationEn:
                'In the name of Allah we enter and in the name of Allah we leave, and upon Allah our Lord we rely.',
            reference: 'أبو داود 5096',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'entry_2',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلِجِ وَخَيْرَ الْمَخْرَجِ بِسْمِ اللَّهِ وَلَجْنَا وَبِسْمِ اللَّهِ خَرَجْنَا وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا',
            translationEn:
                'O Allah, I ask You for the good of the entrance and the good of the exit. In the name of Allah we enter, in the name of Allah we leave, and upon Allah our Lord we rely.',
            reference: 'أبو داود 5096',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'entry_3',
            arabicText:
                'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
            translationEn:
                'O Allah, open the gates of Your mercy for me. (Entering the mosque)',
            reference: 'مسلم 713',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'entry_4',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
            translationEn:
                'O Allah, I ask You of Your bounty. (Leaving the mosque)',
            reference: 'مسلم 713',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'entry_5',
            arabicText:
                'بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
            translationEn:
                'In the name of Allah, I place my trust in Allah, and there is no might nor power except with Allah. (Leaving home)',
            reference: 'أبو داود 5095',
            repeatCount: 1,
            virtue: 'يقال له: كُفيت ووُقيت وهُديت',
          ),
          const AdhkarItem(
            id: 'entry_6',
            arabicText:
                'اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى وَمِنَ الْعَمَلِ مَا تَرْضَى، اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ، اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ وَالْخَلِيفَةُ فِي الْأَهْلِ',
            translationEn:
                'O Allah, we ask You on this journey for goodness and piety, and for works that are pleasing to You. O Allah, lighten this journey for us and make its distance easy for us. O Allah, You are our Companion on the road and the One Who stays behind to look after the family.',
            reference: 'مسلم 1342 – دعاء السفر',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أدعية متنوعة ─────────────────────────────────────────────────
  static AdhkarCategory get _miscDuas => AdhkarCategory(
        id: 'misc',
        titleAr: 'أدعية متنوعة',
        titleEn: 'Miscellaneous Duas',
        subtitleAr: 'أدعية جامعة مأثورة',
        subtitleEn: 'General authentic supplications',
        icon: Icons.volunteer_activism_rounded,
        color: const Color(0xFF558B2F),
        group: AdhkarGroup.occasions,
        items: [
          const AdhkarItem(
            id: 'misc_1',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَأَعُوذُ بِكَ مِنَ النَّارِ',
            translationEn:
                'O Allah, I ask You for Paradise and I seek refuge in You from the Fire.',
            reference: 'أبو داود 792',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_2',
            arabicText:
                'اللَّهُمَّ اغْفِرْ لِي وَارْحَمْنِي وَاهْدِنِي وَعَافِنِي وَارْزُقْنِي',
            translationEn:
                'O Allah, forgive me, have mercy on me, guide me, give me health and grant me provision.',
            reference: 'مسلم 2697',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_3',
            arabicText:
                'اللَّهُمَّ إِنِّي أَعُوذُ بِرِضَاكَ مِنْ سَخَطِكَ وَبِمُعَافَاتِكَ مِنْ عُقُوبَتِكَ وَأَعُوذُ بِكَ مِنْكَ لَا أُحْصِي ثَنَاءً عَلَيْكَ أَنْتَ كَمَا أَثْنَيْتَ عَلَى نَفْسِكَ',
            translationEn:
                'O Allah, I seek refuge in Your pleasure from Your anger, and in Your forgiveness from Your punishment, and I seek refuge in You from You. I cannot enumerate Your praise, You are as You have praised Yourself.',
            reference: 'مسلم 486',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_4',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنَ الْخَيْرِ كُلِّهِ عَاجِلِهِ وَآجِلِهِ مَا عَلِمْتُ مِنْهُ وَمَا لَمْ أَعْلَمْ وَأَعُوذُ بِكَ مِنَ الشَّرِّ كُلِّهِ عَاجِلِهِ وَآجِلِهِ مَا عَلِمْتُ مِنْهُ وَمَا لَمْ أَعْلَمْ',
            translationEn:
                'O Allah, I ask You for all good, immediate and in the future, that which I know and that which I do not know. And I seek refuge in You from all evil, immediate and in the future, that which I know and that which I do not know.',
            reference: 'ابن ماجه 3846',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_5',
            arabicText:
                'اللَّهُمَّ أَصْلِحْ لِي دِينِي الَّذِي هُوَ عِصْمَةُ أَمْرِي وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي وَأَصْلِحْ لِي آخِرَتِي الَّتِي فِيهَا مَعَادِي وَاجْعَلِ الْحَيَاةَ زِيَادَةً لِي فِي كُلِّ خَيْرٍ وَاجْعَلِ الْمَوْتَ رَاحَةً لِي مِنْ كُلِّ شَرٍّ',
            translationEn:
                'O Allah, set right for me my religion which is the safeguard of my affairs. And set right for me the affairs of my world wherein is my livelihood. And set right for me my Hereafter on which depends my after-life. And make the life for me a source of abundance for every good, and make my death a source of comfort for me protecting me against every evil.',
            reference: 'مسلم 2720',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_6',
            arabicText:
                'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا أَنْتَ أَسْتَغْفِرُكَ وَأَتُوبُ إِلَيْكَ',
            translationEn:
                'How perfect You are O Allah, and all praise is for You, I bear witness that none has the right to be worshipped except You. I seek Your forgiveness and turn to You in repentance. (Kaffarah al-Majlis)',
            reference: 'الترمذي 3433',
            repeatCount: 1,
            virtue:
                'كفارة المجلس – من قالها في المجلس صارت كفارةً له',
          ),
          const AdhkarItem(
            id: 'misc_7',
            arabicText:
                'اللَّهُمَّ إِنِّي ظَلَمْتُ نَفْسِي ظُلْمًا كَثِيرًا وَلَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ فَاغْفِرْ لِي مَغْفِرَةً مِنْ عِنْدِكَ وَارْحَمْنِي إِنَّكَ أَنْتَ الْغَفُورُ الرَّحِيمُ',
            translationEn:
                'O Allah, I have greatly wronged myself and no one forgives sins but You. So grant me forgiveness and have mercy on me. Surely, you are Forgiving, Merciful.',
            reference: 'البخاري 834، مسلم 2705',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_8',
            arabicText:
                'اللَّهُمَّ اجْعَلْنِي مِنَ الَّذِينَ إِذَا أَحْسَنُوا اسْتَبْشَرُوا وَإِذَا أَسَاءُوا اسْتَغْفَرُوا',
            translationEn:
                'O Allah, make me of those who, when they do good, feel happiness, and when they do evil, seek forgiveness.',
            reference: 'ابن ماجه 3820',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_9',
            arabicText:
                'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
            translationEn:
                'O Ever Living, O Self-Sustaining and Supporter of all, by Your mercy I seek assistance. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.',
            reference: 'السلسلة الصحيحة 227',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'misc_10',
            arabicText:
                'اللَّهُمَّ لَكَ أَسْلَمْتُ وَبِكَ آمَنْتُ وَعَلَيْكَ تَوَكَّلْتُ وَإِلَيْكَ أَنَبْتُ وَبِكَ خَاصَمْتُ اللَّهُمَّ إِنِّي أَعُوذُ بِعِزَّتِكَ لَا إِلَٰهَ إِلَّا أَنْتَ أَنْ تُضِلَّنِي أَنْتَ الْحَيُّ الَّذِي لَا يَمُوتُ وَالْجِنُّ وَالْإِنْسُ يَمُوتُونَ',
            translationEn:
                'O Allah, to You I have submitted, and in You I have believed, and in You I put my trust, and to You I turn repentantly, and for Your sake I dispute. O Allah, I seek refuge in Your glory – there is no deity except You – from being led astray. You are the Ever-Living Who does not die, while the jinn and mankind die.',
            reference: 'البخاري 7383، مسلم 2717',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الوضوء ──────────────────────────────────────────────────
  static AdhkarCategory get _wuduAdhkar => AdhkarCategory(
        id: 'wudu',
        titleAr: 'أذكار الوضوء',
        titleEn: 'Wudu Adhkar',
        subtitleAr: 'قبل الوضوء وبعده',
        subtitleEn: 'Before and after ablution',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF0288D1),
        group: AdhkarGroup.prayer,
        items: [
          const AdhkarItem(
            id: 'wudu_1',
            arabicText: 'بِسْمِ اللَّهِ',
            translationEn: 'In the name of Allah. (Before wudu)',
            reference: 'أبو داود 101، ابن ماجه 399',
            repeatCount: 1,
            virtue: 'لا وضوء لمن لم يذكر اسم الله عليه',
          ),
          const AdhkarItem(
            id: 'wudu_2',
            arabicText: '[بِسْمِ اللَّهِ] اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ',
            translationEn:
                '[In the name of Allah] O Allah, I seek refuge in You from the male and female devils. (Entering the toilet)',
            reference: 'البخاري 142، مسلم 375',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'wudu_3',
            arabicText: 'غُفْرَانَكَ',
            translationEn: 'I seek Your forgiveness. (Upon leaving the toilet)',
            reference: 'أبو داود 30، الترمذي 7',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'wudu_4',
            arabicText:
                'أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
            translationEn:
                'I bear witness that none has the right to be worshipped except Allah alone, without partner, and I bear witness that Muhammad is His servant and messenger. (After wudu)',
            reference: 'مسلم 234',
            repeatCount: 1,
            virtue: 'فُتحت له أبواب الجنة الثمانية يدخل من أيها شاء',
          ),
          const AdhkarItem(
            id: 'wudu_5',
            arabicText: 'اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ',
            translationEn:
                'O Allah, make me among those who repent and make me among those who purify themselves. (After wudu)',
            reference: 'الترمذي 55',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'wudu_6',
            arabicText:
                'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا أَنْتَ أَسْتَغْفِرُكَ وَأَتُوبُ إِلَيْكَ',
            translationEn:
                'How perfect You are O Allah, and all praise is for You. I bear witness that none has the right to be worshipped except You. I seek Your forgiveness and turn to You in repentance. (After wudu)',
            reference: 'النسائي في السنن الكبرى 9909',
            repeatCount: 1,
          ),
        ],
      );

  // ─── دعاء الاستخارة ──────────────────────────────────────────────
  static AdhkarCategory get _istikharaAdhkar => AdhkarCategory(
        id: 'istikhara',
        titleAr: 'دعاء الاستخارة',
        titleEn: 'Istikhara Prayer',
        subtitleAr: 'للاستشارة والتوجيه من الله',
        subtitleEn: 'Seeking guidance from Allah',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFF6A1B9A),
        group: AdhkarGroup.prayer,
        items: [
          const AdhkarItem(
            id: 'istikhara_1',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ وَتَعْلَمُ وَلَا أَعْلَمُ وَأَنْتَ عَلَّامُ الْغُيُوبِ، اللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي ثُمَّ بَارِكْ لِي فِيهِ، وَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ وَاقْدُرْ لِيَ الْخَيْرَ حَيْثُ كَانَ ثُمَّ أَرْضِنِي بِهِ',
            translationEn:
                'O Allah, I seek Your counsel by Your knowledge and by Your power I seek strength and I ask You from Your immense favour, for verily You are able while I am not and verily You know while I do not and You are the Knower of the unseen. O Allah, if in Your knowledge this matter is good for me in my religion, my life and my end, then ordain it for me, make it easy for me, and bless it for me. And if in Your knowledge it is bad for me, my religion, my life and my end, then turn it away from me and turn me away from it and ordain for me the good wherever it may be and make me pleased with it.',
            reference: 'البخاري 1162 – عن جابر بن عبد الله رضي الله عنهما',
            repeatCount: 1,
            virtue:
                'كان رسول الله ﷺ يعلمنا الاستخارة في الأمور كلها كما يعلمنا السورة من القرآن',
          ),
        ],
      );

  // ─── دعاء القنوت ────────────────────────────────────────────────────
  static AdhkarCategory get _qunutAdhkar => AdhkarCategory(
        id: 'qunut',
        titleAr: 'دعاء القنوت والوتر',
        titleEn: 'Qunut & Witr',
        subtitleAr: 'دعاء الوتر والقنوت',
        subtitleEn: 'Night prayer supplications',
        icon: Icons.brightness_3_rounded,
        color: const Color(0xFF283593),
        group: AdhkarGroup.prayer,
        items: [
          const AdhkarItem(
            id: 'qunut_1',
            arabicText:
                'اللَّهُمَّ اهْدِنِي فِيمَنْ هَدَيْتَ وَعَافِنِي فِيمَنْ عَافَيْتَ وَتَوَلَّنِي فِيمَنْ تَوَلَّيْتَ وَبَارِكْ لِي فِيمَا أَعْطَيْتَ وَقِنِي شَرَّ مَا قَضَيْتَ فَإِنَّكَ تَقْضِي وَلَا يُقْضَى عَلَيْكَ وَإِنَّهُ لَا يَذِلُّ مَنْ وَالَيْتَ تَبَارَكْتَ رَبَّنَا وَتَعَالَيْتَ',
            translationEn:
                'O Allah, guide me among those You have guided, pardon me among those You have pardoned, befriend me among those You have befriended, bless me in what You have bestowed, and save me from the evil of what You have decreed. For verily You decree and none can decree over You, and he is not humiliated whom You befriend. Blessed are You our Lord and Exalted.',
            reference: 'أبو داود 1425، الترمذي 464 – دعاء القنوت',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'qunut_2',
            arabicText:
                'اللَّهُمَّ إِنِّي أَعُوذُ بِرِضَاكَ مِنْ سَخَطِكَ وَبِمُعَافَاتِكَ مِنْ عُقُوبَتِكَ وَأَعُوذُ بِكَ مِنْكَ لَا أُحْصِي ثَنَاءً عَلَيْكَ أَنْتَ كَمَا أَثْنَيْتَ عَلَى نَفْسِكَ',
            translationEn:
                'O Allah, I seek refuge in Your pleasure from Your anger, and in Your forgiveness from Your punishment, and I seek refuge in You from You. I cannot enumerate Your praises; You are as You have praised Yourself.',
            reference: 'مسلم 486 – بعد التشهد في الوتر',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'qunut_3',
            arabicText: 'سُبْحَانَ الْمَلِكِ الْقُدُّوسِ',
            translationEn: 'How perfect is the Sovereign, the Most Holy. (After Witr, 3 times)',
            reference: 'أبو داود 1430، النسائي 1699',
            repeatCount: 3,
            virtue: 'كان النبي ﷺ يقولها بعد الوتر برفع الصوت في الثالثة',
          ),
          const AdhkarItem(
            id: 'qunut_4',
            arabicText:
                'اللَّهُمَّ إِنَّا نَسْتَعِينُكَ وَنَسْتَغْفِرُكَ وَنُؤْمِنُ بِكَ وَنَتَوَكَّلُ عَلَيْكَ وَنُثْنِي عَلَيْكَ الْخَيْرَ وَنَشْكُرُكَ وَلَا نَكْفُرُكَ وَنَخْلَعُ وَنَتْرُكُ مَنْ يَفْجُرُكَ',
            translationEn:
                'O Allah, we seek Your help, Your forgiveness, we believe in You, we put our trust in You, we praise You in the best manner, we thank You, we are not ungrateful to You, and we forsake and turn away from the one who disobeys You.',
            reference: 'البيهقي 2/211 – قنوت النبي ﷺ',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار السفر ─────────────────────────────────────────────────
  static AdhkarCategory get _travelAdhkar => AdhkarCategory(
        id: 'travel',
        titleAr: 'أذكار السفر',
        titleEn: 'Travel Adhkar',
        subtitleAr: 'للسفر والركوب والعودة',
        subtitleEn: 'For travel, riding and return',
        icon: Icons.flight_rounded,
        color: const Color(0xFF00838F),
        group: AdhkarGroup.homeTavel,
        items: [
          const AdhkarItem(
            id: 'travel_1',
            arabicText:
                'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
            translationEn:
                'How perfect He is, the One Who has placed this (transportation) at our service, and we ourselves would not have been capable of that. And to our Lord is our final destiny.',
            reference: 'الزخرف: 13-14 – عند الركوب',
            repeatCount: 1,
            virtue: 'ثم يحمد الله ثلاثاً ويكبر ثلاثاً',
          ),
          const AdhkarItem(
            id: 'travel_2',
            arabicText:
                'اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى وَمِنَ الْعَمَلِ مَا تَرْضَى، اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ، اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ وَالْخَلِيفَةُ فِي الْأَهْلِ، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ وَعْثَاءِ السَّفَرِ وَكَآبَةِ الْمَنْظَرِ وَسُوءِ الْمُنْقَلَبِ فِي الْمَالِ وَالْأَهْلِ',
            translationEn:
                'O Allah, we ask You for righteousness and piety in this journey of ours, and for deeds which please You. O Allah, make this journey easy for us and fold up its distance for us. O Allah, You are the Companion during the journey and the Guardian of the family. O Allah, I seek refuge in You from the difficulties of travel, from having a change of heart, and from being in a bad state upon returning to my family and wealth.',
            reference: 'مسلم 1342 – دعاء السفر',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'travel_3',
            arabicText:
                'اللَّهُمَّ رَبَّ السَّمَوَاتِ السَّبْعِ وَمَا أَظْلَلْنَ وَرَبَّ الْأَرَضِينَ السَّبْعِ وَمَا أَقْلَلْنَ وَرَبَّ الشَّيَاطِينِ وَمَا أَضْلَلْنَ وَرَبَّ الرِّيَاحِ وَمَا ذَرَيْنَ أَسْأَلُكَ خَيْرَ هَذِهِ الْقَرْيَةِ وَخَيْرَ أَهْلِهَا وَأَعُوذُ بِكَ مِنْ شَرِّهَا وَشَرِّ أَهْلِهَا وَشَرِّ مَا فِيهَا',
            translationEn:
                'O Allah, Lord of the seven heavens and all they overshadow, Lord of the seven earths and all they carry, Lord of the devils and all they lead astray, Lord of the winds and all they scatter. I ask You for the goodness of this town and the goodness of its inhabitants, and seek refuge in You from its evil, the evil of its inhabitants, and the evil within it. (Entering a town)',
            reference: 'أبو داود 2632',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'travel_4',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
            translationEn:
                'None has the right to be worshipped except Allah, alone, without partner. To Him belongs all sovereignty and all praise, and He is over all things omnipotent. O Allah, I ask You of Your bounty. (Entering the marketplace)',
            reference: 'الحاكم 1/538، ابن ماجه 2235',
            repeatCount: 1,
            virtue: 'كتب الله له ألف ألف حسنة ومحا عنه ألف ألف سيئة',
          ),
          const AdhkarItem(
            id: 'travel_5',
            arabicText: 'أَسْتَوْدِعُكُمُ اللَّهَ الَّذِي لَا تَضِيعُ وَدَائِعُهُ',
            translationEn:
                'I entrust you to Allah, whose trusts are never lost. (Saying farewell to those staying)',
            reference: 'ابن ماجه 2825',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'travel_6',
            arabicText:
                'آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ',
            translationEn:
                'We are those who return, those who repent, those who worship our Lord and those who praise Him. (Upon returning from journey)',
            reference: 'البخاري 3084، مسلم 1342',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'travel_7',
            arabicText:
                'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ وَعْثَاءِ السَّفَرِ وَكَآبَةِ الْمُنْقَلَبِ وَسُوءِ الْمَنْظَرِ فِي الْأَهْلِ وَالْمَالِ وَالْوَلَدِ',
            translationEn:
                'O Allah, I seek refuge in You from the difficulties of the journey, unhappiness upon returning, and from a bad sight with regards to family, wealth and children. (Dua upon setting out on travel)',
            reference: 'مسلم 1343',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الصيام ────────────────────────────────────────────────
  static AdhkarCategory get _fastingAdhkar => AdhkarCategory(
        id: 'fasting',
        titleAr: 'أذكار الصيام',
        titleEn: 'Fasting Adhkar',
        subtitleAr: 'أدعية الإفطار ومواقف الصائم',
        subtitleEn: 'Breaking fast and fasting moments',
        icon: Icons.nightlight_round,
        color: const Color(0xFF827717),
        group: AdhkarGroup.food,
        items: [
          const AdhkarItem(
            id: 'fasting_1',
            arabicText:
                'ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
            translationEn:
                'The thirst has gone and the veins are quenched, and reward is confirmed if Allah wills. (At breaking fast)',
            reference: 'أبو داود 2357',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'fasting_2',
            arabicText:
                'اللَّهُمَّ لَكَ صُمْتُ وَعَلَى رِزْقِكَ أَفْطَرْتُ',
            translationEn:
                'O Allah, for You I have fasted and upon Your provision I have broken my fast.',
            reference: 'أبو داود 2358',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'fasting_3',
            arabicText:
                'اللَّهُمَّ بَارِكْ لَهُمْ فِيمَا رَزَقْتَهُمْ وَاغْفِرْ لَهُمْ وَارْحَمْهُمْ',
            translationEn:
                'O Allah, bless them in what You have provided for them, forgive them and have mercy on them. (When invited to eat while fasting)',
            reference: 'مسلم 2054',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'fasting_4',
            arabicText: 'إِنِّي صَائِمٌ',
            translationEn:
                'I am fasting. (When someone tries to argue with the fasting person)',
            reference: 'مسلم 1151',
            repeatCount: 1,
            virtue: 'فإن امرؤ قاتله أو شاتمه فليقل إني صائم',
          ),
          const AdhkarItem(
            id: 'fasting_5',
            arabicText:
                'اللَّهُمَّ أَطْعِمْ مَنْ أَطْعَمَنِي وَاسْقِ مَنْ سَقَانِي',
            translationEn:
                'O Allah, feed the one who fed me and give drink to the one who gave me drink.',
            reference: 'مسلم 2055',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أدعية الهم والكرب ───────────────────────────────────────────
  static AdhkarCategory get _distressAdhkar => AdhkarCategory(
        id: 'distress',
        titleAr: 'أدعية الهم والكرب',
        titleEn: 'Distress & Grief',
        subtitleAr: 'عند الضيق والشدة والحزن',
        subtitleEn: 'In times of worry and hardship',
        icon: Icons.healing_rounded,
        color: const Color(0xFFC62828),
        group: AdhkarGroup.health,
        items: [
          const AdhkarItem(
            id: 'distress_1',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَٰهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَٰهَ إِلَّا اللَّهُ رَبُّ السَّمَوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ',
            translationEn:
                'There is no deity except Allah, the Magnificent, the Forbearing. There is no deity except Allah, Lord of the Magnificent Throne. There is no deity except Allah, Lord of the heavens, Lord of the earth and Lord of the Noble Throne.',
            reference: 'البخاري 6346، مسلم 2730',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'distress_2',
            arabicText:
                'اللَّهُمَّ رَحْمَتَكَ أَرْجُو فَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ وَأَصْلِحْ لِي شَأْنِي كُلَّهُ لَا إِلَٰهَ إِلَّا أَنْتَ',
            translationEn:
                'O Allah, it is Your mercy that I hope for, so do not leave me in charge of my affairs even for the blink of an eye; and rectify all my affairs. None has the right to be worshipped except You.',
            reference: 'أبو داود 5090',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'distress_3',
            arabicText:
                'لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
            translationEn:
                'There is no deity except You, glorified are You. Indeed I was among the wrongdoers. (Dua of Yunus)',
            reference: 'الأنبياء: 87، الترمذي 3505',
            repeatCount: 1,
            virtue: 'ما دعا بها مسلم في شيء إلا استجاب الله له',
          ),
          const AdhkarItem(
            id: 'distress_4',
            arabicText:
                'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
            translationEn:
                'O Ever-Living, O Self-Sustaining Sustainer of all, by Your mercy I call for help. Correct all of my affairs and do not leave me to myself, even for the blink of an eye.',
            reference: 'الحاكم 1/730 – وصححه',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'distress_5',
            arabicText:
                'اللَّهُ اللَّهُ رَبِّي لَا أُشْرِكُ بِهِ شَيْئًا',
            translationEn:
                'Allah, Allah is my Lord; I do not associate anything with Him.',
            reference: 'أبو داود 1525',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'distress_6',
            arabicText: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
            translationEn:
                'Sufficient for us is Allah, and He is the best disposer of affairs.',
            reference: 'آل عمران: 173',
            repeatCount: 1,
            virtue: 'قالها إبراهيم ﷺ حين أُلقي في النار وقالها محمد ﷺ حين قيل له إن الناس قد جمعوا لكم',
          ),
        ],
      );

  // ─── دعاء المريض والرقية ────────────────────────────────────────
  static AdhkarCategory get _illnessAdhkar => AdhkarCategory(
        id: 'illness',
        titleAr: 'دعاء المريض والرقية',
        titleEn: 'Illness & Ruqyah',
        subtitleAr: 'عند المرض والألم والعيادة',
        subtitleEn: 'During illness and visiting the sick',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF00796B),
        group: AdhkarGroup.health,
        items: [
          const AdhkarItem(
            id: 'illness_1',
            arabicText:
                'بِسْمِ اللَّهِ أَرْقِيكَ مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ اللَّهُ يَشْفِيكَ بِسْمِ اللَّهِ أَرْقِيكَ',
            translationEn:
                'In the name of Allah I perform ruqyah for you, from everything that is harming you, from the evil of every soul or envious eye. Allah heals you. In the name of Allah I perform ruqyah for you.',
            reference: 'مسلم 2186',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'illness_2',
            arabicText:
                'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ',
            translationEn:
                'I seek refuge in the perfect words of Allah, from every devil and every poisonous pest, and from every evil eye.',
            reference: 'البخاري 3371 – رقية الأطفال',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'illness_3',
            arabicText:
                'أَذْهِبِ الْبَاسَ رَبَّ النَّاسِ وَاشْفِ أَنْتَ الشَّافِي لَا شِفَاءَ إِلَّا شِفَاؤُكَ شِفَاءً لَا يُغَادِرُ سَقَمًا',
            translationEn:
                'Take away the hardship, O Lord of people, and give cure. You are the One Who cures and there is no cure except Your cure, a cure that leaves no illness behind.',
            reference: 'البخاري 5750، مسلم 2191',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'illness_4',
            arabicText:
                'أَعُوذُ بِعِزَّةِ اللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ',
            translationEn:
                'I seek refuge in the might of Allah and His power from the evil of what I find and what I am wary of. (For pain in the body – put hand on the painful spot)',
            reference: 'مسلم 2202',
            repeatCount: 7,
          ),
          const AdhkarItem(
            id: 'illness_5',
            arabicText: 'لَا بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ',
            translationEn:
                'No harm, a purification, if Allah wills. (Said to the sick person when visiting)',
            reference: 'البخاري 3616',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'illness_6',
            arabicText:
                'اللَّهُمَّ اشْفِ [فلان] شِفَاءً لَا يُغَادِرُ سَقَمًا',
            translationEn:
                'O Allah, heal [person\'s name] with a healing that leaves no illness behind. (Dua for the sick)',
            reference: 'ابن ماجه 3501',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الطقس ──────────────────────────────────────────────────
  static AdhkarCategory get _weatherAdhkar => AdhkarCategory(
        id: 'weather',
        titleAr: 'أذكار الطقس والطبيعة',
        titleEn: 'Weather & Nature',
        subtitleAr: 'عند الريح والمطر والرعد والهلال',
        subtitleEn: 'Wind, rain, thunder and moon',
        icon: Icons.wb_cloudy_rounded,
        color: const Color(0xFF0277BD),
        group: AdhkarGroup.health,
        items: [
          const AdhkarItem(
            id: 'weather_1',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَهَا وَخَيْرَ مَا فِيهَا وَخَيْرَ مَا أُرْسِلَتْ بِهِ وَأَعُوذُ بِكَ مِنْ شَرِّهَا وَشَرِّ مَا فِيهَا وَشَرِّ مَا أُرْسِلَتْ بِهِ',
            translationEn:
                'O Allah, I ask You for the good of it and the good of what is in it and the good of what it has been sent with. And I seek refuge in You from its evil, the evil of what is in it and the evil of what it has been sent with. (When the wind blows)',
            reference: 'مسلم 899',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'weather_2',
            arabicText:
                'سُبْحَانَ الَّذِي يُسَبِّحُ الرَّعْدُ بِحَمْدِهِ وَالْمَلَائِكَةُ مِنْ خِيفَتِهِ',
            translationEn:
                'Glorified is He whom the thunder exalts with His praise and likewise the angels because of fear of Him. (When hearing thunder)',
            reference: 'الموطأ 2/992',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'weather_3',
            arabicText: 'اللَّهُمَّ صَيِّبًا نَافِعًا',
            translationEn:
                'O Allah, [make it] a beneficial rain cloud. (When it starts raining)',
            reference: 'البخاري 1032',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'weather_4',
            arabicText: 'مُطِرْنَا بِفَضْلِ اللَّهِ وَرَحْمَتِهِ',
            translationEn:
                'We have been given rain by the grace and mercy of Allah. (After rain falls)',
            reference: 'البخاري 846، مسلم 71',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'weather_5',
            arabicText:
                'اللَّهُمَّ أَغِثْنَا، اللَّهُمَّ أَغِثْنَا، اللَّهُمَّ أَغِثْنَا',
            translationEn:
                'O Allah, send us rain. O Allah, send us rain. O Allah, send us rain. (Dua for rain – istisqa)',
            reference: 'البخاري 1014',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'weather_6',
            arabicText:
                'اللَّهُمَّ أَهِلَّهُ عَلَيْنَا بِالْيُمْنِ وَالْإِيمَانِ وَالسَّلَامَةِ وَالْإِسْلَامِ رَبِّي وَرَبُّكَ اللَّهُ',
            translationEn:
                'O Allah, let this moon appear on us with security and faith, with peace and in Islam. My Lord and your Lord is Allah. (When seeing the new crescent moon)',
            reference: 'الترمذي 3451',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار المجلس ────────────────────────────────────────────────
  static AdhkarCategory get _majlisAdhkar => AdhkarCategory(
        id: 'majlis',
        titleAr: 'أذكار المجلس',
        titleEn: 'Gathering Adhkar',
        subtitleAr: 'كفارة المجلس وآداب الجلوس',
        subtitleEn: 'Kaffarah of the sitting and etiquette',
        icon: Icons.people_rounded,
        color: const Color(0xFF4527A0),
        group: AdhkarGroup.occasions,
        items: [
          const AdhkarItem(
            id: 'majlis_1',
            arabicText:
                'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا أَنْتَ أَسْتَغْفِرُكَ وَأَتُوبُ إِلَيْكَ',
            translationEn:
                'How perfect You are O Allah, and all praise is for You. I bear witness that none has the right to be worshipped except You. I seek Your forgiveness and turn to You in repentance. (Kaffarah al-Majlis)',
            reference: 'أبو داود 4859، الترمذي 3433',
            repeatCount: 1,
            virtue: 'كفارة للمجلس – تُكفّر ما قيل فيه من لغو أو سوء',
          ),
          const AdhkarItem(
            id: 'majlis_2',
            arabicText:
                'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ وَالْعَجْزِ وَالْكَسَلِ وَالْبُخْلِ وَالْجُبْنِ وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
            translationEn:
                'O Allah, I seek refuge in You from grief and sadness, from weakness and laziness, from miserliness and cowardice, from being overcome by debt and from being overpowered by men.',
            reference: 'البخاري 2893',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'majlis_3',
            arabicText:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
            translationEn:
                'O Allah, I ask You for pardon and well-being in this life and the next.',
            reference: 'ابن ماجه 3871',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'majlis_4',
            arabicText:
                'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
            translationEn:
                'O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of Majesty and Honour.',
            reference: 'مسلم 591',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'majlis_5',
            arabicText: 'جَزَاكَ اللَّهُ خَيْرًا',
            translationEn:
                'May Allah reward you with good. (Thanking someone)',
            reference: 'الترمذي 2035',
            repeatCount: 1,
            virtue: 'من صُنع إليه معروف فقال: جزاك الله خيرا فقد أبلغ في الثناء',
          ),
        ],
      );

  // ─── أذكار الجنازة ───────────────────────────────────────────────
  static AdhkarCategory get _janazaAdhkar => AdhkarCategory(
        id: 'janaza',
        titleAr: 'أذكار الجنازة والقبور',
        titleEn: 'Funeral & Graves',
        subtitleAr: 'عند الوفاة والدفن وزيارة القبور',
        subtitleEn: 'At death, burial and grave visits',
        icon: Icons.sentiment_very_satisfied_rounded,
        color: const Color(0xFF4E342E),
        group: AdhkarGroup.occasions,
        items: [
          const AdhkarItem(
            id: 'janaza_1',
            arabicText:
                'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ، اللَّهُمَّ أْجُرْنِي فِي مُصِيبَتِي وَأَخْلِفْ لِي خَيْرًا مِنْهَا',
            translationEn:
                'Indeed, to Allah we belong and to Him we shall return. O Allah, reward me for my affliction and give me something better than it in exchange.',
            reference: 'مسلم 918',
            repeatCount: 1,
            virtue: 'من قالها عند مصيبته أعطاه الله خيرا منها',
          ),
          const AdhkarItem(
            id: 'janaza_2',
            arabicText:
                'اللَّهُمَّ اغْفِرْ لِفُلَانٍ وَارْفَعْ دَرَجَتَهُ فِي الْمَهْدِيِّينَ وَاخْلُفْهُ فِي عَقِبِهِ فِي الْغَابِرِينَ وَاغْفِرْ لَنَا وَلَهُ يَا رَبَّ الْعَالَمِينَ وَافْسَحْ لَهُ فِي قَبْرِهِ وَنَوِّرْ لَهُ فِيهِ',
            translationEn:
                'O Allah, forgive [name of deceased] and elevate his station among those who are guided, send him along the path of those who came before, forgive us and him O Lord of the Worlds and make his grave spacious and illuminate it for him.',
            reference: 'مسلم 920 – عند إغماض الميت',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'janaza_3',
            arabicText:
                'اللَّهُمَّ اغْفِرْ لَهُ وَارْحَمْهُ وَعَافِهِ وَاعْفُ عَنْهُ وَأَكْرِمْ نُزُلَهُ وَوَسِّعْ مُدْخَلَهُ وَاغْسِلْهُ بِالْمَاءِ وَالثَّلْجِ وَالْبَرَدِ وَنَقِّهِ مِنَ الْخَطَايَا كَمَا نَقَّيْتَ الثَّوْبَ الْأَبْيَضَ مِنَ الدَّنَسِ',
            translationEn:
                'O Allah, forgive him and have mercy on him and give him strength and pardon him and be generous in his hospitality. Expand his entry and wash him with water, snow and hail; purify him from sin as a white garment is purified from filth.',
            reference: 'مسلم 963 – الدعاء في صلاة الجنازة',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'janaza_4',
            arabicText:
                'اللَّهُمَّ اغْفِرْ لَهُ اللَّهُمَّ ثَبِّتْهُ',
            translationEn:
                'O Allah, forgive him. O Allah, strengthen him. (After burial)',
            reference: 'أبو داود 3221',
            repeatCount: 1,
            virtue: 'استغفروا لأخيكم واسألوا له التثبيت فإنه الآن يُسأل',
          ),
          const AdhkarItem(
            id: 'janaza_5',
            arabicText:
                'السَّلَامُ عَلَيْكُمْ أَهْلَ الدِّيَارِ مِنَ الْمُؤْمِنِينَ وَالْمُسْلِمِينَ وَإِنَّا إِنْ شَاءَ اللَّهُ بِكُمْ لَاحِقُونَ يَرْحَمُ اللَّهُ الْمُسْتَقْدِمِينَ مِنَّا وَالْمُسْتَأْخِرِينَ نَسْأَلُ اللَّهَ لَنَا وَلَكُمُ الْعَافِيَةَ',
            translationEn:
                'Peace be upon you, O believing and Muslim dwellers of this place. Verily we will, if Allah wills, join you. May Allah have mercy on those who have gone ahead of us and those who will come later. We ask Allah for well-being for ourselves and for you. (When visiting graves)',
            reference: 'مسلم 975',
            repeatCount: 1,
          ),
        ],
      );

  // ─── أذكار الحج والعمرة ──────────────────────────────────────────
  static AdhkarCategory get _hajjAdhkar => AdhkarCategory(
        id: 'hajj',
        titleAr: 'أذكار الحج والعمرة',
        titleEn: 'Hajj & Umrah',
        subtitleAr: 'التلبية والطواف والسعي',
        subtitleEn: 'Talbiyah, tawaf and sa\'y',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF006064),
        group: AdhkarGroup.occasions,
        items: [
          const AdhkarItem(
            id: 'hajj_1',
            arabicText:
                'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ لَا شَرِيكَ لَكَ',
            translationEn:
                'Here I am, O Allah, here I am. Here I am, You have no partner, here I am. Verily all praise and blessings are Yours, and all sovereignty. You have no partner. (Talbiyah)',
            reference: 'البخاري 5915، مسلم 1184',
            repeatCount: 1,
            virtue: 'شعار الحج والعمرة – يُقال منذ الإحرام حتى رمي جمرة العقبة',
          ),
          const AdhkarItem(
            id: 'hajj_2',
            arabicText: 'اللَّهُ أَكْبَرُ',
            translationEn:
                'Allah is the greatest. (When touching or pointing to the Black Stone)',
            reference: 'البخاري 1613',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'hajj_3',
            arabicText:
                'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
            translationEn:
                'Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire. (Between Yemeni corner and Black Stone)',
            reference: 'البقرة: 201، أبو داود 1892',
            repeatCount: 1,
          ),
          const AdhkarItem(
            id: 'hajj_4',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ أَنْجَزَ وَعْدَهُ وَنَصَرَ عَبْدَهُ وَهَزَمَ الْأَحْزَابَ وَحْدَهُ',
            translationEn:
                'There is no deity except Allah, alone without partner. To Him belongs all sovereignty and all praise, and He is over all things omnipotent. There is no deity except Allah alone; He fulfilled His promise, aided His servant and defeated the confederates alone. (On Safa and Marwah)',
            reference: 'مسلم 1218',
            repeatCount: 3,
          ),
          const AdhkarItem(
            id: 'hajj_5',
            arabicText:
                'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            translationEn:
                'There is no deity except Allah, alone without partner. To Him belongs all sovereignty and all praise and He is over all things omnipotent. (Day of Arafah – best dua of the day)',
            reference: 'الترمذي 3585',
            repeatCount: 1,
            virtue: 'خير الدعاء دعاء يوم عرفة',
          ),
        ],
      );
}
