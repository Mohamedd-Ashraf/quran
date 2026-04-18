# خطة توحيد تصميم واجهة المستخدم — نور الإيمان
## Noor Al-Imaan UI Unification & Settings Refresh Plan

> **التاريخ:** 18 أبريل 2026  
> **الهدف:** توحيد شكل وتنسيق كل صفحات التطبيق + تحسين صفحة الإعدادات

---

## 📋 ملخص المشاكل الحالية

| المشكلة | التفاصيل |
|---------|----------|
| **AppBar غير موحّد** | بعض الشاشات بدون gradient، وكل شاشة تستخدم خط مختلف للعنوان |
| **Padding متغير** | كل شاشة بقيم padding مختلفة (4, 12, 16, 20, 36) |
| **Section Headers مختلفة** | Home تستخدم gold underline، More تستخدم gradient badge مختلف، Settings تستخدم gradient pill |
| **Cards غير متسقة** | border radius يتراوح بين 10-16، بعضها بـ border وبعضها بدون |
| **صفحة الإعدادات** | المسافات بين الأقسام ضيقة (6px)، الكروت بسيطة، تحتاج polish |
| **ألوان hardcoded** | بعض الشاشات تستخدم ألوان ثابتة بدل الـ design system |

---

## 🏗️ Phase 1 — Shared AppBar Widget

### ملف جديد: `lib/core/widgets/gradient_app_bar.dart`

**الوصف:** Widget موحّد يرجع `AppBar` بتصميم ثابت لكل الشاشات.

**المواصفات:**
- `flexibleSpace` بـ `AppColors.primaryGradient`
- `centerTitle: true`
- خط العنوان من الـ Theme (`titleLarge`) — مش خط مخصص
- دعم `actions`, `leading`, `bottom` (للـ TabBar)
- `elevation: 0` (Material 3)
- دعم `titleWidget` مخصص للشاشات اللي محتاجة عنوان غير نصي

### الشاشات المتأثرة:

| الشاشة | المشكلة الحالية | التعديل |
|--------|----------------|---------|
| `bookmarks_screen.dart` | **بدون gradient نهائياً** | إضافة gradient AppBar |
| `home_screen.dart` | `arefRuqaa` 19px مخصص | استخدام الـ widget الموحّد مع `titleWidget` للشعار |
| `more_screen.dart` | `arefRuqaa` 18px مخصص | استخدام الـ widget الموحّد |
| `hadith_categories_screen.dart` | `Amiri` 16px + SliverAppBar | استخدام الـ widget الموحّد (مع الحفاظ على SliverAppBar) |
| `hadith_list_screen.dart` | `Amiri` 16px + SliverAppBar | نفس التعديل |
| `hijri_calendar_screen.dart` | `Amiri` 20px | استخدام الـ widget الموحّد |

### الشاشات اللي هتفضل زي ما هي (تصميم مميز بالقصد):
- `tasbeeh_screen.dart` — شاشة كاملة للتسبيح، transparent AppBar
- `surah_detail_screen.dart` — قارئ القرآن بدون AppBar (Stack-based)
- `ruqyah_screen.dart` — تصميم غامر بدون AppBar
- `search_screen.dart` — AppBar فيه search field مخصص
- `mushaf_page_screen.dart` — عرض صفحة المصحف الكامل

---

## 🏗️ Phase 2 — Design System Tokens

### ملف: `lib/core/theme/app_design_system.dart`

**إضافات جديدة:**
```dart
// Section spacing
static const double sectionTopPadding = 20.0;
static const double sectionBottomPadding = 10.0;
static const double sectionGap = 16.0;        // بدل 6.0 الحالية

// Page-level
static const double pageVerticalPadding = 12.0;
static const double pageBottomPadding = 24.0;

// Standard page padding
static const EdgeInsets pagePaddingAll = EdgeInsets.fromLTRB(16, 12, 16, 24);
```

### الشاشات المتأثرة بتوحيد الـ Padding:

| الشاشة | Padding الحالي | الجديد |
|--------|---------------|--------|
| `settings_screen.dart` | `h:16, v:12` | `fromLTRB(16, 12, 16, 24)` |
| `adhkar_categories_screen.dart` | `fromLTRB(16, 4, 16, 24)` | `fromLTRB(16, 12, 16, 24)` |
| `hijri_calendar_screen.dart` | `fromLTRB(16, 20, 16, 36)` | `fromLTRB(16, 12, 16, 24)` |
| `hadith_list_screen.dart` | `fromLTRB(16, 12, 16, 24)` | ✅ بالفعل صحيح |

---

## 🏗️ Phase 3 — Unified Section Headers

### ملف جديد: `lib/core/widgets/section_header.dart`

**الوصف:** استخراج `_SectionHeader` من Settings كـ widget عام `AppSectionHeader`.

**التصميم المعتمد (من Settings الحالية):**
- Gradient pill (أخضر) مع أيقونة + نص أبيض
- خط فاصل ممتد مع تدرج لوني
- Padding: `fromLTRB(2, 20, 2, 10)`
- Shadow: Primary 0.15 alpha, blur 8

### الشاشات المتأثرة:

| الشاشة | الستايل الحالي | التعديل |
|--------|---------------|---------|
| `home_screen.dart` | Title + gold underline + count badge | `AppSectionHeader` + trailing widget للعدد |
| `more_screen.dart` | Gradient badge مختلف + divider | `AppSectionHeader` |
| `settings_screen.dart` | `_SectionHeader` (المصدر) | استبدال بـ `AppSectionHeader` |
| باقي الشاشات | متنوع | مراجعة وتوحيد |

---

## 🏗️ Phase 4 — Settings Screen Visual Refresh

### ملف: `lib/features/quran/presentation/screens/settings_screen.dart`

### التعديلات التفصيلية:

#### 4.1 — تحسين المسافات بين الأقسام
- **قبل:** `SizedBox(height: 6)` بين كل section
- **بعد:** `SizedBox(height: 16)` — تنفس بصري أفضل

#### 4.2 — تحسين `_SettingsCard`
- **قبل:** `Card` عادي بـ `margin: bottom 10` فقط
- **بعد:** 
  - إضافة `clipBehavior: Clip.antiAlias` للكروت
  - شريط لوني رفيع (3px) على اليسار (primary color) كـ accent
  - `borderRadius: 16` موحّد (بدل القيم المتغيرة)

#### 4.3 — فواصل أنظف داخل الكروت
- إضافة `Divider(height: 1, indent: 56)` بين الـ ListTiles

#### 4.4 — تحسين القسم About
- أيقونات موحّدة لكل عنصر
- Version badge بتصميم أفضل في الأسفل

#### 4.5 — تنظيف ألوان الـ Reciter Picker
- **قبل:** Hardcoded `Color(0xFF1A1F25)` في الـ bottom sheet
- **بعد:** `AppColors.darkSurface` أو `Theme.of(context).colorScheme.surface`

#### 4.6 — رفع جودة الـ MushafEntryCard
- توحيد `borderRadius` من 14 إلى 16
- تحسين الـ Chips الداخلية

---

## 🏗️ Phase 5 — Card Styling Consistency

### القواعد الموحّدة للكروت:
- **Border Radius:** `AppDesignSystem.radiusLg` (16dp) في كل مكان
- **Border:** 1px من `AppColors.cardBorder` (light) أو `AppColors.darkDivider` (dark)
- **Elevation:** 0 (Material 3 flat style)
- **Margin:** `EdgeInsets.only(bottom: AppDesignSystem.cardMargin)` (10dp)

### الشاشات المتأثرة:
- `_MushafEntryCard` في settings (حالياً radius 14 → 16)
- `_NavCard` في more_screen
- Cards في home_screen, wird_screen, adhkar screens

---

## 📝 ملخص الملفات

### ملفات جديدة:
| الملف | الوصف |
|-------|-------|
| `lib/core/widgets/gradient_app_bar.dart` | AppBar موحّد بـ gradient |
| `lib/core/widgets/section_header.dart` | Section header موحّد بـ gradient pill |

### ملفات أساسية للتعديل:
| الملف | نوع التعديل |
|-------|------------|
| `lib/core/theme/app_design_system.dart` | إضافة tokens جديدة |
| `lib/features/quran/presentation/screens/settings_screen.dart` | تحسين بصري شامل |

### شاشات للتحديث (AppBar + padding + headers):
| الملف | التعديلات |
|-------|----------|
| `lib/features/quran/presentation/screens/home_screen.dart` | AppBar + section headers |
| `lib/features/quran/presentation/screens/bookmarks_screen.dart` | إضافة gradient AppBar |
| `lib/features/islamic/presentation/screens/more_screen.dart` | AppBar + section headers |
| `lib/features/hadith/presentation/screens/hadith_categories_screen.dart` | AppBar font |
| `lib/features/hadith/presentation/screens/hadith_list_screen.dart` | AppBar font |
| `lib/features/islamic/presentation/screens/hijri_calendar_screen.dart` | AppBar + padding |
| `lib/features/adhkar/presentation/screens/adhkar_categories_screen.dart` | Padding |

---

## ✅ Verification Checklist

```
□ كل الشاشات بنفس الـ gradient AppBar
□ الـ padding موحّد في كل الشاشات
□ الـ Section Headers بنفس الستايل
□ الكروت بنفس الـ border radius والـ styling
□ صفحة الإعدادات شكلها أفضل وأنظف
□ Dark Mode شغّال صح في كل التعديلات
□ اللغة العربية/الإنجليزية + RTL شغّالين
□ flutter build apk --debug بدون أخطاء
```
