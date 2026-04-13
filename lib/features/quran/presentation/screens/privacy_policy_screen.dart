import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.isArabic = true});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'سياسة الخصوصية' : 'Privacy Policy'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isArabic ? _ArabicPolicy(isDark: isDark) : _EnglishPolicy(isDark: isDark),
      ),
    );
  }
}

class _ArabicPolicy extends StatelessWidget {
  const _ArabicPolicy({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title('سياسة الخصوصية — تطبيق نور الإيمان', isDark),
          _SubText('آخر تحديث: أبريل 2026', isDark),
          const SizedBox(height: 16),
          _Para(
            'نحن في نور الإيمان نحترم خصوصيتك. توضح هذه السياسة كيفية جمع بياناتك واستخدامها وحمايتها عند استخدام تطبيقنا.',
            isDark,
          ),
          _Section('1. البيانات التي نجمعها', isDark),
          _BulletPoint('الموقع الجغرافي (عند الإذن): لحساب أوقات الصلاة وتحديد اتجاه القبلة. لا يتم مشاركة موقعك مع أي جهة خارجية.', isDark),
          _BulletPoint('بيانات حساب Google: الاسم والبريد الإلكتروني عند تسجيل الدخول بحساب Google، لإتاحة مزامنة الإشارات المرجعية والتقدم.', isDark),
          _BulletPoint('بيانات الاستخدام: الإشارات المرجعية، نتائج الاختبارات، تقدم الورد، أوقات التشغيل — محفوظة في حسابك على Firebase.', isDark),
          _Section('2. كيف نستخدم البيانات', isDark),
          _BulletPoint('لحساب أوقات الصلاة والأذان وتحديد اتجاه القبلة.', isDark),
          _BulletPoint('لمزامنة تقدمك عبر أجهزتك المختلفة.', isDark),
          _BulletPoint('لتحسين تجربة استخدام التطبيق.', isDark),
          _Section('3. مشاركة البيانات', isDark),
          _Para('لا نبيع بياناتك ولا نشاركها مع أطراف ثالثة لأغراض تجارية. البيانات تُخزَّن على خوادم Firebase (Google Cloud) المشفرة.', isDark),
          _Section('4. الإعلانات', isDark),
          _Para('التطبيق لا يحتوي على أي إعلانات ولا يستخدم أي شبكات إعلانية.', isDark),
          _Section('5. حذف البيانات', isDark),
          _Para('يمكنك حذف حسابك وجميع بياناتك المرتبطة به من داخل التطبيق من قائمة الإعدادات ← معلومات الحساب ← حذف الحساب.', isDark),
          _Section('6. أمان البيانات', isDark),
          _Para('جميع البيانات مشفرة أثناء النقل (TLS) وأثناء التخزين على Firebase. نتبع أفضل الممارسات الأمنية لحماية معلوماتك.', isDark),
          _Section('7. الأطفال', isDark),
          _Para('التطبيق مناسب لجميع الأعمار ولا يجمع بيانات شخصية من الأطفال دون الـ 13 عاماً بشكل متعمد.', isDark),
          _Section('8. التواصل معنا', isDark),
          _Para('لأي استفسار بخصوص الخصوصية، تواصل معنا عبر صفحة الاقتراحات داخل التطبيق.', isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _EnglishPolicy extends StatelessWidget {
  const _EnglishPolicy({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title('Privacy Policy — Noor Al-Iman App', isDark),
        _SubText('Last updated: April 2026', isDark),
        const SizedBox(height: 16),
        _Para(
          'At Noor Al-Iman, we respect your privacy. This policy explains how we collect, use, and protect your data when you use our app.',
          isDark,
        ),
        _Section('1. Data We Collect', isDark),
        _BulletPoint('Precise location (when permitted): To calculate prayer times and Qibla direction. Your location is never shared with third parties.', isDark),
        _BulletPoint('Google account data: Your name and email when signing in with Google, used for bookmark and progress sync.', isDark),
        _BulletPoint('Usage data: Bookmarks, quiz scores, Wird progress — stored in your Firebase account.', isDark),
        _Section('2. How We Use Data', isDark),
        _BulletPoint('To calculate prayer times, Adhan scheduling, and Qibla direction.', isDark),
        _BulletPoint('To sync your progress across devices.', isDark),
        _BulletPoint('To improve the app experience.', isDark),
        _Section('3. Data Sharing', isDark),
        _Para('We do not sell or share your data with third parties for commercial purposes. Data is stored on encrypted Firebase (Google Cloud) servers.', isDark),
        _Section('4. Advertising', isDark),
        _Para('The app contains no advertisements and uses no ad networks.', isDark),
        _Section('5. Data Deletion', isDark),
        _Para('You can delete your account and all associated data from within the app: Settings → Account Info → Delete Account.', isDark),
        _Section('6. Data Security', isDark),
        _Para('All data is encrypted in transit (TLS) and at rest on Firebase. We follow security best practices to protect your information.', isDark),
        _Section('7. Children', isDark),
        _Para('The app is suitable for all ages and does not knowingly collect personal data from children under 13.', isDark),
        _Section('8. Contact Us', isDark),
        _Para('For any privacy inquiries, contact us via the Feedback page inside the app.', isDark),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title(this.text, this.isDark);
  final String text;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.primary,
          height: 1.4,
        ),
      );
}

class _SubText extends StatelessWidget {
  const _SubText(this.text, this.isDark);
  final String text;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.text, this.isDark);
  final String text;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primary,
          ),
        ),
      );
}

class _Para extends StatelessWidget {
  const _Para(this.text, this.isDark);
  final String text;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
        ),
      );
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint(this.text, this.isDark);
  final String text;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      );
}
