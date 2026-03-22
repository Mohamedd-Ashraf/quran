import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';

/// صفحة تجريبية — طريقة صور الصفحات الكاملة من المصحف
/// كل صفحة تُعرض كصورة من CDN، والآيات قابلة للتفاعل من القائمة أسفل الصفحة
class MushafImageDemoScreen extends StatefulWidget {
  const MushafImageDemoScreen({super.key});

  @override
  State<MushafImageDemoScreen> createState() => _MushafImageDemoScreenState();
}

class _MushafImageDemoScreenState extends State<MushafImageDemoScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 1;

  /// Cache: page number → list of verse maps
  final Map<int, List<Map<String, dynamic>>> _pageAyahsCache = {};
  bool _loadingAyahs = false;
  String? _ayahError;

  @override
  void initState() {
    super.initState();
    _fetchAyahsForPage(1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// رابط صورة الصفحة من islamic.network CDN
  String _pageImageUrl(int pageNumber) {
    final padded = pageNumber.toString().padLeft(3, '0');
    return 'https://cdn.islamic.network/quran/images/page/page$padded.png';
  }

  /// جلب قائمة الآيات لصفحة معينة من Quran.com API v4
  Future<void> _fetchAyahsForPage(int page) async {
    if (_pageAyahsCache.containsKey(page)) return;
    setState(() {
      _loadingAyahs = true;
      _ayahError = null;
    });

    try {
      final url = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$page'
        '?fields=text_uthmani,verse_number&per_page=50',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final verses = (data['verses'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        if (mounted) {
          setState(() {
            _pageAyahsCache[page] = verses;
            _loadingAyahs = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingAyahs = false;
            _ayahError = 'خطأ في جلب الآيات (${response.statusCode})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingAyahs = false;
          _ayahError = 'تحقق من الاتصال بالإنترنت';
        });
      }
    }
  }

  void _showAyahBottomSheet(Map<String, dynamic> ayah) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AyahActionSheet(ayah: ayah),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ayahsForPage = _pageAyahsCache[_currentPage] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('المصحف — صورة الصفحة'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$_currentPage / 604',
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header وصف الطريقة ──────────────────────────────────
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined,
                    color: AppColors.secondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'الطريقة الأولى: صورة الصفحة من CDN',
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── صورة الصفحة ─────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 604,
              onPageChanged: (index) {
                final page = index + 1;
                setState(() => _currentPage = page);
                _fetchAyahsForPage(page);
              },
              itemBuilder: (ctx, index) {
                final page = index + 1;
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Image.network(
                    _pageImageUrl(page),
                    fit: BoxFit.contain,
                    headers: const {
                      'User-Agent': 'Mozilla/5.0 QuranApp/1.0',
                      'Accept': 'image/png,image/*',
                    },
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      final percent = progress.expectedTotalBytes != null
                          ? (progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes! *
                                  100)
                              .toInt()
                          : null;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                value: percent != null ? percent / 100 : null,
                                color: AppColors.secondary,
                                strokeWidth: 3,
                              ),
                            ),
                            if (percent != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off,
                              color: Colors.white38, size: 52),
                          const SizedBox(height: 14),
                          const Text(
                            'تعذّر تحميل صورة الصفحة',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'cdn.islamic.network',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 11),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh,
                                color: AppColors.secondary),
                            label: const Text('إعادة المحاولة',
                                style:
                                    TextStyle(color: AppColors.secondary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.secondary),
                            ),
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── شريط الآيات التفاعلي ────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  child: Text(
                    '← اضغط على رقم أي آية للتفاعل',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: AppColors.onPrimary.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: _loadingAyahs
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary,
                            ),
                          ),
                        )
                      : _ayahError != null
                          ? Center(
                              child: Text(
                                _ayahError!,
                                style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              reverse: true, // RTL
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: ayahsForPage.length,
                              itemBuilder: (ctx, i) {
                                final ayah = ayahsForPage[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 6),
                                  child: InkWell(
                                    onTap: () =>
                                        _showAyahBottomSheet(ayah),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.18),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.secondary
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Text(
                                        ayah['verse_key'] ?? '',
                                        style: const TextStyle(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── أزرار التنقل بين الصفحات ────────────────────────────
          Container(
            color: const Color(0xFF0A3D26),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر الصفحة التالية (الأيمن للغة العربية = صفحة سابقة رقماً)
                _NavButton(
                  icon: Icons.navigate_next,
                  tooltip: 'الصفحة التالية ←',
                  enabled: _currentPage < 604,
                  onTap: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                  ),
                ),
                // رقم الصفحة مع Go to page
                GestureDetector(
                  onTap: _showGoToPageDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'صفحة $_currentPage',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                // زر الصفحة السابقة
                _NavButton(
                  icon: Icons.navigate_before,
                  tooltip: '→ الصفحة السابقة',
                  enabled: _currentPage > 1,
                  onTap: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGoToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('انتقل لصفحة', textDirection: TextDirection.rtl),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: '1 → 604',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 1 && n <= 604) {
                Navigator.pop(ctx);
                _pageController.animateToPage(
                  n - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: const Text('انتقل',
                style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet التفاعل مع الآية
// ─────────────────────────────────────────────────────────────────────────────

class _AyahActionSheet extends StatefulWidget {
  final Map<String, dynamic> ayah;
  const _AyahActionSheet({required this.ayah});

  @override
  State<_AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends State<_AyahActionSheet> {
  String? _tafsirText;
  bool _loadingTafsir = false;

  String get _verseKey => widget.ayah['verse_key'] ?? '';
  String get _textUthmani => widget.ayah['text_uthmani'] ?? '';

  Future<void> _loadTafsir() async {
    setState(() => _loadingTafsir = true);
    try {
      // نستخدم alquran.cloud التفسير الميسر
      final parts = _verseKey.split(':');
      final surah = parts[0];
      final ayah = parts.length > 1 ? parts[1] : '1';
      final url = Uri.parse(
          'https://api.alquran.cloud/v1/ayah/$surah:$ayah/ar.muyassar');
      final r = await http.get(url).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final text = d['data']?['text'] as String?;
        if (mounted) setState(() => _tafsirText = text);
      }
    } catch (_) {
      if (mounted) setState(() => _tafsirText = 'تعذّر جلب التفسير');
    } finally {
      if (mounted) setState(() => _loadingTafsir = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // رقم الآية
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _verseKey,
                    style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                const Text('آية المصحف',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),

            // نص الآية بالرسم العثماني
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
              ),
              child: Text(
                _textUthmani,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 28,
                  height: 2.0,
                  color: AppColors.arabicText,
                  fontFamily: 'Scheherazade New',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.headphones_rounded,
                    label: 'استماع',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔊 قريباً: تشغيل الآية صوتياً'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.menu_book_outlined,
                    label: 'التفسير',
                    color: AppColors.accent,
                    onTap: _tafsirText != null ? null : _loadTafsir,
                  ),
                ),
              ],
            ),

            // عرض التفسير
            if (_loadingTafsir) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ],
            if (_tafsirText != null && !_loadingTafsir) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'التفسير الميسر',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tafsirText!,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets مساعدة
// ─────────────────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon,
            color: enabled
                ? AppColors.onPrimary
                : AppColors.onPrimary.withValues(alpha: 0.3)),
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: onTap != null ? color : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: onTap != null ? color : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}