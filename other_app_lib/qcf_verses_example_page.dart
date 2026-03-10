import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qcf_quran/qcf_quran.dart';

class QcfVersesExamplePage extends StatelessWidget {
  const QcfVersesExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QcfVerses Examples"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Al-Fatiha
            Text(
              "سورة الفاتحة (1:1–7)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QcfVerses(
                surahNumber: 1,
                firstVerse: 1,
                lastVerse: 7,
                sp: 1.sp,
                h: 1.h,
              ),
            ),

            const Divider(height: 40),

            /// Al-Baqarah — opening verses
            Text(
              "سورة البقرة (2:1–5)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QcfVerses(
                surahNumber: 2,
                firstVerse: 1,
                lastVerse: 5,
                sp: 1.sp,
                h: 1.h,
              ),
            ),

            const Divider(height: 40),

            /// Al-Baqarah — Ayat Al-Kursi
            Text(
              "آية الكرسي — البقرة (2:255)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QcfVerses(
                surahNumber: 2,
                firstVerse: 255,
                lastVerse: 255,
                sp: 1.2.sp,
                h: 1.h,
              ),
            ),

            const Divider(height: 40),

            /// Al-Baqarah — last two verses
            Text(
              "خواتيم البقرة (2:285–286)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QcfVerses(
                surahNumber: 2,
                firstVerse: 285,
                lastVerse: 286,
                sp: 1.sp,
                h: 1.h,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
