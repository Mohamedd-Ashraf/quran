import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/adhan_notification_service.dart';
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

  final _adhanService = di.sl<AdhanNotificationService>();
  final _settings = di.sl<SettingsService>();

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
      (id: 1, min: 1, label: 'اختبار ١: الأذان (شاشة مفتوحة)'),
      (id: 2, min: 2, label: 'اختبار ٢: الأذان (أقفل الشاشة الآن!)'),
      (id: 3, min: 3, label: 'اختبار ٣: الأذان (اخرج من التطبيق!)'),
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
      label: 'اختبار سريع ($minutes دقيقة)',
    );

    setState(() {
      _tests.add(_TestItem(
        id: testId,
        label: 'اختبار سريع ($minutes دقيقة)',
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
    if (d.isNegative) return 'انتهى';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final s = dt.second;
    final ampm = h >= 12 ? 'م' : 'ص';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} $ampm';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختبار موثوقية الأذان'),
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
                          'كيف يعمل الاختبار؟',
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
                      '• يُجدول أذانات حقيقية عبر AlarmManager (نفس مسار الأذان الفعلي)\n'
                      '• الاختبار ١: اترك التطبيق مفتوحًا — يجب أن يعمل\n'
                      '• الاختبار ٢: أقفل الشاشة قبل الدقيقة الثانية\n'
                      '• الاختبار ٣: اخرج من التطبيق تمامًا (أغلقه من Recent Apps)\n'
                      '• ارجع بعد ٤ دقائق لمراجعة النتائج',
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
                  _running ? 'الاختبار جاري...' : 'بدء اختبار شامل (٣ دقائق)'),
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
                    label: const Text('بعد دقيقة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleSingleTest(2),
                    icon: const Icon(Icons.timer, size: 18),
                    label: const Text('بعد دقيقتين'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleSingleTest(5),
                    icon: const Icon(Icons.timer, size: 18),
                    label: const Text('بعد ٥ دقائق'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Test results ─────────────────────────────────────────────
            if (_tests.isNotEmpty) ...[
              Text(
                'نتائج الاختبار',
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
              'حالة النظام',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            _statusRow('تحسين البطارية معطّل', battOpt, cs, isDark),
            _statusRow('صلاحية الأذانات الدقيقة', exactAlarms, cs, isDark),
            _statusRow(
              'مستوى الأولوية',
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
    if (bucket <= 5) return 'نشط (ممتاز)';
    if (bucket <= 10) return 'عامل (جيد)';
    if (bucket <= 20) return 'متكرر (مقبول)';
    if (bucket <= 30) return 'نادر ⚠️';
    if (bucket <= 45) return 'مقيّد 🔴';
    return 'غير معروف';
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
          statusText = 'في انتظار الاستجابة...';
        } else {
          statusColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
          statusIcon = Icons.schedule;
          statusText = 'متبقي ${_formatCountdown(remaining)}';
        }
        break;
      case _TestStatus.passed:
        statusColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
        statusIcon = Icons.check_circle;
        statusText = test.firedAt != null
            ? 'نجح ✓ (${_formatTime(test.firedAt!)})'
            : 'نجح ✓';
        break;
      case _TestStatus.failed:
        statusColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
        statusIcon = Icons.cancel;
        statusText = 'فشل ✗ — لم يُسمع الأذان';
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
          'مُجدول: ${_formatTime(test.scheduledAt)}',
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
              'قائمة التحقق اليدوي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...[
              'جدول اختبار → أقفل الشاشة → هل سمعت الأذان؟',
              'جدول اختبار → اخرج من التطبيق (Recent Apps) → هل سمعت الأذان؟',
              'جدول اختبار → أعد تشغيل الجهاز → هل سمعت الأذان عند الوقت المحدد؟',
              'جدول اختبار → شغّل تطبيق آخر بصوت (يوتيوب) → هل الأذان غطى على الصوت؟',
              'جدول اختبار → وصّل سماعة بلوتوث → هل الأذان خرج من سماعة الجهاز؟ (إذا مفعّل Force Speaker)',
              'جدول اختبار → اتصل بحد → هل الأذان توقف أثناء المكالمة؟',
            ].map(
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
    this.status = _TestStatus.pending,
    this.firedAt,
  });
}
