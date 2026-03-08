import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

class BasmallahWidget extends StatelessWidget {
  const BasmallahWidget(this.surahNumber, {super.key});
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        surahNumber == 97 || surahNumber == 95
            ? "بِّسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
            : 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
        // استخدام الكلاس المساعد هنا
        style: QuranTextStyles.hafsStyle(
          fontSize: 23.55,
          color: Theme.of(context).textTheme.bodyLarge!.color,
        ),
      ),
    );
  }
}
