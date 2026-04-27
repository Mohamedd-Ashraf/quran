import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// A bottom sheet for reporting a problematic question.
///
/// Works for both practice questions (pass a Firestore [questionId]) and
/// daily quiz questions (pass a numeric [questionIndex] as the id string,
/// e.g. `'daily_$index'`).
///
/// On submit the report is written to the `question_reports` Firestore
/// collection. The sheet closes after a successful write.
class ReportQuestionSheet extends StatefulWidget {
  /// Unique identifier for the question being reported.
  /// For practice questions: the Firestore document ID.
  /// For daily quiz questions: `'daily_$index'`.
  final String questionId;

  /// Short snippet of the question text (shown in the sheet for context).
  final String questionSnippet;

  /// Full question text — saved verbatim in the report doc so admins can
  /// identify the question even after a reseed changes document IDs.
  final String questionText;

  const ReportQuestionSheet({
    super.key,
    required this.questionId,
    required this.questionSnippet,
    required this.questionText,
  });

  /// Convenience method — shows the sheet and returns when dismissed.
  static Future<void> show(
    BuildContext context, {
    required String questionId,
    required String questionSnippet,
    required String questionText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportQuestionSheet(
        questionId: questionId,
        questionSnippet: questionSnippet,
        questionText: questionText,
      ),
    );
  }

  @override
  State<ReportQuestionSheet> createState() => _ReportQuestionSheetState();
}

class _ReportQuestionSheetState extends State<ReportQuestionSheet> {
  static const _reasons = [
    ('wrong_answer', 'الإجابة الصحيحة خاطئة', 'Wrong correct answer'),
    ('unclear', 'السؤال غير واضح', 'Question is unclear'),
    ('typo', 'خطأ إملائي أو نحوي', 'Spelling / grammar error'),
    ('duplicate', 'سؤال مكرر', 'Duplicate question'),
    ('other', 'أخرى', 'Other'),
  ];

  String? _selectedReason;
  final _noteController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.7,
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _submitted ? _buildSuccess(isDark) : _buildForm(isDark),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'الإبلاغ عن مشكلة في السؤال',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Question snippet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard
                  : AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.questionSnippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontFamily: 'Amiri',
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reason chips
          Text(
            'سبب الإبلاغ:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _reasons.map((r) {
              final (key, labelAr, _) = r;
              final selected = _selectedReason == key;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.error.withValues(alpha: 0.12)
                        : (isDark ? AppColors.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppColors.error
                          : (isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.5)
                              : Colors.grey.withValues(alpha: 0.25)),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    labelAr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.error
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Optional note
          TextField(
            controller: _noteController,
            maxLines: 2,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'ملاحظات إضافية (اختياري)',
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 16),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedReason == null || _submitting
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: const StadiumBorder(),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إرسال البلاغ',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 56),
          const SizedBox(height: 16),
          Text(
            'شكراً لك!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'تم إرسال بلاغك بنجاح. سنراجع السؤال قريباً.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color:
                  isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('question_reports').add({
        'questionId': widget.questionId,
        'questionText': widget.questionText,
        'reason': _selectedReason,
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل إرسال البلاغ. تحقق من الاتصال بالإنترنت.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
