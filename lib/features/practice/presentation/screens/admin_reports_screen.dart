import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Admin-only screen listing all `question_reports` from Firestore.
///
/// Access: long-press XP badge in practice home → admin UID check.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  /// Returns true if the currently signed-in user is the admin.
  static Future<bool> isAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final rc = FirebaseRemoteConfig.instance;
    try {
      await rc.fetchAndActivate();
    } catch (_) {}
    final adminUid = rc.getString('admin_uid').trim();
    return adminUid.isNotEmpty && uid.trim() == adminUid;
  }

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  static const _reasonLabels = {
    'wrong_answer': 'الإجابة الصحيحة خاطئة',
    'unclear': 'السؤال غير واضح',
    'typo': 'خطأ إملائي أو نحوي',
    'duplicate': 'سؤال مكرر',
    'other': 'أخرى',
  };

  String _filter = 'all'; // 'all' | reason key

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير الأسئلة'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              ..._reasonLabels.entries.map(
                (e) => PopupMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('question_reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('خطأ: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)),
            );
          }

          final docs = snap.data?.docs ?? [];
          final filtered = _filter == 'all'
              ? docs
              : docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['reason'] == _filter;
                }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 64,
                      color: isDark ? Colors.white38 : Colors.black26),
                  const SizedBox(height: 16),
                  const Text('لا توجد تقارير',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = filtered[i].data() as Map<String, dynamic>;
              final questionText =
                  (data['questionText'] as String?)?.trim() ?? '—';
              final reason = data['reason'] as String? ?? '';
              final note = (data['note'] as String?)?.trim() ?? '';
              final ts = data['createdAt'] as Timestamp?;
              final date = ts != null
                  ? _formatDate(ts.toDate())
                  : '—';

              return _ReportCard(
                questionText: questionText,
                reason: _reasonLabels[reason] ?? reason,
                note: note,
                date: date,
                isDark: isDark,
                onDelete: () => _deleteReport(filtered[i].id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteReport(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقرير؟'),
        content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('question_reports')
        .doc(docId)
        .delete();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _ReportCard extends StatelessWidget {
  final String questionText;
  final String reason;
  final String note;
  final String date;
  final bool isDark;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.questionText,
    required this.reason,
    required this.note,
    required this.date,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            questionText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Amiri',
              height: 1.6,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          // Reason chip + date row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          // Optional note
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.error),
              label: const Text('حذف',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.error)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
        ],
      ),
    );
  }
}
