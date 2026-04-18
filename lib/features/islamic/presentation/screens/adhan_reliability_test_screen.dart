import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';

/// Comprehensive real-world Adhan testing screen.
///
/// Unlike "Test Now" (which fires via MethodChannel while the app is open),
/// this screen schedules REAL AlarmManager alarms at short intervals and
/// asks the user to lock the screen / kill the app to verify the full
/// native alarm → BroadcastReceiver → ForegroundService → MediaPlayer path.
class AdhanReliabilityTestScreen extends StatefulWidget {
  const AdhanReliabilityTestScreen({super.key});

  @override
  State<AdhanReliabilityTestScreen> createState() =>
      _AdhanReliabilityTestScreenState();
}

class _AdhanReliabilityTestScreenState
    extends State<AdhanReliabilityTestScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('quraan/adhan_player');

  final _settings = di.sl<SettingsService>();

  bool get isAr => _settings.getAppLanguage() == 'ar';

  // Test state
  final List<_TestItem> _tests = [];
  bool _running = false;
  Timer? _ticker;
  Map<String, dynamic> _diag = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDiagnostics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns to the app, check if any tests fired
    if (state == AppLifecycleState.resumed) {
      _checkFiredTests();
    }
  }

  Future<void> _loadDiagnostics() async {
    try {
      final diag =
          await _channel.invokeMapMethod<String, dynamic>('getDiagnostics');
      if (mounted) setState(() => _diag = diag ?? {});
    } catch (_) {}
  }

  // ── Test scheduling ──────────────────────────────────────────────────────

  /// Schedule a single real native alarm at [minutes] from now.
  Future<void> _scheduleRealAlarm({
    required int testId,
    required int minutes,
    required String label,
  }) async {
    final when = DateTime.now().add(Duration(minutes: minutes));
    final alarmId = 990000 + testId;

    // Write the scheduled time to prefs so we can verify later even if app is killed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'adhan_test_$alarmId', when.millisecondsSinceEpoch.toString());

    // Schedule exactly like the real prayer path: MethodChannel → AdhanAlarmReceiver → AlarmManager.setAlarmClock()
    await _channel.invokeMethod('scheduleAdhanAlarms', {
      'alarms': [
        {
          'id': alarmId,
          'timeMs': when.millisecondsSinceEpoch,
          'arabicName': label,
        }
      ],
      'soundName': _settings.getSelectedAdhanSound(),
      'shortMode': true,
      'shortCutoffSeconds': 6,
      'onlineUrl': null,
      'fallbackSoundName': 'adhan_1',
      'useAlarmStream': _settings.getAdhanAudioStream() == 'alarm',
    });
  }

  /// Run the full test suite: 3 alarms at 1, 2, and 3 minutes.
  Future<void> _startFullTest() async {
    if (_running) return;
    setState(() {
      _running = true;
      _tests.clear();
    });

    await _loadDiagnostics();

    final now = DateTime.now();
    final testSuite = [
      (id: 1, min: 1, label: isAr ? 'اختبار ١: الأذان (شاشة مفتوحة)' : 'Test 1: Adhan (screen open)'),
      (id: 2, min: 2, label: isAr ? 'اختبار ٢: الأذان (أقفل الشاشة الآن!)' : 'Test 2: Adhan (lock screen now!)'),
      (id: 3, min: 3, label: isAr ? 'اختبار ٣: الأذان (اخرج من التطبيق!)' : 'Test 3: Adhan (leave the app!)'),
    ];

    final items = <_TestItem>[];
    for (final t in testSuite) {
      final fireAt = now.add(Duration(minutes: t.min));
      await _scheduleRealAlarm(
        testId: t.id,
        minutes: t.min,
        label: t.label,
      );
      items.add(_TestItem(
        id: t.id,
        label: t.label,
        scheduledAt: fireAt,
        alarmId: 990000 + t.id,
      ));
    }

    setState(() => _tests.addAll(items));

    // Start countdown ticker
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkFiredTests();
      setState(() {}); // refresh countdowns
      // Stop ticker if all tests resolved
      if (_tests.every((t) => t.status != _TestStatus.pending)) {
        _ticker?.cancel();
      }
    });
  }

  /// Check SharedPreferences for fired-alarm markers written by AdhanAlarmReceiver.
  Future<void> _checkFiredTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force re-read from disk

    bool changed = false;
    final now = DateTime.now();
    for (final test in _tests) {
      if (test.status != _TestStatus.pending) continue;

      // Check if the alarm actually fired by checking if AdhanPlayerService.isPlaying
      // was set, or if the alarm time has passed + we can detect the fired marker.
      // On Android, the BroadcastReceiver writes a "last_fired" timestamp to prefs.
      final firedKey = 'adhan_test_fired_${test.alarmId}';
      final firedStr = prefs.getString(firedKey);

      if (firedStr != null) {
        test.status = _TestStatus.passed;
        test.firedAt = DateTime.fromMillisecondsSinceEpoch(int.parse(firedStr));
        changed = true;
      } else if (now.isAfter(test.scheduledAt.add(const Duration(seconds: 30)))) {
        // 30 seconds grace period passed — mark as failed
        test.status = _TestStatus.failed;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  /// Schedule a single quick alarm for [minutes] from now. Good for one-off testing.
  Future<void> _scheduleSingleTest(int minutes) async {
    final testId = DateTime.now().millisecondsSinceEpoch % 1000;
    final when = DateTime.now().add(Duration(minutes: minutes));

    await _scheduleRealAlarm(
      testId: testId,
      minutes: minutes,
      label: isAr ? 'اختبار سريع ($minutes دقيقة)' : 'Quick test ($minutes min)',
    );

    setState(() {
      _tests.add(_TestItem(
        id: testId,
        label: isAr ? 'اختبار سريع ($minutes دقيقة)' : 'Quick test ($minutes min)',
        scheduledAt: when,
        alarmId: 990000 + testId,
      ));
    });

    // Start ticker if not already running
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkFiredTests();
      setState(() {});
      if (_tests.every((t) => t.status != _TestStatus.pending)) {
        _ticker?.cancel();
      }
    });
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return isAr ? 'انتهى' : 'Done';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final s = dt.second;
    final ampm = h >= 12 ? (isAr ? 'م' : 'PM') : (isAr ? 'ص' : 'AM');
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} $ampm';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'اختبار موثوقية الأذان' : 'Adhan Reliability Test'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── System status card ───────────────────────────────────────
            _buildSystemStatusCard(cs, isDark),
            const SizedBox(height: 16),

            // ── Instructions ─────────────────────────────────────────────
            Card(
              color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'كيف يعمل الاختبار؟' : 'How does the test work?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? '• يُجدول أذانات حقيقية عبر AlarmManager (نفس مسار الأذان الفعلي)\n'
                            '• الاختبار ١: اترك التطبيق مفتوحًا — يجب أن يعمل\n'
                            '• الاختبار ٢: أقفل الشاشة قبل الدقيقة الثانية\n'
                            '• الاختبار ٣: اخرج من التطبيق تمامًا (أغلقه من Recent Apps)\n'
                            '• ارجع بعد ٤ دقائق لمراجعة النتائج'
                          : '• Schedules real Adhan alarms via AlarmManager (same path as real Adhan)\n'
                            '• Test 1: Keep the app open — it should fire\n'
                            '• Test 2: Lock the screen before the 2nd minute\n'
                            '• Test 3: Leave the app completely (close from Recent Apps)\n'
                            '• Come back after 4 minutes to review results',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color:
                            isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Full test suite button ────────────────────────────────────
            FilledButton.icon(
              onPressed: _running ? null : _startFullTest,
              icon: Icon(_running ? Icons.hourglass_top : Icons.play_arrow),
              label: Text(
                  _running
                      ? (isAr ? 'الاختبار جاري...' : 'Test in progress...')
                      : (isAr ? 'بدء اختبار شامل (٣ دقائق)' : 'Start full test (3 minutes)')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 12),

            // ── Quick single tests ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleSingleTest(1),
                    icon: const Icon(Icons.timer, size: 18),
                    label: Text(isAr ? 'بعد دقيقة' : 'In 1 min'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleSingleTest(2),
                    icon: const Icon(Icons.timer, size: 18),
                    label: Text(isAr ? 'بعد دقيقتين' : 'In 2 min'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleSingleTest(5),
                    icon: const Icon(Icons.timer, size: 18),
                    label: Text(isAr ? 'بعد ٥ دقائق' : 'In 5 min'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Test results ─────────────────────────────────────────────
            if (_tests.isNotEmpty) ...[
              Text(
                isAr ? 'نتائج الاختبار' : 'Test Results',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ..._tests.map((t) => _buildTestCard(t, cs, isDark)),
            ],

            // ── Manual checklist ─────────────────────────────────────────
            const SizedBox(height: 24),
            _buildChecklistCard(cs, isDark),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard(ColorScheme cs, bool isDark) {
    final battOpt = _diag['batteryOptimizationDisabled'] == true;
    final exactAlarms = _diag['canScheduleExactAlarms'] == true;
    final bucket = _diag['appStandbyBucket'] ?? -1;
    final mfr = _diag['manufacturer'] ?? '';
    final sdk = _diag['sdkVersion'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'حالة النظام' : 'System Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            _statusRow(isAr ? 'تحسين البطارية معطّل' : 'Battery Optimization Disabled', battOpt, cs, isDark),
            _statusRow(isAr ? 'صلاحية الأذانات الدقيقة' : 'Exact Alarm Permission', exactAlarms, cs, isDark),
            _statusRow(
              isAr ? 'مستوى الأولوية' : 'Priority Level',
              bucket <= 10, // ACTIVE=5, WORKING=10, FREQUENT=20, RARE=30, RESTRICTED=40+
              cs,
              isDark,
              subtitle: _bucketLabel(bucket as int),
            ),
            const SizedBox(height: 4),
            Text(
              '$mfr — Android $sdk',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, bool ok, ColorScheme cs, bool isDark,
      {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error,
            color: ok
                ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                : (isDark ? Colors.red.shade300 : Colors.red.shade700),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bucketLabel(int bucket) {
    if (bucket <= 5) return isAr ? 'نشط (ممتاز)' : 'Active (Excellent)';
    if (bucket <= 10) return isAr ? 'عامل (جيد)' : 'Working (Good)';
    if (bucket <= 20) return isAr ? 'متكرر (مقبول)' : 'Frequent (OK)';
    if (bucket <= 30) return isAr ? 'نادر ⚠️' : 'Rare ⚠️';
    if (bucket <= 45) return isAr ? 'مقيّد 🔴' : 'Restricted 🔴';
    return isAr ? 'غير معروف' : 'Unknown';
  }

  Widget _buildTestCard(_TestItem test, ColorScheme cs, bool isDark) {
    final now = DateTime.now();
    final remaining = test.scheduledAt.difference(now);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (test.status) {
      case _TestStatus.pending:
        if (remaining.isNegative) {
          statusColor = isDark ? Colors.orange.shade300 : Colors.orange.shade700;
          statusIcon = Icons.hourglass_bottom;
          statusText = isAr ? 'في انتظار الاستجابة...' : 'Waiting for response...';
        } else {
          statusColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
          statusIcon = Icons.schedule;
          statusText = isAr ? 'متبقي ${_formatCountdown(remaining)}' : '${_formatCountdown(remaining)} left';
        }
        break;
      case _TestStatus.passed:
        statusColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
        statusIcon = Icons.check_circle;
        statusText = test.firedAt != null
            ? (isAr ? 'نجح ✓ (${_formatTime(test.firedAt!)})' : 'Passed ✓ (${_formatTime(test.firedAt!)})')
            : (isAr ? 'نجح ✓' : 'Passed ✓');
        break;
      case _TestStatus.failed:
        statusColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
        statusIcon = Icons.cancel;
        statusText = isAr ? 'فشل ✗ — لم يُسمع الأذان' : 'Failed ✗ — Adhan not heard';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 28),
        title: Text(
          test.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isAr ? 'مُجدول: ${_formatTime(test.scheduledAt)}' : 'Scheduled: ${_formatTime(test.scheduledAt)}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Text(
          statusText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistCard(ColorScheme cs, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'قائمة التحقق اليدوي' : 'Manual Checklist',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...(isAr
                ? [
                    'جدول اختبار → أقفل الشاشة → هل سمعت الأذان؟',
                    'جدول اختبار → اخرج من التطبيق (Recent Apps) → هل سمعت الأذان؟',
                    'جدول اختبار → أعد تشغيل الجهاز → هل سمعت الأذان عند الوقت المحدد؟',
                    'جدول اختبار → شغّل تطبيق آخر بصوت (يوتيوب) → هل الأذان غطى على الصوت؟',
                    'جدول اختبار → وصّل سماعة بلوتوث → هل الأذان خرج من سماعة الجهاز؟ (إذا مفعّل Force Speaker)',
                    'جدول اختبار → اتصل بحد → هل الأذان توقف أثناء المكالمة؟',
                  ]
                : [
                    'Schedule test → Lock screen → Did you hear the Adhan?',
                    'Schedule test → Leave app (Recent Apps) → Did you hear the Adhan?',
                    'Schedule test → Restart device → Did you hear the Adhan at the scheduled time?',
                    'Schedule test → Play another app audio (YouTube) → Did Adhan override it?',
                    'Schedule test → Connect Bluetooth headset → Did Adhan come from device speaker? (if Force Speaker enabled)',
                    'Schedule test → Make a phone call → Did Adhan stop during the call?',
                  ]).map(
              (text) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.radio_button_unchecked,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Models ─────────────────────────────────────────────────────────────────

enum _TestStatus { pending, passed, failed }

class _TestItem {
  final int id;
  final String label;
  final DateTime scheduledAt;
  final int alarmId;
  _TestStatus status;
  DateTime? firedAt;

  _TestItem({
    required this.id,
    required this.label,
    required this.scheduledAt,
    required this.alarmId,
  }) : status = _TestStatus.pending, firedAt = null;
}
