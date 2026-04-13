// integration_test/screenshot_test.dart
//
// تصوير تلقائي لشاشات التطبيق لـ Google Play Store
// ──────────────────────────────────────────────────
// الاستخدام (خطوتين):
//
//   1) شغّل التيست على الإميوليتر:
//        flutter test integration_test/screenshot_test.dart
//
//   2) اسحب الصور من الجهاز للكمبيوتر:
//        adb pull /sdcard/Pictures/quraan_play_store  screenshots\raw
//      (أو من مسار getExternalStorageDirectory لو /sdcard/ ما اشتغلش)
//
//   3) شغّل framing script:
//        python scripts\frame_screenshots.py

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quraan/main_firebase.dart' as app;

// /sdcard/Pictures/quraan_play_store  — writable on all emulators API 21+
// On real devices (Android 10+) we also fall back to getExternalStorageDirectory.
String? _outputDir;

Future<String> _resolveOutputDir() async {
  if (_outputDir != null) return _outputDir!;
  // Try sdcard first (always works on emulator even without permission declaration)
  const sdcard = '/sdcard/Pictures/quraan_play_store';
  try {
    await Directory(sdcard).create(recursive: true);
    _outputDir = sdcard;
    return sdcard;
  } catch (_) {}
  // Fallback: app-accessible external files dir (no permission needed, API 19+)
  final ext = await getExternalStorageDirectory();
  final dir = ext != null ? ext.path : (await getApplicationDocumentsDirectory()).path;
  final out = '$dir/quraan_play_store';
  await Directory(out).create(recursive: true);
  _outputDir = out;
  return out;
}

/// يلتقط صورة الشاشة ويحفظها على الجهاز في [_resolveOutputDir()]/[name].png
Future<void> _captureScreen(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    final bytes  = await binding.takeScreenshot(name);
    final outDir = await _resolveOutputDir();
    final file   = File('$outDir/$name.png');
    await file.writeAsBytes(bytes);
    // ignore: avoid_print
    print('📸 Saved: ${file.path}');
  } catch (e) {
    // ignore: avoid_print
    print('⚠️  Screenshot skipped ($name): $e');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Google Play Store Screenshots', () {
    setUpAll(() async {
      // Resolve & create output directory on the device
      final dir = await _resolveOutputDir();
      // ignore: avoid_print
      print('📁 Output dir: $dir');
    });

    testWidgets('01 - شاشة القرآن الكريم', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // الانتظار حتى تنتهي الـ splash وتظهر الشاشة الرئيسية
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await _captureScreen(binding, 'home');
    });

    testWidgets('02 - فتح شاشة القرآن', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // الضغط على أول سورة في القائمة
      final surahTile = find.byType(ListTile).first;
      if (surahTile.evaluate().isNotEmpty) {
        await tester.tap(surahTile);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await _captureScreen(binding, 'quran');
      }
    });

    testWidgets('03 - تبويب الورد', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // البحث عن تبويب الورد في الشريط السفلي (index 2)
      final navItems = find.byType(BottomNavigationBar);
      if (navItems.evaluate().isNotEmpty) {
        // الضغط على التبويب الثالث (Wird)
        await tester.tap(find.byIcon(Icons.book_outlined).last);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await _captureScreen(binding, 'wird');
      }
    });

    testWidgets('04 - تبويب المزيد', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // الضغط على تبويب "المزيد" (index 3)
      final moreTab = find.byIcon(Icons.grid_view_outlined);
      if (moreTab.evaluate().isEmpty) {
        // جرّب أيقونة أخرى
        final tabs = find.byType(BottomNavigationBar);
        if (tabs.evaluate().isNotEmpty) {
          await tester.tap(find.byType(BottomNavigationBarItem).at(3));
        }
      } else {
        await tester.tap(moreTab.last);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _captureScreen(binding, 'more');
    });
  });
}
