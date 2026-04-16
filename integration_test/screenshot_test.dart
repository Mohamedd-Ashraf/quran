// integration_test/screenshot_test.dart
//
// تصوير تلقائي لشاشات التطبيق لـ Google Play Store
// ──────────────────────────────────────────────────
// الاستخدام:
//   1) شغّل على الإميوليتر Android:
//      flutter test integration_test/screenshot_test.dart -d <android-device-id>
//      مثال: flutter test integration_test/screenshot_test.dart -d emulator-5554
//
//   2) اسحب الصور للكمبيوتر:
//      adb pull /sdcard/Pictures/quraan_play_store screenshots\raw
//
//   3) اعمل الإطارات الاحترافية:
//      python scripts\frame_screenshots.py

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quraan/main_firebase.dart' as app;

String? _outputDir;

Future<String> _resolveOutputDir() async {
  if (_outputDir != null) return _outputDir!;

  const outputDir = '/storage/emulated/0/Pictures/quraan_play_store';
  try {
    await Directory(outputDir).create(recursive: true);
    _outputDir = outputDir;
    return outputDir;
  } catch (_) {}

  final ext = await getExternalStorageDirectory();
  final baseDir = ext != null
      ? ext.path
      : (await getApplicationDocumentsDirectory()).path;
  final out = '$baseDir/quraan_play_store';
  await Directory(out).create(recursive: true);
  _outputDir = out;
  return out;
}

Future<void> _captureScreen(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
  WidgetTester tester,
  bool convertSurface,
) async {
  try {
    if (convertSurface) {
      try {
        await binding.convertFlutterSurfaceToImage();
      } catch (_) {}
      await tester.pump();
    }
    final bytes = await binding.takeScreenshot(name);
    final outDir = await _resolveOutputDir();
    final file = File('$outDir/$name.png');
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Saved screenshot: ${file.path}');
  } catch (e) {
    // ignore: avoid_print
    print('Screenshot skipped ($name): $e');
  }
}

Future<void> _tapFirst(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      return;
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Google Play screenshots flow (Android only)', (
    WidgetTester tester,
  ) async {
    if (kIsWeb || !Platform.isAndroid) {
      // ignore: avoid_print
      print(
        'Skipping: This integration test must run on Android emulator/device.',
      );
      return;
    }

    final dir = await _resolveOutputDir();
    // ignore: avoid_print
    print('Output dir: $dir');

    // Run app only once to avoid duplicate GetIt registrations.
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // 1) Home
    await _captureScreen(binding, 'home', tester, true);

    // 2) Quran (first surah tile if available)
    final surahTile = find.byType(ListTile);
    if (surahTile.evaluate().isNotEmpty) {
      await tester.tap(surahTile.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await _captureScreen(binding, 'quran', tester, false);
      if (find.byTooltip('Back').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Back').first);
      } else if (find.byType(BackButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton).first);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // 3) Wird tab
    await _tapFirst(tester, [
      find.text('الورد'),
      find.text('Wird'),
      find.byIcon(Icons.book_outlined),
      find.byIcon(Icons.menu_book_outlined),
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _captureScreen(binding, 'wird', tester, true);

    // 4) More tab
    await _tapFirst(tester, [
      find.text('المزيد'),
      find.text('More'),
      find.byIcon(Icons.grid_view_outlined),
      find.byIcon(Icons.more_horiz),
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _captureScreen(binding, 'more', tester, false);
  });
}
