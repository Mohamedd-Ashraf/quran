import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/number_style_utils.dart';
import '../../data/models/leaderboard_entry.dart';
import '../cubit/leaderboard_cubit.dart';
import '../cubit/leaderboard_state.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = di.sl<LeaderboardCubit>();
    _cubit.load();
  }

  Future<void> _onLeaderboardAvatarLongPress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final remoteConfig = di.sl<FirebaseRemoteConfig>();
    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // Keep last activated value when fetch fails.
    }

    final adminUid = remoteConfig.getString('admin_uid').trim();
    if (!mounted || adminUid.isEmpty || user.uid.trim() != adminUid) return;

    _showAdminPanel();
  }

  void _showAdminPanel() {
    final isArabic = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAdminSheet(isArabic),
    );
  }

  Widget _buildAdminSheet(bool isArabic) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isArabic ? 'لوحة الأدمن' : 'Admin Panel',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'أنت الأدمن - يمكنك إدارة لوحة المتصدرين'
                : 'You are the admin - manage the leaderboard',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Text(
                isArabic
                    ? 'ميزات الأدمن قريباً...'
                    : 'Admin features coming soon...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String _localizeInt(int value, {required bool isArabic}) {
    return localizeNumber(value, isArabic: isArabic);
  }

  Widget _digitAwareText({
    required String text,
    required TextStyle style,
    required bool isArabic,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
  }) {
    if (!isArabic) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return buildRichTextWithAmiriDigits(
      text: text,
      baseStyle: style,
      amiriStyle: amiriDigitTextStyle(
        style,
        fontWeight: style.fontWeight ?? FontWeight.w700,
        height: style.height,
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'لوحة المتصدرين' : 'Leaderboard'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Builder(builder: (context) {
                final user = FirebaseAuth.instance.currentUser;
                return GestureDetector(
                  onLongPress: _onLeaderboardAvatarLongPress,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
        body: BlocBuilder<LeaderboardCubit, LeaderboardState>(
          builder: (context, state) {
            if (state is LeaderboardInitial || state is LeaderboardLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is LeaderboardError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      isArabic
                          ? 'تعذر تحميل لوحة المتصدرين'
                          : 'Failed to load leaderboard',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _cubit.load(),
                      child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              );
            }
            if (state is LeaderboardLoaded) {
              return _buildLeaderboard(
                context, state,
                isArabic: isArabic, isDark: isDark,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLeaderboard(
    BuildContext context,
    LeaderboardLoaded state, {
    required bool isArabic,
    required bool isDark,
  }) {
    final entries = state.entries;
    final top3 = entries.length >= 3 ? entries.sublist(0, 3) : entries;
    final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _cubit.load(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // ── Podium ──
              if (top3.isNotEmpty)
                _buildPodium(top3, isArabic: isArabic, isDark: isDark),

              // ── Ranking list header ──
              if (rest.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.format_list_numbered, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? 'ترتيب المتسابقين' : 'Rankings',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Ranking list ──
              ...List.generate(rest.length, (i) {
                final entry = rest[i];
                final rank = i + 4;
                final isCurrentUser =
                    state.currentUserEntry != null &&
                    entry.uid == state.currentUserEntry!.uid;
                return _buildRankCard(
                  entry, rank,
                  isCurrentUser: isCurrentUser,
                  isArabic: isArabic, isDark: isDark,
                );
              }),

              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        isArabic
                            ? 'لا يوجد متسابقون بعد\nكن أول من يشارك!'
                            : 'No participants yet\nBe the first to join!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Current user sticky bar ──
        if (state.currentUserEntry != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildCurrentUserBar(
              state.currentUserEntry!,
              state.currentUserRank,
              isArabic: isArabic,
              isDark: isDark,
            ),
          ),
      ],
    );
  }

  // ── Podium ──────────────────────────────────────────────────────────────

  Widget _buildPodium(
    List<LeaderboardEntry> top3, {
    required bool isArabic,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (top3.length > 1)
            Expanded(child: _podiumItem(top3[1], 2, isDark: isDark, isArabic: isArabic)),
          // 1st place
          Expanded(child: _podiumItem(top3[0], 1, isDark: isDark, isArabic: isArabic)),
          // 3rd place
          if (top3.length > 2)
            Expanded(child: _podiumItem(top3[2], 3, isDark: isDark, isArabic: isArabic)),
        ],
      ),
    );
  }

  Widget _podiumItem(
    LeaderboardEntry entry,
    int rank, {
    required bool isDark,
    required bool isArabic,
  }) {
    final isFirst = rank == 1;
    final borderColor = rank == 1
        ? AppColors.secondary
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);
    final avatarSize = isFirst ? 76.0 : 58.0;
    final podiumHeight = isFirst ? 140.0 : rank == 2 ? 96.0 : 72.0;

    final podiumColor = isFirst
        ? AppColors.primary
        : rank == 2
            ? (isDark ? AppColors.darkCard : const Color(0xFFE7E8E9))
            : (isDark
                ? AppColors.darkCard.withValues(alpha: 0.7)
                : const Color(0xFFF3F4F5));

    final textColor = isFirst ? Colors.white : null;
    final scoreColor = isFirst ? AppColors.secondary : AppColors.primary;

    // Arch shape for 1st place, rounded for others
    final borderRadius = isFirst
        ? const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          )
        : const BorderRadius.vertical(top: Radius.circular(16));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 3),
                boxShadow: isFirst
                    ? [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: entry.photoUrl != null
                    ? Image.network(
                        entry.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _defaultAvatar(entry),
                      )
                    : _defaultAvatar(entry),
              ),
            ),
            if (isFirst)
              Positioned(
                top: -14,
                child: Icon(
                  Icons.workspace_premium,
                  color: AppColors.secondary,
                  size: 30,
                ),
              ),
            Positioned(
              bottom: -4,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _digitAwareText(
                  text: _localizeInt(rank, isArabic: isArabic),
                  style: TextStyle(
                    color: rank == 1 ? AppColors.textPrimary : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                  isArabic: isArabic,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Podium column
        Container(
          width: double.infinity,
          height: podiumHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: borderRadius,
            boxShadow: isFirst
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isFirst ? 13 : 10,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                _digitAwareText(
                  text: _localizeInt(entry.totalScore, isArabic: isArabic),
                  style: TextStyle(
                    fontSize: isFirst ? 18 : 13,
                    fontWeight: FontWeight.w900,
                    color: isFirst ? Colors.white : scoreColor,
                  ),
                  isArabic: isArabic,
                  textAlign: TextAlign.center,
                ),
                if (entry.streak > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 11),
                      _digitAwareText(
                        text: ' ${_localizeInt(entry.streak, isArabic: isArabic)}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isFirst
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                        isArabic: isArabic,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Rank card ───────────────────────────────────────────────────────────

  Widget _buildRankCard(
    LeaderboardEntry entry,
    int rank, {
    required bool isCurrentUser,
    required bool isArabic,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.08)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 32,
            child: _digitAwareText(
              text: _localizeInt(rank, isArabic: isArabic),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              isArabic: isArabic,
            ),
          ),
          // Avatar
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsetsDirectional.only(end: 12),
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.hardEdge,
            child: entry.photoUrl != null
                ? Image.network(
                    entry.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _defaultAvatar(entry),
                  )
                : _defaultAvatar(entry),
          ),
          // Name + streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (entry.streak > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 14),
                      const SizedBox(width: 3),
                      _digitAwareText(
                        text: '${_localizeInt(entry.streak, isArabic: isArabic)} ${isArabic ? "يوم متواصل" : "day streak"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        isArabic: isArabic,
                        textDirection: isArabic
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _digitAwareText(
                text: _localizeInt(entry.totalScore, isArabic: isArabic),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
                isArabic: isArabic,
                textAlign: TextAlign.end,
              ),
              Text(
                isArabic ? 'نقطة' : 'pts',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Current user sticky bar ─────────────────────────────────────────────

  Widget _buildCurrentUserBar(
    LeaderboardEntry entry,
    int? rank, {
    required bool isArabic,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border(
          left: BorderSide(color: AppColors.secondary, width: 4),
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 44,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _digitAwareText(
                  text: rank != null
                      ? _localizeInt(rank, isArabic: isArabic)
                      : '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                  isArabic: isArabic,
                ),
                Text(
                  isArabic ? 'مرتبتك' : 'Rank',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          // Avatar
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsetsDirectional.only(end: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            clipBehavior: Clip.hardEdge,
            child: entry.photoUrl != null
                ? Image.network(
                    entry.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _defaultAvatar(entry, light: true),
                  )
                : _defaultAvatar(entry, light: true),
          ),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArabic ? 'أنت (${entry.displayName})' : 'You (${entry.displayName})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        color: AppColors.secondary, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      isArabic ? 'استمر! أنت في تقدم مستمر' : 'Keep going!',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _digitAwareText(
                text: _localizeInt(entry.totalScore, isArabic: isArabic),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppColors.secondary,
                ),
                isArabic: isArabic,
                textAlign: TextAlign.end,
              ),
              Text(
                isArabic ? 'نقطة' : 'pts',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Default avatar ──────────────────────────────────────────────────────

  Widget _defaultAvatar(LeaderboardEntry entry, {bool light = false}) {
    return Container(
      color: light ? Colors.white24 : AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          entry.displayName.isNotEmpty ? entry.displayName[0] : '?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: light ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
