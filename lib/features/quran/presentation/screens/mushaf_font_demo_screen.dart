import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';

/// صفحة تجريبية — طريقة النص العثماني كلمة بكلمة (QPC Hafs style)
/// البيانات من Quran.com API — كل آية قابلة للضغط والتفاعل
/// يتشابه هذا النهج مع تطبيق Ayat في عرض الكلمات سطراً بسطر
class MushafFontDemoScreen extends StatefulWidget {
  const MushafFontDemoScreen({super.key});

  @override
  State<MushafFontDemoScreen> createState() => _MushafFontDemoScreenState();
}

class _MushafFontDemoScreenState extends State<MushafFontDemoScreen> {
  int _currentPage = 1;
  final PageController _pageController = PageController();

  /// Cache: page number → list of verse data maps
  final Map<int, List<_VerseData>> _cache = {};
  bool _loading = false;
  String? _error;

  /// رقم الآية المحددة حالياً (للـ highlight)
  String? _selectedVerseKey;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page) async {
    if (_cache.containsKey(page)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // نجلب الآيات بكلماتها ورقم السطر لكل كلمة
      final url = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$page'
        '?words=true&word_fields=text_uthmani,line_number,code_v1'
        '&fields=text_uthmani,verse_number&per_page=50',
      );
      final r = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final rawVerses =
            (data['verses'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final verses = rawVerses.map((v) {
          final words = (v['words'] as List?)
                  ?.cast<Map<String, dynamic>>()
                  .where((w) => w['char_type_name'] == 'word')
                  .map((w) => _WordData(
                        text: w['text_uthmani'] as String? ?? '',
                        codeV1: w['code_v1'] as String? ?? '',
                        lineNumber: (w['line_number'] as num?)?.toInt() ?? 0,
                      ))
                  .toList() ??
              [];

          return _VerseData(
            verseKey: v['verse_key'] as String? ?? '',
            verseNumber: (v['verse_number'] as num?)?.toInt() ?? 0,
            textUthmani: v['text_uthmani'] as String? ?? '',
            words: words,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _cache[page] = verses;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'خطأ في جلب البيانات (${r.statusCode})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تحقق من الاتصال بالإنترنت';
        });
      }
    }
  }

  void _showVerseBottomSheet(_VerseData verse) {
    setState(() => _selectedVerseKey = verse.verseKey);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseDetailSheet(verse: verse),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedVerseKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E4),
      appBar: AppBar(
        title: const Text('المصحف — نص عثماني تفاعلي'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.4)),
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
            color: AppColors.primary.withValues(alpha: 0.9),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.text_fields_outlined,
                    color: AppColors.secondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'الطريقة الثانية: نص عثماني تفاعلي — اضغط على أي آية',
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── محتوى الصفحة ────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 604,
              onPageChanged: (index) {
                final page = index + 1;
                setState(() {
                  _currentPage = page;
                  _selectedVerseKey = null;
                });
                _loadPage(page);
              },
              itemBuilder: (ctx, index) {
                final page = index + 1;
                return _PageContent(
                  page: page,
                  verses: _cache[page],
                  loading: _loading && page == _currentPage,
                  error: _error,
                  selectedVerseKey: _selectedVerseKey,
                  onVerseTap: _showVerseBottomSheet,
                );
              },
            ),
          ),

          // ── شريط التنقل ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // التالي (الأيمن في RTL)
                IconButton(
                  icon: Icon(
                    Icons.navigate_next,
                    color: _currentPage < 604
                        ? AppColors.onPrimary
                        : AppColors.onPrimary.withValues(alpha: 0.3),
                  ),
                  tooltip: 'الصفحة التالية',
                  onPressed: _currentPage < 604
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                // الانتقال السريع
                GestureDetector(
                  onTap: _showGoToPageDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 7),
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
                // السابق
                IconButton(
                  icon: Icon(
                    Icons.navigate_before,
                    color: _currentPage > 1
                        ? AppColors.onPrimary
                        : AppColors.onPrimary.withValues(alpha: 0.3),
                  ),
                  tooltip: 'الصفحة السابقة',
                  onPressed: _currentPage > 1
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
// محتوى الصفحة — عرض الآيات
// ─────────────────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final int page;
  final List<_VerseData>? verses;
  final bool loading;
  final String? error;
  final String? selectedVerseKey;
  final void Function(_VerseData) onVerseTap;

  const _PageContent({
    required this.page,
    required this.verses,
    required this.loading,
    required this.error,
    required this.selectedVerseKey,
    required this.onVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text(
              'جاري تحميل الصفحة...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (error != null && verses == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.grey, size: 48),
            const SizedBox(height: 14),
            Text(
              error!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (verses == null || verses!.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Container(
      color: const Color(0xFFF5F0E4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ── إطار المصحف ────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFEFBF4),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Header الصفحة ────────────────────────────────
                  _PageHeader(pageNumber: page),

                  // ── الآيات ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Column(
                      children: verses!.asMap().entries.map((entry) {
                        final verse = entry.value;
                        final isSelected =
                            verse.verseKey == selectedVerseKey;
                        return _VerseBlock(
                          verse: verse,
                          isSelected: isSelected,
                          onTap: () => onVerseTap(verse),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── Footer الصفحة ────────────────────────────────
                  _PageFooter(pageNumber: page),
                ],
              ),
            ),

            // ── تلميح ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.6)),
                  const SizedBox(width: 5),
                  Text(
                    'اضغط على أي آية لسماعها وقراءة تفسيرها',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// كتلة عرض الآية (تفاعلية)
// ─────────────────────────────────────────────────────────────────────────────

class _VerseBlock extends StatelessWidget {
  final _VerseData verse;
  final bool isSelected;
  final VoidCallback onTap;

  const _VerseBlock({
    required this.verse,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  width: 1,
                )
              : null,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 0,
            runSpacing: 4,
            children: [
              // الكلمات
              for (final word in verse.words)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    word.text,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 2.0,
                      color: AppColors.arabicText,
                      // هنا يمكن وضع فونت QPC Hafs لو أضفته للمشروع
                    ),
                  ),
                ),
              // رقم الآية (دائرة)
              _AyahNumber(number: verse.verseNumber),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// رقم الآية بشكل دائرة تراثية
// ─────────────────────────────────────────────────────────────────────────────

class _AyahNumber extends StatelessWidget {
  final int number;
  const _AyahNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _toArabicNumerals(number),
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _toArabicNumerals(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n
        .toString()
        .split('')
        .map((c) => int.tryParse(c) != null ? digits[int.parse(c)] : c)
        .join();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header و Footer الصفحة بتصميم المصحف
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int pageNumber;
  const _PageHeader({required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.secondary.withValues(alpha: 0.4),
              width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'صفحة $pageNumber',
            style: TextStyle(
              fontSize: 11,
              color:
                  AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          const Text(
            '﷽',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.arabicText,
            ),
          ),
          const Spacer(),
          const Text(
            'القرآن الكريم',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFooter extends StatelessWidget {
  final int pageNumber;
  const _PageFooter({required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: AppColors.secondary.withValues(alpha: 0.4),
              width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // زخرفة
          Container(
            width: 40,
            height: 1,
            color: AppColors.secondary.withValues(alpha: 0.4),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${pageNumber}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 1,
            color: AppColors.secondary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet تفاصيل الآية مع التفسير
// ─────────────────────────────────────────────────────────────────────────────

class _VerseDetailSheet extends StatefulWidget {
  final _VerseData verse;
  const _VerseDetailSheet({required this.verse});

  @override
  State<_VerseDetailSheet> createState() => _VerseDetailSheetState();
}

class _VerseDetailSheetState extends State<_VerseDetailSheet> {
  String? _tafsirText;
  bool _loadingTafsir = false;
  bool _showTafsir = false;

  Future<void> _loadTafsir() async {
    if (_loadingTafsir) return;
    setState(() {
      _loadingTafsir = true;
      _showTafsir = true;
    });

    try {
      final parts = widget.verse.verseKey.split(':');
      final surah = parts[0];
      final ayah = parts.length > 1 ? parts[1] : '1';
      final url = Uri.parse(
          'https://api.alquran.cloud/v1/ayah/$surah:$ayah/ar.muyassar');
      final r =
          await http.get(url).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        final text = d['data']?['text'] as String?;
        if (mounted) setState(() => _tafsirText = text ?? '—');
      } else {
        if (mounted) setState(() => _tafsirText = 'تعذّر جلب التفسير');
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

            // رقم الآية + مفتاحها
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.gradientStart,
                        AppColors.gradientEnd
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.verse.verseKey,
                    style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.auto_awesome,
                    color: AppColors.secondary, size: 16),
                const SizedBox(width: 4),
                const Text('آية مختارة',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),

            // نص الآية الكامل
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.35)),
              ),
              child: Text(
                widget.verse.textUthmani,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 26,
                  height: 2.0,
                  color: AppColors.arabicText,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: _SheetBtn(
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
                  child: _SheetBtn(
                    icon: Icons.menu_book_outlined,
                    label: _showTafsir ? 'التفسير ↓' : 'التفسير',
                    color: AppColors.accent,
                    onTap: _showTafsir ? null : _loadTafsir,
                  ),
                ),
              ],
            ),

            // عرض التفسير
            if (_showTafsir) ...[
              const SizedBox(height: 16),
              if (_loadingTafsir)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
              else
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
                        _tafsirText ?? '...',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.85,
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

class _SheetBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SheetBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Material(
      color: color.withValues(alpha: active ? 0.1 : 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: active ? color : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : Colors.grey,
                  fontWeight: FontWeight.bold,
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

// ─────────────────────────────────────────────────────────────────────────────
// نماذج البيانات
// ─────────────────────────────────────────────────────────────────────────────

class _WordData {
  final String text;
  final String codeV1;
  final int lineNumber;

  const _WordData({
    required this.text,
    required this.codeV1,
    required this.lineNumber,
  });
}

class _VerseData {
  final String verseKey;
  final int verseNumber;
  final String textUthmani;
  final List<_WordData> words;

  const _VerseData({
    required this.verseKey,
    required this.verseNumber,
    required this.textUthmani,
    required this.words,
  });
}