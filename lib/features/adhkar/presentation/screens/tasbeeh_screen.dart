import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/tasbeeh_tutorial.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Direct Vibrator channel (bypasses haptic feedback system settings) ─────────
const _kVibrateChannel = MethodChannel('quraan/adhan_player');

// ── Tasbeeh widget refresh channel ────────────────────────────────────────────
const _kTasbeehWidgetChannel = MethodChannel('quraan/tasbeeh_widget');

Future<void> _refreshTasbeehWidget() async {
  try {
    await _kTasbeehWidgetChannel.invokeMethod<void>('refreshWidget');
  } catch (_) {}
}

Future<void> _vibrateDevice({int duration = 40, int amplitude = 180}) async {
  try {
    await _kVibrateChannel.invokeMethod<void>(
      'vibrate',
      {'duration': duration, 'amplitude': amplitude},
    );
  } catch (_) {
    HapticFeedback.mediumImpact();
  }
}

// ─── Arabic numeral helper ────────────────────────────────────────────────────
String _toAr(int n, bool isAr) {
  if (!isAr) return '$n';
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return '$n'.split('').map((c) {
    final i = int.tryParse(c);
    return i != null ? d[i] : c;
  }).join();
}

// ─── Preset dhikr list ────────────────────────────────────────────────────────
class _DhikrPreset {
  final String textAr;
  final String textEn;
  final int target;
  final Color color;
  final Color lightBg;  // soft tint for background in light mode
  final Color darkBg;   // soft tint for background in dark mode

  const _DhikrPreset({
    required this.textAr,
    required this.textEn,
    required this.target,
    required this.color,
    required this.lightBg,
    required this.darkBg,
  });
}

const List<_DhikrPreset> _kPresets = [
  _DhikrPreset(
    textAr: 'سُبْحَانَ اللَّهِ',
    textEn: 'SubhanAllah',
    target: 33,
    color: Color(0xFF0D5E3A),
    lightBg: Color(0xFFEFF8F3),
    darkBg: Color(0xFF0C2218),
  ),
  _DhikrPreset(
    textAr: 'الْحَمْدُ لِلَّهِ',
    textEn: 'Alhamdulillah',
    target: 33,
    color: Color(0xFF1B6B2F),
    lightBg: Color(0xFFEEF7F0),
    darkBg: Color(0xFF0D2213),
  ),
  _DhikrPreset(
    textAr: 'اللَّهُ أَكْبَرُ',
    textEn: 'Allahu Akbar',
    target: 34,
    color: Color(0xFF4A2080),
    lightBg: Color(0xFFF3EEF9),
    darkBg: Color(0xFF180D2A),
  ),
  _DhikrPreset(
    textAr: 'لَا إِلَٰهَ إِلَّا اللَّهُ',
    textEn: 'La Ilaha Illa Allah',
    target: 100,
    color: Color(0xFF00606A),
    lightBg: Color(0xFFEDF7F8),
    darkBg: Color(0xFF091E20),
  ),
  _DhikrPreset(
    textAr: 'أَسْتَغْفِرُ اللَّهَ',
    textEn: 'Astaghfirullah',
    target: 100,
    color: Color(0xFFAD3B14),
    lightBg: Color(0xFFFBEFEB),
    darkBg: Color(0xFF2A0F07),
  ),
  _DhikrPreset(
    textAr: 'الصَّلَاةُ عَلَى النَّبِيِّ ﷺ',
    textEn: 'Salawat on the Prophet ﷺ',
    target: 100,
    color: Color(0xFF7A6000),
    lightBg: Color(0xFFFBF7E8),
    darkBg: Color(0xFF211A00),
  ),
  _DhikrPreset(
    textAr: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
    textEn: 'HasbunAllah wa Ni\'mal Wakeel',
    target: 100,
    color: Color(0xFF2F4858),
    lightBg: Color(0xFFECF2F5),
    darkBg: Color(0xFF0C161C),
  ),
  _DhikrPreset(
    textAr: 'حرة — اضغط لتخصيص',
    textEn: 'Free — tap to customise',
    target: 0,
    color: Color(0xFF455A64),
    lightBg: Color(0xFFECF0F1),
    darkBg: Color(0xFF111518),
  ),
];

// ─── SharedPreferences keys ───────────────────────────────────────────────────
const _kPrefCount   = 'tasbeeh_count_v2';
const _kPrefTotal   = 'tasbeeh_total_v2';
const _kPrefPreset  = 'tasbeeh_preset_v2';
const _kPrefTarget  = 'tasbeeh_custom_target_v2';
const _kPrefVibrate = 'tasbeeh_vibrate_v2';

// ─── Screen ───────────────────────────────────────────────────────────────────
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int _count        = 0;
  int _totalCount   = 0;
  int _presetIndex  = 0;
  int _customTarget = 33;
  bool _vibrate     = true;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _scaleAnim;
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;
  late SharedPreferences         _prefs;
  bool _tutorialShown = false;

  // ── Derived ────────────────────────────────────────────────────────────────
  _DhikrPreset get _preset => _kPresets[_presetIndex];
  int get _target => _presetIndex == _kPresets.length - 1
      ? _customTarget
      : _preset.target;
  bool get _hasTarget => _target > 0;
  bool get _done => _hasTarget && _count >= _target;
  double get _progress => _hasTarget
      ? (_count / _target).clamp(0.0, 1.0)
      : 0.0;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.88)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 65),
    ]).animate(_pulseCtrl);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _loadPrefs();
    _showTutorialIfNeeded();
  }

  void _showTutorialIfNeeded() {
    if (_tutorialShown) return;
    _tutorialShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final svc = di.sl<TutorialService>();
      if (svc.isTutorialComplete(TutorialService.tasbeehScreen)) return;
      final isAr = context
          .read<AppSettingsCubit>()
          .state
          .appLanguageCode
          .toLowerCase()
          .startsWith('ar');
      final isDark = Theme.of(context).brightness == Brightness.dark;
      TasbeehTutorial.show(
        context: context,
        tutorialService: svc,
        isArabic: isAr,
        isDark: isDark,
      );
    });
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _count        = _prefs.getInt(_kPrefCount)  ?? 0;
      _totalCount   = _prefs.getInt(_kPrefTotal)  ?? 0;
      _presetIndex  = (_prefs.getInt(_kPrefPreset) ?? 0)
          .clamp(0, _kPresets.length - 1);
      _customTarget = _prefs.getInt(_kPrefTarget) ?? 33;
      _vibrate      = _prefs.getBool(_kPrefVibrate) ?? true;
    });
  }

  void _save() {
    _prefs.setInt(_kPrefCount,    _count);
    _prefs.setInt(_kPrefTotal,    _totalCount);
    _prefs.setInt(_kPrefPreset,   _presetIndex);
    _prefs.setInt(_kPrefTarget,   _customTarget);
    _prefs.setBool(_kPrefVibrate, _vibrate);
    _refreshTasbeehWidget();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  void _increment() {
    _pulseCtrl.forward(from: 0);
    if (_vibrate) _vibrateDevice(duration: 35, amplitude: 160);
    setState(() {
      _count++;
      _totalCount++;
    });
    _save();
    if (_hasTarget && _count == _target) {
      _vibrateDevice(duration: 120, amplitude: 255);
      _showCompletionSnack();
    }
  }

  void _reset({bool keepTotal = true}) {
    _vibrateDevice(duration: 60, amplitude: 200);
    setState(() {
      _count = 0;
      if (!keepTotal) _totalCount = 0;
    });
    _save();
  }

  void _hardReset() {
    _vibrateDevice(duration: 100, amplitude: 255);
    setState(() {
      _count      = 0;
      _totalCount = 0;
    });
    _save();
  }

  void _selectPreset(int index) {
    setState(() {
      _presetIndex = index;
      _count       = 0;
    });
    _save();
  }

  void _showCompletionSnack() {
    final isAr = context.read<AppSettingsCubit>().state.appLanguageCode
        .toLowerCase().startsWith('ar');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAr ? '🌟 أتممت الذكر — جزاك الله خيراً' : '🌟 Dhikr complete — JazakAllah Khayr',
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        backgroundColor: _preset.color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  Future<void> _openCustomiseDialog() async {
    final isAr = context.read<AppSettingsCubit>().state.appLanguageCode
        .toLowerCase().startsWith('ar');
    final ctrl = TextEditingController(
        text: _customTarget > 0 ? '$_customTarget' : '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isAr ? 'ضبط الهدف' : 'Set Target',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isAr ? 'أدخل الهدف (0 = بدون هدف)' : 'Enter target (0 = no target)',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  hintText: '33',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final v = int.tryParse(ctrl.text) ?? 0;
                Navigator.pop(ctx, v.clamp(0, 99999));
              },
              child: Text(isAr ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _customTarget = result);
      _save();
    }
  }

  Future<void> _confirmReset(bool isAr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isAr ? 'تأكيد الإعادة' : 'Confirm Reset',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(isAr ? 'هل تريد إعادة العداد إلى صفر؟' : 'Reset counter to zero?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'إعادة' : 'Reset'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _reset();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppSettingsCubit>().state.appLanguageCode
        .toLowerCase().startsWith('ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preset = _preset;

    // Per-preset tinted background
    final bgColor = isDark ? preset.darkBg : preset.lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(isAr, isDark, preset),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Islamic arabesque background ────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _ArabesquePainter(
                  color: preset.color.withValues(alpha: isDark ? 0.055 : 0.065),
                ),
              ),
            ),
            // ── Main content ────────────────────────────────────────────
            Column(
              children: [
                // Preset bar
                _PresetBar(
                  presets: _kPresets,
                  selectedIndex: _presetIndex,
                  isAr: isAr,
                  isDark: isDark,
                  presetColor: preset.color,
                  onSelect: (i) {
                    if (i == _kPresets.length - 1) {
                      _selectPreset(i);
                      _openCustomiseDialog();
                    } else {
                      _selectPreset(i);
                    }
                  },
                ),
                // Dhikr text banner
                _DhikrBanner(preset: preset, isAr: isAr, isDark: isDark),
                // Main tap area
                Expanded(
                  child: GestureDetector(
                    key: TasbeehTutorialKeys.tapArea,
                    onTap: _increment,
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: _TasbeehButton(
                          key: TasbeehTutorialKeys.counter,
                          count: _count,
                          target: _target,
                          hasTarget: _hasTarget,
                          progress: _progress,
                          isDone: _done,
                          preset: preset,
                          isAr: isAr,
                          isDark: isDark,
                          glowAnim: _glowAnim,
                        ),
                      ),
                    ),
                  ),
                ),
                // Hint / remaining / done
                _StatusLine(
                  count: _count,
                  target: _target,
                  hasTarget: _hasTarget,
                  isDone: _done,
                  preset: preset,
                  isAr: isAr,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                // Stats card
                _StatsCard(
                  count: _count,
                  total: _totalCount,
                  target: _target,
                  hasTarget: _hasTarget,
                  isAr: isAr,
                  isDark: isDark,
                  presetColor: preset.color,
                ),
                const SizedBox(height: 8),
                // Bottom actions
                _BottomActions(
                  key: TasbeehTutorialKeys.resetButton,
                  isAr: isAr,
                  isDark: isDark,
                  vibrate: _vibrate,
                  presetColor: preset.color,
                  onReset: () => _confirmReset(isAr),
                  onHardReset: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        title: Text(isAr ? 'إعادة ضبط كاملة' : 'Full Reset',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        content: Text(isAr
                            ? 'سيتم حذف العداد الكلي أيضاً. هل أنت متأكد؟'
                            : 'This will also clear the total count. Continue?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(isAr ? 'إلغاء' : 'Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(isAr ? 'إعادة ضبط' : 'Full Reset'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && mounted) _hardReset();
                  },
                  onToggleVibrate: () {
                    setState(() => _vibrate = !_vibrate);
                    _save();
                    if (_vibrate) _vibrateDevice(duration: 30, amplitude: 120);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isAr, bool isDark, _DhikrPreset preset) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: preset.color,
      title: Text(
        isAr ? 'السبحة الإلكترونية' : 'Digital Tasbeeh',
        style: TextStyle(
          color: preset.color,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          fontFamily: 'Amiri',
        ),
      ),
      centerTitle: true,
      iconTheme: IconThemeData(color: preset.color),
      // actions: [
      //   Padding(
      //     padding: const EdgeInsets.only(right: 8),
      //     child: GestureDetector(
      //       onTap: () {
      //         setState(() => _vibrate = !_vibrate);
      //         _save();
      //         if (_vibrate) _vibrateDevice(duration: 30, amplitude: 120);
      //       },
      //       child: AnimatedContainer(
      //         duration: const Duration(milliseconds: 250),
      //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      //         decoration: BoxDecoration(
      //           color: _vibrate
      //               ? preset.color.withValues(alpha: 0.12)
      //               : Colors.transparent,
      //           borderRadius: BorderRadius.circular(12),
      //           border: Border.all(
      //             color: preset.color.withValues(alpha: 0.3),
      //             width: 1,
      //           ),
      //         ),
      //         child: Icon(
      //           _vibrate ? Icons.vibration_rounded : Icons.phonelink_erase_rounded,
      //           color: preset.color,
      //           size: 20,
      //         ),
      //       ),
      //     ),
      //   ),
      // ],
    );
  }
}

// ─── Arabesque background painter ─────────────────────────────────────────────
// ─── Islamic 8-star tile background painter ──────────────────────────────────
// Draws classic two-overlapping-squares 8-pointed star pattern (Rub al-Hizb
// style) as a very subtle, eye-friendly background.
class _ArabesquePainter extends CustomPainter {
  final Color color;
  const _ArabesquePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round;

    // Primary star grid — large stars
    const step = 88.0;
    const bigR  = 20.0;
    const smallR = 11.0;

    for (double x = 0; x <= size.width + step; x += step) {
      for (double y = 0; y <= size.height + step; y += step) {
        _draw8PointedStar(canvas, Offset(x, y), bigR, paint);
      }
    }
    // Half-offset grid — smaller accent stars between primaries
    for (double x = step / 2; x <= size.width + step; x += step) {
      for (double y = step / 2; y <= size.height + step; y += step) {
        _draw8PointedStar(canvas, Offset(x, y), smallR, paint);
      }
    }
    // Thin connecting lines linking adjacent primary stars horizontally
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 0.6;
    for (double x = bigR; x <= size.width; x += step) {
      for (double y = 0; y <= size.height + step; y += step) {
        canvas.drawLine(Offset(x, y), Offset(x + step - bigR * 2, y), linePaint);
        canvas.drawLine(Offset(x - bigR, y - bigR),
            Offset(x - bigR + step / 2 - smallR, y - bigR + step / 2 - smallR),
            linePaint);
      }
    }
  }

  /// Draws a true 8-pointed star (two overlapping squares) at center [c] with
  /// outer tip radius [r]. Inner radius = r × 0.42 for pleasing proportions.
  void _draw8PointedStar(Canvas canvas, Offset c, double r, Paint p) {
    final ir = r * 0.42; // inner notch radius
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final angle = i * math.pi / 8 - math.pi / 2;
      final rad   = i.isEven ? r : ir;
      final px = c.dx + rad * math.cos(angle);
      final py = c.dy + rad * math.sin(angle);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ArabesquePainter old) => old.color != color;
}

// ─── Dhikr banner ─────────────────────────────────────────────────────────────
class _DhikrBanner extends StatelessWidget {
  final _DhikrPreset preset;
  final bool isAr;
  final bool isDark;

  const _DhikrBanner({
    required this.preset,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(preset.textAr),
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: preset.color.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: preset.color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Decorative top divider
            Row(
              children: [
                Expanded(child: _GoldDivider(color: preset.color)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '۞',
                    style: TextStyle(
                      color: preset.color.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(child: _GoldDivider(color: preset.color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? preset.textAr : preset.textEn,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: isAr ? 26 : 16,
                fontWeight: FontWeight.w700,
                color: preset.color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _GoldDivider(color: preset.color)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '۞',
                    style: TextStyle(
                      color: preset.color.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(child: _GoldDivider(color: preset.color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  final Color color;
  const _GoldDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─── Main Tasbeeh Button ──────────────────────────────────────────────────────
class _TasbeehButton extends StatelessWidget {
  final int count;
  final int target;
  final bool hasTarget;
  final double progress;
  final bool isDone;
  final _DhikrPreset preset;
  final bool isAr;
  final bool isDark;
  final Animation<double> glowAnim;

  const _TasbeehButton({
    super.key,
    required this.count,
    required this.target,
    required this.hasTarget,
    required this.progress,
    required this.isDone,
    required this.preset,
    required this.isAr,
    required this.isDark,
    required this.glowAnim,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final outerSize = (sw * 0.72).clamp(210.0, 290.0);
    final innerSize = outerSize - 32;
    final color = preset.color;

    return AnimatedBuilder(
      animation: glowAnim,
      builder: (context, child) {
        return SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Outer glow circle ─────────────────────────────────
              Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(
                          alpha: (isDone ? 0.35 : 0.22) * glowAnim.value),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              // ── Tasbeeh bead ring (always visible, 33 fixed beads) ──────
              SizedBox(
                width: outerSize,
                height: outerSize,
                child: CustomPaint(
                  painter: _BeadRingPainter(
                    progress: progress,
                    ringColor: isDone ? AppColors.secondary : color,
                    isDone: isDone,
                    isDark: isDark,
                  ),
                ),
              ),
              // ── Inner button ──────────────────────────────────────
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 1.1,
                    colors: isDone
                        ? [
                            Color.lerp(color, Colors.white, 0.3)!,
                            color,
                            Color.lerp(color, Colors.black, 0.2)!,
                          ]
                        : [
                            Color.lerp(color, Colors.white, 0.18)!,
                            color,
                            Color.lerp(color, Colors.black, 0.30)!,
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.18),
                      blurRadius: 14,
                      offset: const Offset(-4, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Count number
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Text(
                        _toAr(count, isAr),
                        key: ValueKey(count),
                        style: GoogleFonts.cairo(
                          fontSize: count > 9999 ? 38
                              : count > 999 ? 46
                              : count > 99 ? 54
                              : 64,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasTarget) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${isAr ? "من" : "of"} ${_toAr(target, isAr)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tasbeeh Bead Ring Painter ───────────────────────────────────────────────
// Always renders exactly 33 beads (symbolic tasbeeh count) with:
//  • A thin cord circle underneath
//  • 3D sphere effect via radial gradient + specular highlight
//  • A slightly larger "divider" bead at index 0 (12 o'clock)
//  • Filled beads: preset color (gold when done)
//  • Empty beads: faint outline circles
class _BeadRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final bool isDone;
  final bool isDark;

  const _BeadRingPainter({
    required this.progress,
    required this.ringColor,
    required this.isDone,
    required this.isDark,
  });

  static const _kBeads = 33;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ringR   = size.width / 2 - 8.0;
    final beadR   = (size.width / 34.0).clamp(7.0, 9.5);

    const gold      = AppColors.secondary;
    const lightGold = Color(0xFFF8DC6A);
    const darkGold  = Color(0xFF8B6600);

    final filledCount = isDone
        ? _kBeads
        : (progress * _kBeads).round().clamp(0, _kBeads);

    final cordColor = isDone
        ? gold.withValues(alpha: 0.45)
        : ringColor.withValues(alpha: 0.20);

    final anglePerBead = (math.pi * 2) / _kBeads;

    // 1 ─ Draw the cord (thin full-circle string)
    canvas.drawCircle(
      Offset(cx, cy),
      ringR,
      Paint()
        ..color = cordColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 2 ─ Draw each bead
    for (int i = 0; i < _kBeads; i++) {
      final angle  = -math.pi / 2 + i * anglePerBead;
      final bx     = cx + ringR * math.cos(angle);
      final by     = cy + ringR * math.sin(angle);
      final center = Offset(bx, by);
      // bead 0 is the divider head — slightly larger
      final r         = (i == 0) ? beadR * 1.38 : beadR;
      final isFilled  = i < filledCount;

      if (isFilled || isDone) {
        final bc    = isDone ? gold       : ringColor;
        final light = isDone ? lightGold  : Color.lerp(ringColor, Colors.white, 0.42)!;
        final dark  = isDone ? darkGold   : Color.lerp(ringColor, Colors.black, 0.42)!;

        // Soft drop shadow
        canvas.drawCircle(
          Offset(center.dx, center.dy + r * 0.28),
          r * 0.82,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );

        // Sphere body — radial gradient for 3D look
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.38, -0.38),
              radius: 0.98,
              colors: [light, bc, dark],
              stops: const [0.0, 0.48, 1.0],
            ).createShader(Rect.fromCircle(center: center, radius: r)),
        );

        // Specular highlight (soft oval, top-left)
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx - r * 0.26, center.dy - r * 0.26),
            width: r * 0.70,
            height: r * 0.50,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.60),
        );

        // Divider bead: white rim
        if (i == 0) {
          canvas.drawCircle(
            center, r,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.40)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
      } else {
        // Empty bead — subtle hollow ring
        canvas.drawCircle(
          center, r,
          Paint()
            ..color = ringColor.withValues(alpha: isDark ? 0.12 : 0.09)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center, r,
          Paint()
            ..color = ringColor.withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BeadRingPainter old) =>
      old.progress != progress ||
      old.isDone != isDone ||
      old.ringColor != ringColor ||
      old.isDark != isDark;
}



// ─── Status line ──────────────────────────────────────────────────────────────
class _StatusLine extends StatelessWidget {
  final int count;
  final int target;
  final bool hasTarget;
  final bool isDone;
  final _DhikrPreset preset;
  final bool isAr;
  final bool isDark;

  const _StatusLine({
    required this.count,
    required this.target,
    required this.hasTarget,
    required this.isDone,
    required this.preset,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌟', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isAr ? 'أتممت الذكر — جزاك الله خيراً' : 'Dhikr complete — JazakAllah Khayr',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B6914),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('🌟', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    if (count == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(
          isAr ? '— اضغط في أي مكان للتسبيح —' : '— Tap anywhere to count —',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? preset.color.withValues(alpha: 0.55)
                : preset.color.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    if (hasTarget && !isDone) {
      final remaining = target - count;
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(
          isAr
              ? 'باقي ${_toAr(remaining, isAr)} ذكر'
              : '$remaining remaining',
          style: TextStyle(
            fontSize: 13,
            color: preset.color.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const SizedBox(height: 14);
  }
}

// ─── Stats Card ───────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final int count;
  final int total;
  final int target;
  final bool hasTarget;
  final bool isAr;
  final bool isDark;
  final Color presetColor;

  const _StatsCard({
    required this.count,
    required this.total,
    required this.target,
    required this.hasTarget,
    required this.isAr,
    required this.isDark,
    required this.presetColor,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = hasTarget && target > 0 ? total ~/ target : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? presetColor.withValues(alpha: 0.10)
            : presetColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: presetColor.withValues(alpha: isDark ? 0.22 : 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            label: isAr ? 'الجلسة' : 'Session',
            value: _fmt(count, isAr),
            icon: '📿',
            color: presetColor,
          ),
          _StatDivider(color: presetColor),
          _Stat(
            label: isAr ? 'الإجمالي' : 'Total',
            value: _fmt(total, isAr),
            icon: '📊',
            color: presetColor,
          ),
          if (rounds > 0) ...[
            _StatDivider(color: presetColor),
            _Stat(
              label: isAr ? 'الدورات' : 'Rounds',
              value: _fmt(rounds, isAr),
              icon: '🔄',
              color: AppColors.secondary,
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int n, bool ar) {
    if (!ar) return _commas(n);
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return _commas(n).split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? d[i] : c;
    }).join();
  }

  String _commas(int n) {
    final s = '$n';
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: color.withValues(alpha: 0.2),
    );
  }
}

// ─── Bottom Actions ─────────────────────────────────────────────────────────
class _BottomActions extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final bool vibrate;
  final Color presetColor;
  final VoidCallback onReset;
  final VoidCallback onHardReset;
  final VoidCallback onToggleVibrate;

  const _BottomActions({
    super.key,
    required this.isAr,
    required this.isDark,
    required this.vibrate,
    required this.presetColor,
    required this.onReset,
    required this.onHardReset,
    required this.onToggleVibrate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Reset session
          Expanded(
            flex: 3,
            child: _ActionBtn(
              label: isAr ? 'إعادة العداد' : 'Reset',
              icon: Icons.refresh_rounded,
              color: presetColor,
              isDark: isDark,
              onTap: onReset,
            ),
          ),
          const SizedBox(width: 10),
          // Vibration toggle
          _IconBtn(
            icon: vibrate ? Icons.vibration_rounded : Icons.phonelink_erase_rounded,
            color: vibrate ? presetColor : Colors.grey,
            isDark: isDark,
            tooltip: isAr
                ? (vibrate ? 'إيقاف الاهتزاز' : 'تفعيل الاهتزاز')
                : (vibrate ? 'Disable vibration' : 'Enable vibration'),
            onTap: onToggleVibrate,
          ),
          const SizedBox(width: 10),
          // Hard reset
          _IconBtn(
            icon: Icons.delete_sweep_rounded,
            color: AppColors.error,
            isDark: isDark,
            tooltip: isAr ? 'إعادة ضبط كاملة' : 'Full Reset',
            onTap: onHardReset,
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
        ),
      ),
    );
  }
}

// ─── Preset Bar ───────────────────────────────────────────────────────────────
class _PresetBar extends StatelessWidget {
  final List<_DhikrPreset> presets;
  final int selectedIndex;
  final bool isAr;
  final bool isDark;
  final Color presetColor;
  final ValueChanged<int> onSelect;

  const _PresetBar({
    required this.presets,
    required this.selectedIndex,
    required this.isAr,
    required this.isDark,
    required this.presetColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          final p = presets[i];
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? p.color
                    : p.color.withValues(alpha: isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? p.color
                      : p.color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: p.color.withValues(alpha: 0.38),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Text(
                isAr ? p.textAr : p.textEn,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : p.color.withValues(alpha: 0.85),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                  fontFamily: isAr && i < presets.length - 1 ? 'Amiri' : null,
                ),
                maxLines: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}
