import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/widgets/islamic_logo.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Authentication screen shown after onboarding.
/// Provides Google Sign-In, Email/Password, and Guest options.
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthComplete;

  const AuthScreen({super.key, required this.onAuthComplete});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _showEmailForm = false;
  bool _isSignUp = true;
  bool _obscurePassword = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final screenHeight = MediaQuery.of(context).size.height;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated ||
            state.status == AuthStatus.guest) {
          widget.onAuthComplete();
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          context.read<AuthCubit>().clearError();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.background,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight,
              ),
              child: Column(
                children: [
                  // ── Islamic Header ──────────────────────────────
                  _IslamicHeader(isDark: isDark, isArabic: isArabic),

                  // ── Auth Content ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // ── Google Sign-In ───────────────────────
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            return _GoogleSignInButton(
                              isArabic: isArabic,
                              isDark: isDark,
                              isLoading:
                                  state.isLoading && !_showEmailForm,
                              onPressed: state.isLoading
                                  ? null
                                  : () => context
                                      .read<AuthCubit>()
                                      .signInWithGoogle(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Divider ──────────────────────────────
                        _OrDivider(isArabic: isArabic, isDark: isDark),
                        const SizedBox(height: 16),

                        // ── Email/Password ───────────────────────
                        if (!_showEmailForm)
                          Column(
                            children: [
                              _EmailToggleButton(
                                isArabic: isArabic,
                                isDark: isDark,
                                label: isArabic
                                    ? 'التسجيل بالبريد الإلكتروني'
                                    : 'Sign Up with Email',
                                onPressed: () => setState(() {
                                  _showEmailForm = true;
                                  _isSignUp = true;
                                }),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => setState(() {
                                  _showEmailForm = true;
                                  _isSignUp = false;
                                }),
                                child: Text(
                                  isArabic
                                      ? 'لديك حساب بالفعل؟ سجّل دخولك'
                                      : 'Already have an account? Sign In',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          _buildEmailForm(context, isArabic, isDark),

                        const SizedBox(height: 28),

                        // ── Guest Button ─────────────────────────
                        _GuestButton(
                          isArabic: isArabic,
                          isDark: isDark,
                          onPressed: () =>
                              _showGuestWarning(context, isArabic, isDark),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Email Form ──────────────────────────────────────────────────────────

  Widget _buildEmailForm(BuildContext context, bool isArabic, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isArabic ? 'الاسم' : 'Full Name',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.primary.withValues(alpha: 0.7),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkCard
                    : AppColors.primary.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isArabic ? 'أدخل اسمك' : 'Enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.primary.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkCard
                  : AppColors.primary.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic
                    ? 'أدخل البريد الإلكتروني'
                    : 'Enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                return isArabic
                    ? 'البريد الإلكتروني غير صالح'
                    : 'Invalid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة المرور' : 'Password',
              prefixIcon: Icon(
                Icons.lock_outline,
                color: isDark ? AppColors.darkTextSecondary : AppColors.primary.withValues(alpha: 0.7),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textHint,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkCard
                  : AppColors.primary.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isArabic ? 'أدخل كلمة المرور' : 'Enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return isArabic
                    ? 'كلمة المرور يجب أن تكون ٦ أحرف على الأقل'
                    : 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          if (!_isSignUp)
            Align(
              alignment:
                  isArabic ? Alignment.centerLeft : Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  isArabic ? 'نسيت كلمة المرور؟' : 'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _handleEmailSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isSignUp
                              ? (isArabic ? 'إنشاء حساب' : 'Sign Up')
                              : (isArabic ? 'تسجيل الدخول' : 'Sign In'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () => setState(() {
              _isSignUp = !_isSignUp;
              _nameController.clear();
            }),
            child: Text(
              _isSignUp
                  ? (isArabic
                      ? 'لديك حساب بالفعل؟ سجّل دخولك'
                      : 'Already have an account? Sign In')
                  : (isArabic
                      ? 'ليس لديك حساب؟ أنشئ حساباً جديداً'
                      : "Don't have an account? Sign Up"),
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEmailSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final cubit = context.read<AuthCubit>();
    if (_isSignUp) {
      cubit.signUpWithEmail(email, password, _nameController.text.trim());
    } else {
      cubit.signInWithEmail(email, password);
    }
  }

  void _handleForgotPassword() {
    final email = _emailController.text.trim();
    final isArabic = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'أدخل بريدك الإلكتروني أولاً'
                : 'Enter your email first',
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    context.read<AuthCubit>().sendPasswordReset(email);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم إرسال رابط إعادة تعيين كلمة المرور'
              : 'Password reset email sent',
          textAlign: TextAlign.center,
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showGuestWarning(BuildContext context, bool isArabic, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning.withValues(alpha: 0.85),
            size: 32,
          ),
        ),
        title: Text(
          isArabic ? 'الاستمرار كزائر' : 'Continue as Guest',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Text(
          isArabic
              ? 'في وضع الزائر لن يتم حفظ بياناتك في السحابة.\n\n'
                  'إذا قمت بحذف التطبيق أو تغيير الجهاز ستفقد جميع بياناتك '
                  '(الإشارات المرجعية، الورد، الإعدادات).\n\n'
                  'يمكنك ربط حسابك لاحقاً من الإعدادات.'
              : 'In guest mode, your data will NOT be saved to the cloud.\n\n'
                  'If you uninstall the app or switch devices, you will lose all your data '
                  '(bookmarks, wird, settings).\n\n'
                  'You can link your account later from Settings.',
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            height: 1.6,
            fontSize: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.cardBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<AuthCubit>().continueAsGuest();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child:
                      Text(isArabic ? 'استمرار كزائر' : 'Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Islamic Header ──────────────────────────────────────────────────────────

class _IslamicHeader extends StatelessWidget {
  final bool isDark;
  final bool isArabic;

  const _IslamicHeader({required this.isDark, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF0A3D26),
                  const Color(0xFF0D4F30),
                  AppColors.darkBackground,
                ]
              : [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryLight.withValues(alpha: 0.8),
                ],
          stops: isDark
              ? const [0.0, 0.6, 1.0]
              : const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              // ── Decorative top accent ──────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiriQuran(
                    fontSize: 20,
                    color: Colors.white,
                    height: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Logo ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const IslamicLogo(size: 100, darkTheme: true),
              ),
              const SizedBox(height: 20),

              // ── Welcome text ───────────────────────────────
              Text(
                isArabic ? 'أهلاً وسهلاً' : 'Welcome',
                style: TextStyle(
                  fontFamily: isArabic ? 'Amiri' : null,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: isArabic ? 0 : 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'سجّل دخولك لحفظ بياناتك ومزامنتها عبر أجهزتك'
                    : 'Sign in to save and sync your data across devices',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google Sign-In Button ────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({
    required this.isArabic,
    required this.isDark,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          foregroundColor:
              isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.cardBorder,
              width: 1,
            ),
          ),
          elevation: isDark ? 0 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" colored logo using text
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4285F4),
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isArabic
                        ? 'تسجيل الدخول بحساب جوجل'
                        : 'Continue with Google',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── "Or" Divider ─────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  final bool isArabic;
  final bool isDark;

  const _OrDivider({required this.isArabic, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.darkDivider : AppColors.divider;
    return Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 0.8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            isArabic ? 'أو' : 'or',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textHint,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 0.8)),
      ],
    );
  }
}

// ── Email Toggle Button ──────────────────────────────────────────────────────

class _EmailToggleButton extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final String label;
  final VoidCallback onPressed;

  const _EmailToggleButton({
    required this.isArabic,
    required this.isDark,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? AppColors.darkTextPrimary : AppColors.primary,
          side: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.primary.withValues(alpha: 0.4),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.email_outlined,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guest Button ─────────────────────────────────────────────────────────────

class _GuestButton extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final VoidCallback onPressed;

  const _GuestButton({
    required this.isArabic,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.person_outline_rounded,
        size: 18,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
      ),
      label: Text(
        isArabic ? 'الاستمرار كزائر بدون حساب' : 'Continue without an account',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color:
              isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
