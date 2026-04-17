# Play Console خطوات ملء الخطوات — الواجهة الجديدة

## الخطوة 1: Privacy Policy URL

**المسار (من الواجهة الحالية):**
1. في الـ sidebar الأيسر اضغط **Test and release**
2. سيظهر تحته خيارات فرعية — ابحث عن **Preparation** أو **Closed testing**
3. اضغط على **Store listing** (أو روح مباشرة للخطوة التالية)

**أو المسار البديل الأسرع:**
1. من الـ sidebar اضغط **Test and release**
2. في الـ dropdown ستجد **Prepare for release** أو نفس الخيارات
3. ابحث عن **Store listing** 

**في صفحة Store listing:**
- ستجد حقل **Privacy policy**
- الصقها هنا:
```
https://quraan-dd543.web.app/privacy
```
- اضغط **Save**

---

## الخطوة 2: Data Safety Questionnaire

**أين توجد؟**
1. من الـ sidebar اضغط **Test and release**
2. اضغط على **Data safety or policies** (إن وجدت)
3. أو روح مباشرة: **Setup** (إن كانت موجودة في الـ sidebar)
4. ابحث عن **Data safety questionnaire**

**إذا ما لقيتها:**
- اضغط على **Policy** من الـ sidebar الرئيسي
- ستجد **Data safety** هناك

**الرابط المباشر (الأسهل):**
```
https://play.google.com/console/u/0/developers/[id]/app/com.nooraliman.quran/data-safety
```

---

## الخطوات من Dashboard الحالي (الطريقة السهلة):

### **من الصندوق الأول — "Provide app information and create your store listing"**

1. اضغط **View tasks** (الزر تحت الصندوق)
2. ستظهر قائمة بالمهام
3. ابحث عن:
   - ✓ **Create or update your app details** 
   - ✓ **Configure app settings**
   - ✓ **Set up your store listing**

4. اضغط على **Set up your store listing**
   - Fill في:
     - **App name:** نور الإيمان - قرآن وأذان
     - **Description:** [انظر الخطوة 4 أدناه]
     - **Privacy policy:** https://quraan-dd543.web.app/privacy

---

### **من الصندوق الثاني — "Closed testing"**

1. في نفس الصندوق اضغط **View tasks**
2. ابحث عن **Data & privacy** أو **Data safety**
3. اضغط عليها وملأ الفورم (انظر الأسئلة والإجابات أدناه)

---

### Q1: Does your app collect any personal data?
**Answer:** YES

### Q2: Select the personal data types you collect:
اختر:
- ✓ **Approximate location** (وليس Precise location)
- ✓ **Name**
- ✓ **Email address**
- ✓ **App interactions** (or User-generated content)

### Q3: لكل نوع بيانات، اختر:

#### Approximate Location (ليس Precise)
- **Data is encrypted in transit?** → ✓ YES
- **Users can request deletion?** → ✓ YES
- **Primary purpose:** App functionality (prayer times, Qibla)

**تفاصيل إضافية عند السؤال:**

**هل يتم جمع هذه البيانات أو مشاركتها**
- ✓ بيانات يتم جمعها فقط (NOT مشاركتها)

**هل تتم معالجة البيانات بشكل مؤقت؟**
- ✓ نعم، هذه البيانات المجمّعة تتم معالجتها بشكل مؤقّت (للحساب الفوري للأوقات فقط ثم تُحفظ)

**هل جمع البيانات مطلوب أم اختياري؟**
- ✓ يمكن للمستخدمِين اختيار جمع هذه البيانات أو عدم جمعها (اختياري - بعد إدخال المدينة يدوياً)

#### Name
- **Data is encrypted in transit?** → ✓ YES
- **Users can request deletion?** → ✓ YES
- **Primary purpose:** Account management

**تفاصيل إضافية عند السؤال:**

**هل يتم جمع هذه البيانات أو مشاركتها**
- ✓ بيانات يتم جمعها فقط (NOT مشاركتها)

**هل تتم معالجة البيانات بشكل مؤقت؟**
- ✓ لا، هذه البيانات المجمّعة لا تتم معالجتها بشكل مؤقّت (يتم تخزينها مع حساب المستخدم)

**هل جمع البيانات مطلوب أم اختياري؟**
- ✓ يمكن للمستخدمِين اختيار جمع هذه البيانات أو عدم جمعها (اختياري - عند تسجيل الدخول فقط)

**لماذا يتم جمع البيانات؟**
- ✓ وظائف التطبيق — لتحديد هوية المستخدم
- ✓ إدارة الحساب — لضبط وإدارة حسابات المستخدمين

#### Email Address
- **Data is encrypted in transit?** → ✓ YES
- **Users can request deletion?** → ✓ YES
- **Primary purpose:** Account management

**تفاصيل إضافية عند السؤال:**

**هل يتم جمع هذه البيانات أو مشاركتها**
- ✓ بيانات يتم جمعها فقط (NOT مشاركتها)

**هل تتم معالجة البيانات بشكل مؤقت؟**
- ✓ لا، هذه البيانات المجمّعة لا تتم معالجتها بشكل مؤقّت (يتم تخزينها مع الحساب)

**هل جمع البيانات مطلوب أم اختياري؟**
- ✓ يمكن للمستخدمِين اختيار جمع هذه البيانات أو عدم جمعها (اختياري - عند تسجيل الدخول فقط)

**لماذا يتم جمع البيانات؟**
- ✓ إدارة الحساب — للتواصل والتحقق من الهوية

#### App Interactions
- **Data is encrypted in transit?** → ✓ YES
- **Users can request deletion?** → ✓ YES
- **Primary purpose:** App functionality

**البيانات المجمعة:**
- الملاحظات والإشارات المرجعية (bookmarks/favorites على الآيات)
- سجل القراءة (آخر موضع قراءة للمستخدم)
- الإعدادات المحفوظة (اللغة، الثيم، طريقة الحساب)
- سجل البحث

**ملاحظة:** جميع البيانات محفوظة محلياً على جهاز المستخدم فقط (لا تُرسل لخادم)

**تفاصيل إضافية عند السؤال:**

**هل يتم جمع هذه البيانات أو مشاركتها**
- ✓ بيانات يتم جمعها فقط (NOT مشاركتها)

**هل تتم معالجة البيانات بشكل مؤقت؟**
- ✓ نعم، هذه البيانات المجمّعة تتم معالجتها بشكل مؤقّت (ملاحظات المستخدم المحفوظة محلياً)

**هل جمع البيانات مطلوب أم اختياري؟**
- ✓ يمكن للمستخدمِين اختيار جمع هذه البيانات أو عدم جمعها (اختياري - الملاحظات والإشارات المرجعية)

**لماذا يتم جمع البيانات؟ اختر:**
- ✓ وظائف التطبيق — للسماح للمستخدم بحفظ الملاحظات والإشارات واستئناف القراءة
- (اختياري) ✓ تخصيص — إذا كان التطبيق يعرض اقتراحات بناءً على سجل القراءة

### Q4: Do you share this data with third parties?
**Answer:** NO

**ملاحظة:** التطبيق لا يشارك أي بيانات مع جهات خارجية — بما فيها خدمات التحليلات أو الإعلانات.

### Q5: Is your app a children's app?
**Answer:** NO (but suitable for ages 3+)

---

## الخطوة 3: Authorized App Access (الوصول إلى التطبيقات)

**المسار:**
1. من sidebar → **Policy** → **App content** أو **Setup** → **Access**
2. ابحث عن **Authorized app access** أو **App access & authentication**

**السؤال:**
```
جميع الوظائف في تطبيقي متاحة بدون أي قيود أم بها قيود؟
```

**الإجابة الصحيحة:**
```
✓ جميع الوظائف في تطبيقي متاحة بدون أي قيود مفروضة على الوصول إليها
```

**السبب:**
- لا يوجد تسجيل دخول إجباري (لا forced login)
- لا يوجد اشتراكات مدفوعة تحجب الميزات
- لا يوجد قيود على الموقع الجغرافي
- جميع الميزات متاحة **حتى بدون Google Sign-In**:
  - ✅ القرآن الكريم كاملاً
  - ✅ أوقات الصلاة (بعد إدخال المدينة يدوياً أو السماح بالموقع)
  - ✅ الأذان والتنبيهات
  - ✅ اتجاه القبلة
  - ✅ الأذكار والأحاديث

**ملاحظة:** Google Sign-In اختياري فقط لحفظ الملاحظات والإشارات في السحابة

---

## الخطوة 6: Content Ratings (تقييمات المحتوى)

**المسار:**
1. من sidebar → **Policy** → **App content**
2. ابحث عن **Content ratings questionnaire** أو **Rating questionnaire**

**الأسئلة والإجابات:**

### Q1: هل يحتوى التطبيق على محتوى مرتبط بالتصنيفات (جنس، عنف، لغة)؟
```
✓ لا
```
**السبب:** التطبيق يحتوي على محتوى إسلامي نظيف فقط (قرآن كريم، أذكار، أحاديث)

---

### Q2: هل يسمح التطبيق بالتفاعل بين المستخدمين (رسائل، صوت، صور)؟
```
✓ لا
```
**السبب:** التطبيق لا يوفر خاصية مراسلة أو دردشة أو مشاركة محتوى بين المستخدمين

---

### Q3: هل يعرض التطبيق محتوى عبر الإنترنت (ليس من التنزيل الأولي)؟
```
✓ نعم
```
**السبب:**
- صفحات المصحف تُحمّل **ديناميكياً** بعد التثبيق من Firebase
- المستخدم يحتاج **إنترنت** لعرض محتوى المصحف
- الخطوط والـ QCF → أصول مضمنة مع البناء الأولي
- محتوى المصحف → يُحمّل عند الحاجة (Lazy Loading)

**ملاحظة:** محتوى عبر الإنترنت يعني محتوى يُحمّل من الخادم (مثل Netflix, Spotify, قراء الأخبار)

---

### Q4: هل يتم ترويج أو بيع أنشطة/منتجات مقيدة حسب العمر؟
```
✓ لا
```
**السبب:** التطبيق لا يتضمن محتوى بالغين، مراهنات، أو كحول أو دخان

---

**المسار:**
1. من sidebar → **Policy** → **App content** أو **Setup** → **Permissions**
2. راجع التصاريح الحساسة المتبقية التالية:
   - `SCHEDULE_EXACT_ALARM`
   - `ACCESS_NOTIFICATION_POLICY`
   - Foreground Service `specialUse`
3. استخدم وصفًا مطابقًا للسلوك الفعلي داخل التطبيق (بدون مبالغة)
4. ملاحظة مهمة:

- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` تم إزالته من Manifest لتقليل حساسية المراجعة.
- التطبيق يكتفي بتوجيه المستخدم لإعدادات النظام العامة للبطارية بدون طلب إعفاء مباشر.

**نص مقترح لـ SCHEDULE_EXACT_ALARM:**

```
Used to schedule prayer-time alerts (Adhan) at exact times.
The app is time-sensitive by nature (religious prayer reminders), and inexact delivery can miss the prayer window.
```

**نص مقترح لـ ACCESS_NOTIFICATION_POLICY:**

```
Used only when the user enables silent-during-prayer mode, to temporarily control ringer behavior during configured prayer windows.
The feature is optional and can be disabled any time from settings.
```

**نص مقترح لـ Foreground Service (specialUse):**

```
Used for an optional, user-enabled persistent prayer-times notification showing next prayer and remaining time.
Users can disable it from app settings or directly from the notification action.
```

**مرجع جاهز للاستخدام السريع:**

- راجع ملف: `PLAY_CONSOLE_SENSITIVE_PERMISSIONS_DECLARATION.md`
- وملف: `PLAY_CONSOLE_FGS_DECLARATION.md`

---

## الخطوة 6: App Name & Description

**المسار:**
1. من sidebar → **Store listing**
2. عدّل:

**App name** (مرئي في البحث):
```
نور الإيمان - قرآن وأذان
```

**Short description** (80 حرف):
```
قرآن كريم | أوقات الصلاة | أذان | قبلة | أذكار | Quran
```

**Full description** (ابدأ بالكلمات الرئيسية):
```
نور الإيمان — تطبيق إسلامي شامل

📖 القرآن الكريم كاملاً مع المصحف الشريف
🕌 أوقات الصلاة الدقيقة
📡 الأذان بأجمل الأصوات
🧭 اتجاه القبلة
📿 أذكار يومية
📚 أحاديث صحيح البخاري

Quran | Prayer Times | Adhan | Islamic App | Qibla | Adhkar
```

---

## إذا لم تجد Data Safety

**جرب هذا الرابط المباشر:**
```
https://play.google.com/console/u/0/developers/[your-developer-id]/app/com.nooraliman.quran/data-safety
```

أو اسأل في Google Play Console Help أو ابحث في الـ sidebar عن أي كلمة من:
- Data
- Safety
- Privacy
- Questionnaire
- Declarations

---

## أسئلة إضافية قد تظهر:

### **Data Collection and Security**

**Q: Does your app collect or share any of the required user data types?**
```
✓ Yes
```

**Q: Is all of the user data collected by your app encrypted in transit?**
```
✓ Yes
```

**Q: Is all of the user data that is collected and shared by your app encrypted when stored?**
```
✓ Yes
```

**Q: Do you allow users to request and receive all of their data that you collect in a portable and readily transferable format?**
```
✓ Yes
```

**Q: Do you allow users to request the deletion of their data?**
```
✓ Yes
```

---

### **Account Creation Methods**

**Q: Which of the following methods of account creation does your app support?**

**اختر جميع الخيارات التي تنطبق:**

```
✓ OAuth
```

**ملاحظات:**
- **OAuth** = Google Sign-In ✅
- إذا كان التطبيق يسمح بالاستخدام **بدون حساب إجباري**:
  - ✓ اختر أيضاً: **My app does not allow users to create an account**

---

**الخطوات:**
1. اضغط على مربع ✓ بجانب **OAuth**
2. إذا كان التطبيق يسمح بالوصول بدون تسجيل:
   - اضغط أيضاً على **My app does not allow users to create an account**
3. اضغط **Save** أو **Continue**

---

### **Delete Account & Data Deletion**

**Q: Add a link that users can use to request account and data deletion**

**Delete account URL:**
```
https://quraan-dd543.web.app/delete-account
```

**Q: Do you provide a way for users to request data deletion without deleting the account?**

اختر واحد:
```
✓ No, but user data is automatically deleted within 90 days
```

أو إذا كان التطبيق بدون نظام حذف تلقائي:
```
✓ No
```

---

**ملاحظة:** سيُطلب منك إضافة صفحة Delete Account على Firebase Hosting (مشابهة للـ Privacy Policy سابقاً)

---

### **Additional Badges (اختياري)**

- **Independent security review:** ⏭️ تخطي
- **UPI Payments verified:** ⏭️ تخطي (التطبيق غير تطبيق مالي)

---

## الخطوة 7️⃣: Targeted Audience and Age Groups

**أين توجد؟**
1. من الـ sidebar اضغط **Create an app**
2. ابحث عن **Target audience and content** أو **Content maturity rating**
3. أو في Dashboard الرئيسي، ابحث عن صندوق **Target audience**

**الفئات العمرية المستهدفة:**

اختر **جميع الفئات**:
```
✓ 5 سنوات وأصغر
✓ من 6 إلى 8 سنوات
✓ من 9 إلى 12 سنة
✓ من 13 إلى 15 سنة
✓ من 16 إلى 17 سنة
✓ 18 سنة وأكثر
```

**السبب:**
- التطبيق محتوى ديني آمن للجميع
- لا يحتوي على عنف أو محتوى غير مناسب
- مناسب للأطفال والبالغين

---

### متطلبات Families Policy (سياسة العائلات)

عند اختيار فئات عمرية تشمل الأطفال، يجب الالتزام بـ **Families Policy**:

#### ✅ اختيارات يجب الالتزام بها:

1. **المحتوى المناسب للأطفال:**
   ```
   ✓ نعم، جميع محتويات التطبيق مناسبة للأطفال
   ```
   - لا عنف، لا محتوى بالغي، لا إعلانات مخيفة

2. **الإعلانات:**
   ```
   ✓ استخدم شبكات إعلانات معتمدة من Google Play فقط
   ```
   - استخدم Google AdMob (وليس شبكات إعلانات خارجية)
   - تأكد من عدم عرض إعلانات للكحول أو السجائر أو الألعاب
   - عدم عرض إعلانات موجهة للبالغين بغض النظر عن العمر

3. **الامتثال للقوانين:**
   ```
   ✓ التطبيق يتوافق مع:
   - COPPA (قانون حماية خصوصية الأطفال الأمريكي)
   - GDPR (اللائحة الأوروبية العامة لحماية البيانات)
   - قوانين الخصوصية المحلية
   ```

4. **بيانات الأطفال:**
   - ✓ عدم جمع بيانات إلا الضروري جداً
   - ✓ عدم مشاركة البيانات مع أطراف ثالثة
   - ✓ توفير رابط حذف البيانات (متوفر في صفحة طلب حذف البيانات)

---

### تفاصيل إضافية في نفس القسم:

#### Q: مسئول خصوصية البيانات (Data Protection Officer)
```
✓ نعم، معلومات التواصل:
   البريد الإلكتروني: mohamed.ashraf.1177s@gmail.com
```

#### Q: هل توفِّر للمستخدمين طريقة يمكنهم بها طلب حذف بعض بياناتهم بدون حذف الحساب؟
```
✓ نعم - نوفر طريقة شاملة لطلب حذف البيانات:

   صفحة طلب حذف البيانات:
   https://quraan-dd543.web.app/data-deletion-request

   المميزات:
   • اختيار نوع البيانات المراد حذفها (الإشارات المرجعية، الورد اليومي، الإعدادات، السجل)
   • أو حذف كل البيانات دفعة واحدة
   • الحفاظ على الحساب (غير حذف الحساب)
   • رابط مدمج في تطبيق (قائمة الإعدادات)
   • معالجة آمنة والتحقق من ملكية الحساب
   • حذف خلال 7 أيام عمل
   • تأكيد عبر البريد الإلكتروني
```

#### Q: أين يمكن للمستخدمين حذف بياناتهم أو طلب الحذف؟
```
✓ خيارات متعددة:

   1. طلب حذف بيانات محددة (دون حذف الحساب):
      https://quraan-dd543.web.app/data-deletion-request
      
   2. حذف الحساب والبيانات كاملة (نهائي):
      https://quraan-dd543.web.app/delete-account
      
   3. من داخل التطبيق:
      الإعدادات > قسم الحساب > "طلب حذف البيانات" أو "حذف الحساب"
```

---

## ملخص الخطوات النهائي:

| الخطوة | الحالة | الملاحظات |
|------|--------|---------|
| 1️⃣ Privacy Policy URL | ✅ | https://quraan-dd543.web.app/privacy |
| 2️⃣ Data Safety Questionnaire | ✅ | جميع الإجابات مملوءة |
| 3️⃣ Authorized App Access | ✅ | جميع الوظائف بدون قيود |
| 4️⃣ Content Ratings | ✅ | لا محتوى غير مناسب |
| 5️⃣ Battery Permission | ✅ | REQUEST_IGNORE_BATTERY_OPTIMIZATIONS → Alarms & reminders |
| 6️⃣ App Name & Description | ✅ | نور الإيمان - قرآن وأذان |
| 7️⃣ Targeted Audience & Age Groups | ✅ | جميع الفئات العمرية + Families Policy |
| 8️⃣ Build APK Release | ⏳ | بعد ملء جميع الخطوات أعلاه |
| 9️⃣ رفع الـ APK | ⏳ | Upload إلى Play Console → Production |

---

## ملاحظات إضافية لـ Data Safety Form

### الأسئلة الشائعة المتكررة لكل نوع بيانات:

عند ملء استمارة Data Safety، قد تُسأل الأسئلة التالية **لكل نوع بيانات**:

1. **هل يتم جمع البيانات أو مشاركتها أو كلاهما؟**
   - الإجابة: **بيانات يتم جمعها** (اختر COLLECTION فقط، لا تختر SHARING)

2. **هل تتم معالجة البيانات بشكل مؤقت؟**
   - الموقع + التفاعلات: **نعم** (معالجة مؤقتة)
   - الاسم + البريد الإلكتروني: **لا** (تخزين دائم مع الحساب)

3. **هل جمع البيانات مطلوب أم اختياري؟**
   - الإجابة: **اختياري** لجميع البيانات (المستخدم يمكنه عدم التسجيل)

4. **لماذا يتم جمع البيانات؟** (اختر ALL المناسبة):
   - **Approximate Location**: وظائف التطبيق
   - **Name**: وظائف التطبيق + إدارة الحساب
   - **Email**: إدارة الحساب
   - **App Interactions**: وظائف التطبيق
