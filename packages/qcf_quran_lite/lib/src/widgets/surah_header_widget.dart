import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

class SurahHeaderWidget extends StatelessWidget {
  final int suraNumber;

  const SurahHeaderWidget({super.key, required this.suraNumber});

  @override
  Widget build(BuildContext context) {
    const String imagePath = "assets/surah_banner.png";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double headerWidth = availableWidth * 0.9;
        final double dynamicFontSize = headerWidth * 0.085;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          width: double.infinity,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image(
                image: const AssetImage(imagePath, package: 'qcf_quran_lite'),
                width: headerWidth,
                fit: BoxFit.contain,
              ),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: "$suraNumber",
                  style: QuranTextStyles.surahHeaderStyle(
                    fontSize: dynamicFontSize,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
