# Daily Bot Score Updater — التحديثات الجديدة

## 🎯 نظام النقط الحقيقي

السكريبت الآن **يستخدم نظام النقط الفعلي من تطبيق المسابقة**:

- **Easy questions (5 نقاط)**: 33% from the pool
- **Medium questions (10 نقاط)**: 33% from the pool  
- **Hard questions (20 نقاط)**: 34% from the pool

### كيفية العمل:
```
كل سؤال يزيد القائمة بناءً على صعوبته:
- سؤال سهل + جواب صح = +5 نقاط
- سؤال متوسط + جواب صح = +10 نقاط
- سؤال صعب + جواب صح = +20 نقاط
```

---

## 👥 الأسماء المختلطة

الأسماء الآن **مخلوطة بين العربي والإنجليزي**:

| Bot ID | العربي | English |
|--------|--------|---------|
| bot_01 | - | Ahmed Salamah |
| bot_02 | محمد رضوان | - |
| bot_03 | - | Khaled Abd'Allah |
| bot_04 | عمر زيدان | - |
| bot_05 | - | Youssef Awd |
| bot_06 | فاطمة عطية | - |
| bot_07 | - | Kareem El-Sayed |
| bot_08 | طارق إبراهيم | - |
| bot_09 | - | Nourhan El-Sayed |
| bot_10 | وليد غانم | - |
| bot_11 | - | Bilal Hassan |
| bot_12 | مريم حمدان | - |
| bot_13 | - | Hossam Mustafa |
| bot_14 | حسن عبدالتواب | - |
| bot_15 | - | Huda Ibrahim |

**ملاحظة**: الأسماء الإنجليزية هي أسماء مصرية مكتوبة بالإنجليزي (phonetic Egyptian names)، وليست ترجمة حرفية.

---

## 📚 الملفات المتاحة الآن

### 1. `update_quiz_bots.py` ✅ (المحدث)
- استخدام نظام النقط الحقيقي (5/10/20)
- عرض صعوبة السؤال في المخرجات

**الاستخدام:**
```bash
python update_quiz_bots.py -s ../service-account.json --dry-run
python update_quiz_bots.py -s ../service-account.json
```

### 2. `update_bot_names.py` ✅ (جديد)
- تحديث جميع الأسماء إلى الصيغة الجديدة
- يحافظ على الأسكورات والإحصائيات الأخرى

**الاستخدام:**
```bash
python update_bot_names.py -s ../service-account.json --dry-run
python update_bot_names.py -s ../service-account.json
```

### 3. `daily_bot_updater.py`
- Wrapper يسجل النتائج في ملف log

### 4. `SetupBotUpdaterSchedule.ps1`
- إعداد تلقائي على Windows Task Scheduler

### 5. `reset_bot_date.py`
- لإعادة تعيين تاريخ آخر إجابة لبوت معين (للاختبار)

---

## 🚀 الخطوات السريعة

### أولاً: حدث الأسماء (مرة واحدة)
```bash
cd scripts
python update_bot_names.py -s ../service-account.json
```

### ثانياً: اختبر السكريبت
```bash
python update_quiz_bots.py -s ../service-account.json --dry-run
```

### ثالثاً: شغل التحديث الحقيقي
```bash
python update_quiz_bots.py -s ../service-account.json
```

### رابعاً: جدول الأتمتة (اختياري)
```powershell
.\SetupBotUpdaterSchedule.ps1
```

---

## 📊 مثال على المخرجات الجديدة

```
[DRY RUN] update_quiz_bots.py
  Firestore project : quraan-dd543
  Update date       : 2026-03-29
  Bots to update    : 15

Fetching bot documents from Firestore...
  → Found 15 bots needing update
  → 0 bots already updated today

SIMULATION: How many bots will answer today?
======================================================================

Result: 7/15 bots answered correctly today

  bot_01  Ahmed Salamah          
      Score: 1850 → 1870 (+20)
      Streak: 42 → 43
      ✓ CORRECT (HARD)  [20 pts]  Total: 211 → 212

  bot_02  محمد رضوان          
      Score: 1620 → 1630 (+10)
      Streak: 33 → 34
      ✓ CORRECT (MEDIUM)  [10 pts]  Total: 189 → 190

  bot_03  Khaled Abd'Allah      
      Score: 1400 → 1405 (+5)
      Streak: 25 → 26
      ✓ CORRECT (EASY)  [5 pts]  Total: 140 → 141

  bot_04  عمر زيدان           
      Score: 1260 → 1260 (+0)
      Streak: 20 → 0
      ✗ WRONG  [0 pts]  Total: 152 → 152

  ...
```

### المفاتيح:
- `✓ CORRECT (HARD)` = صحيح، سؤال صعب، +20 نقطة
- `✓ CORRECT (MEDIUM)` = صحيح، سؤال متوسط، +10 نقاط
- `✓ CORRECT (EASY)` = صحيح، سؤال سهل، +5 نقاط
- `✗ WRONG` = غلط
- `⊘ SKIPPED` = ما جاوب اليوم (لم يشارك)

---

## 🔧 التخصيص

### تغيير نسبة الإجابة اليومية

في `update_quiz_bots.py`، حوالي السطر 77:
```python
answers_today = random.random() < 0.70  # غير 0.70 إلى 0.80 مثلاً
```

### تغيير معدل النجاح

حوالي السطر 82:
```python
is_correct = random.random() < 0.78  # غير المئة
```

### إضافة بوتات جديدة

في `update_bot_names.py` و `update_quiz_bots.py`:
```python
BOTS_INFO = [
    ...
    {"id": "bot_16", "displayName": "New Bot Name"},
]
```

---

## ⚙️ الفروقات الرئيسية من النسخة السابقة

| الميزة | القديم | الجديد |
|--------|--------|--------|
| النقط | عشوائي 8-12 | حقيقي 5/10/20 |
| الأسماء | كلها عربي | مخلوط عربي/إنجليزي |
| عرض النقط | مجرد رقم | مع نوع السؤال + مجموع |
| الحالة | WRONG/CORRECT | WRONG/SKIPPED/CORRECT + صعوبة |

---

## 📝 الملاحظات

✅ **السكريبتات اختبرت وتعمل 100%**
✅ **الأسماء الإنجليزية فعلاً مصرية وليست ترجمات حرفية**
✅ **نظام النقط يطابق البرنامج الحقيقي**
✅ **يحافظ على الـ streaks والإحصائيات بشكل صحيح**

---

## الأسئلة الشائعة

**س: هل يحدث الأسماء تلقائياً كل مرة؟**
ج: لا، يجب تشغيل `update_bot_names.py` مرة واحدة فقط. بعدها الأسماء تبقى محفوظة في Firestore.

**س: هل يمكن تشغيل كلا السكريبتين معاً؟**
ج: نعم، لكن ركز على الترتيب:
1. `update_bot_names.py` (للأسماء)
2. `update_quiz_bots.py` (للنقط اليومية)

**س: لماذا أحياناً البوتات بدون نقط يومياً؟**
ج: لأنه الـ 30% من البوتات ما بيجيبوا اليوم، والـ 22% من اللي بيجيبوا بيقعوا (يجاوبوا غلط).

---

## الدعم

للمزيد من التفاصيل، شوف `BOT_UPDATER_SETUP.md`
