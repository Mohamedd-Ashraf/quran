package com.example.quraan

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

// ═══════════════════════════════════════════════════════════════════════════════
//  أذكار ما بعد الصلاة  –  Home-Screen Widget
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Constants ───────────────────────────────────────────────────────────────

private const val ADHKAR_PREFS       = "FlutterSharedPreferences"
private const val KEY_CACHED_PT      = "flutter.cached_prayer_times"

// Widget-specific state keys (stored in same prefs file)
private const val KEY_AW_PRAYER        = "adhkar_widget_prayer"        // fajr|dhuhr|asr|maghrib|isha
private const val KEY_AW_PHASE         = "adhkar_widget_phase"         // after_prayer|morning|evening|sleep|done
private const val KEY_AW_INDEX         = "adhkar_widget_index"         // index within current phase list
private const val KEY_AW_COUNT         = "adhkar_widget_count"         // repetition count for current dhikr
private const val KEY_AW_LAST_RESET    = "adhkar_widget_last_reset"    // "prayer_yyyyMMdd" dedup
// Intermediate display states
private const val KEY_AW_DHIKR_DONE    = "adhkar_widget_dhikr_done"   // true = dhikr just completed, show full ring before advancing
private const val KEY_AW_PHASE_ANNOUNCE = "adhkar_widget_phase_announce" // non-empty = show phase-change announcement screen

private const val ACTION_ADHKAR_TAP          = "com.example.quraan.ADHKAR_WIDGET_TAP"
private const val ACTION_ADHKAR_RESET        = "com.example.quraan.ADHKAR_WIDGET_RESET"
private const val ACTION_ADHKAR_UPDATE       = "com.example.quraan.ADHKAR_WIDGET_UPDATE"
private const val ACTION_ADHKAR_AUTO_ADVANCE = "com.example.quraan.ADHKAR_WIDGET_AUTO_ADVANCE"
private const val ADHKAR_REFRESH_MS          = 5 * 60 * 1000L   // 5 min auto-refresh (for prayer change detect)
private const val DHIKR_AUTO_ADVANCE_DELAY_MS = 900L             // brief pause to show full ring before auto-advance

// ─── Dhikr data model ────────────────────────────────────────────────────────

private data class WidgetDhikr(
    val shortText: String,   // label shown on widget face
    val target: Int,         // number of repetitions
)

// ─── Adhkar lists (mirrors lib/features/adhkar/data/adhkar_data.dart) ────────
// تشكيل مبسط: محفوظ في الكلمات التي قد يلتبس نطقها، محذوف من الكلمات الشائعة

private val AFTER_PRAYER = listOf(
    WidgetDhikr("أستغفر الله", 3),
    WidgetDhikr("اللهم أنت السلام ومنك السلام تباركت يا ذا الجلال والإكرام", 1),
    WidgetDhikr("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير، اللهم لا مانع لما أعطيت ولا معطي لما منعت", 1),
    WidgetDhikr("سبحان الله", 33),
    WidgetDhikr("الحمد لله", 33),
    WidgetDhikr("الله أكبر", 33),
    WidgetDhikr("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير", 1),
    // آية الكرسي كاملة
    WidgetDhikr("اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ", 1),
    WidgetDhikr("اللهم أعني على ذكرك وشكرك وحسن عبادتك", 1),
    WidgetDhikr("اللهم إني أسألك علماً نافعاً ورزقاً طيباً وعملاً متقبَّلاً", 1),
)

private val MORNING_ADHKAR = listOf(
    // آية الكرسي كاملة
    WidgetDhikr("اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ", 1),
    WidgetDhikr("قُلْ هُوَ اللَّهُ أَحَدٌ — سورة الإخلاص", 3),
    WidgetDhikr("قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ — سورة الفلق", 3),
    WidgetDhikr("قُلْ أَعُوذُ بِرَبِّ النَّاسِ — سورة الناس", 3),
    WidgetDhikr("أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له...", 1),
    WidgetDhikr("اللهم بك أصبحنا وبك أمسينا وبك نحيا وبك نموت وإليك النشور", 1),
    WidgetDhikr("اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك — سيد الاستغفار", 1),
    WidgetDhikr("اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري", 3),
    WidgetDhikr("اللهم إني أسألك العفو والعافية في الدنيا والآخرة", 1),
    WidgetDhikr("اللهم إني أعوذ بك من الهم والحزن والعجز والكسل والبخل والجبن وضلع الدين", 1),
    WidgetDhikr("سبحان الله وبحمده", 100),
    WidgetDhikr("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير", 10),
    WidgetDhikr("رضيت بالله رباً وبالإسلام ديناً وبمحمد ﷺ نبياً", 3),
    WidgetDhikr("حسبي الله لا إله إلا هو، عليه توكلت وهو رب العرش العظيم", 7),
)

private val EVENING_ADHKAR = listOf(
    // آية الكرسي كاملة
    WidgetDhikr("اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ", 1),
    WidgetDhikr("قُلْ هُوَ اللَّهُ أَحَدٌ — سورة الإخلاص", 3),
    WidgetDhikr("قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ — سورة الفلق", 3),
    WidgetDhikr("قُلْ أَعُوذُ بِرَبِّ النَّاسِ — سورة الناس", 3),
    WidgetDhikr("أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له...", 1),
    WidgetDhikr("اللهم بك أمسينا وبك أصبحنا وبك نحيا وبك نموت وإليك المصير", 1),
    WidgetDhikr("اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك — سيد الاستغفار", 1),
    WidgetDhikr("اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري", 3),
    WidgetDhikr("اللهم إني أسألك العفو والعافية في الدنيا والآخرة", 1),
    WidgetDhikr("اللهم إني أعوذ بك من الهم والحزن والعجز والكسل والبخل والجبن وضلع الدين", 1),
    WidgetDhikr("سبحان الله وبحمده", 100),
    WidgetDhikr("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير", 10),
    WidgetDhikr("رضيت بالله رباً وبالإسلام ديناً وبمحمد ﷺ نبياً", 3),
    WidgetDhikr("حسبي الله لا إله إلا هو، عليه توكلت وهو رب العرش العظيم", 7),
)

private val SLEEP_ADHKAR = listOf(
    WidgetDhikr("باسمك اللهم أموت وأحيا", 1),
    WidgetDhikr("اللهم قني عذابك يوم تبعث عبادك", 3),
    WidgetDhikr("باسمك ربي وضعت جنبي وبك أرفعه، إن أمسكت نفسي فاغفر لها وإن أرسلتها فاحفظها", 1),
    WidgetDhikr("اللهم أسلمت نفسي إليك وفوضت أمري إليك ووجهت وجهي إليك وألجأت ظهري إليك رغبةً ورهبةً إليك — آمنت بكتابك الذي أنزلت وبنبيك الذي أرسلت", 1),
    WidgetDhikr("سبحان الله", 33),
    WidgetDhikr("الحمد لله", 33),
    WidgetDhikr("الله أكبر", 34),
    WidgetDhikr("اللهم رب السموات ورب الأرض ورب العرش العظيم، ربنا ورب كل شيء، أعوذ بك من شر كل شيء أنت آخذ بناصيته", 1),
)

// ─── Phase helpers ───────────────────────────────────────────────────────────

private fun adhkarForPhase(phase: String): List<WidgetDhikr> = when (phase) {
    "morning"      -> MORNING_ADHKAR
    "evening"      -> EVENING_ADHKAR
    "sleep"        -> SLEEP_ADHKAR
    else           -> AFTER_PRAYER
}

private fun phaseTitle(phase: String): String = when (phase) {
    "morning"      -> "أذكار الصباح"
    "evening"      -> "أذكار المساء"
    "sleep"        -> "أذكار النوم"
    "done"         -> "تم بحمد الله ✓"
    else           -> "أذكار بعد الصلاة"
}

/**
 * Single unified header line. Shows what we're doing right now:
 * e.g. "أذكار بعد صلاة الفجر" or "أذكار الصباح" or "تم بحمد الله ✓"
 */
private fun unifiedHeader(prayer: String, phase: String): String = when (phase) {
    "after_prayer" -> if (prayer.isNotEmpty()) "أذكار بعد صلاة ${prayerDisplayName(prayer)}" else "أذكار بعد الصلاة"
    "morning"      -> "أذكار الصباح"
    "evening"      -> "أذكار المساء"
    "sleep"        -> "أذكار النوم"
    "done"         -> "تم بحمد الله ✓"
    else           -> "أذكار الصلاة"
}

/** Announce message when transitioning to a new phase */
private fun phaseAnnounceMessage(newPhase: String, prayer: String): String = when (newPhase) {
    "morning" -> "انتهيت من أذكار صلاة الفجر\nاضغط للبدء في أذكار الصباح 🌅"
    "evening" -> "انتهيت من أذكار صلاة ${prayerDisplayName(prayer)}\nاضغط للبدء في أذكار المساء 🌆"
    "sleep"   -> "انتهيت من أذكار صلاة العشاء\nاضغط للبدء في أذكار النوم 🌙"
    else      -> ""
}

private fun prayerDisplayName(prayer: String): String = when (prayer) {
    "fajr"    -> "الفجر"
    "dhuhr"   -> "الظهر"
    "asr"     -> "العصر"
    "maghrib" -> "المغرب"
    "isha"    -> "العشاء"
    else      -> "—"
}

/**
 * After completing after-prayer adhkar, decide the follow-up phase
 * based on which prayer we just finished.
 */
private fun followUpPhase(prayer: String): String? = when (prayer) {
    "fajr"    -> "morning"     // أذكار الصباح بعد الفجر
    "asr"     -> "evening"     // أذكار المساء بعد العصر
    "maghrib" -> "evening"     // أذكار المساء بعد المغرب (لو لم يقلها بعد العصر)
    "isha"    -> "sleep"       // أذكار النوم بعد العشاء
    else      -> null
}

// ─── Dispatcher ──────────────────────────────────────────────────────────────

object AdhkarWidgetUpdateDispatcher {
    fun refreshAll(context: Context) {
        val providers = listOf(
            AdhkarWidget::class.java,
            AdhkarWidgetDark::class.java,
            AdhkarWidgetLight::class.java,
        )
        providers.forEach { provider ->
            try {
                val intent = Intent(context, provider).apply { action = ACTION_ADHKAR_UPDATE }
                context.sendBroadcast(intent)
            } catch (_: Exception) {}
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Base Widget
// ═══════════════════════════════════════════════════════════════════════════════

abstract class BaseAdhkarWidget : AppWidgetProvider() {
    protected abstract val layoutResId: Int
    protected abstract val receiverClass: Class<out AppWidgetProvider>
    protected abstract val requestCode: Int
    protected abstract val beadColor: Int
    protected abstract val cordAlpha: Int
    protected abstract val accentColor: Int

    companion object {
        private const val BEAD_COUNT = 33
    }

    // ── AppWidgetProvider lifecycle ──────────────────────────────────────────

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        try {
            appWidgetIds.forEach { id -> safeUpdateWidget(context, appWidgetManager, id) }
        } catch (_: Exception) {}
        scheduleNextUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        try { super.onReceive(context, intent) } catch (_: Exception) {}
        try {
            when (intent.action) {
                ACTION_ADHKAR_TAP -> {
                    handleTap(context)
                    refreshWidgets(context)
                }
                ACTION_ADHKAR_RESET -> {
                    handleReset(context)
                    refreshWidgets(context)
                }
                ACTION_ADHKAR_AUTO_ADVANCE -> {
                    // Auto-fired ~900ms after a within-phase dhikr completes
                    if (readDhikrDone(context)) {
                        prefs(context).edit()
                            .putBoolean(KEY_AW_DHIKR_DONE, false)
                            .apply()
                        advanceAfterDhikrComplete(context)
                        refreshWidgets(context)
                    }
                }
                ACTION_ADHKAR_UPDATE,
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                "android.intent.action.QUICKBOOT_POWERON",
                "com.htc.intent.action.QUICKBOOT_POWERON",
                "com.example.quraan.ADHAN_STARTED" -> {
                    refreshWidgets(context)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onEnabled(context: Context) {
        try { super.onEnabled(context) } catch (_: Exception) {}
        scheduleNextUpdate(context)
    }

    override fun onDisabled(context: Context) {
        try { super.onDisabled(context) } catch (_: Exception) {}
        cancelScheduledUpdate(context)
    }

    // ── AlarmManager for periodic refresh ───────────────────────────────────

    private fun buildAlarmPI(context: Context): PendingIntent {
        val intent = Intent(context, receiverClass).apply { action = ACTION_ADHKAR_UPDATE }
        return PendingIntent.getBroadcast(
            context, requestCode + 500, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleNextUpdate(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildAlarmPI(context)
            val trigger = System.currentTimeMillis() + ADHKAR_REFRESH_MS
            try { am.setExact(AlarmManager.RTC, trigger, pi) }
            catch (_: SecurityException) { am.set(AlarmManager.RTC, trigger, pi) }
        } catch (_: Exception) {}
    }

    private fun cancelScheduledUpdate(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildAlarmPI(context))
        } catch (_: Exception) {}
    }

    // ── Auto-advance (within-phase) alarm helpers ────────────────────────────

    private fun buildAutoAdvancePI(context: Context): PendingIntent {
        val intent = Intent(context, receiverClass).apply { action = ACTION_ADHKAR_AUTO_ADVANCE }
        return PendingIntent.getBroadcast(
            context, requestCode + 200, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleAutoAdvance(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildAutoAdvancePI(context)
            val trigger = System.currentTimeMillis() + DHIKR_AUTO_ADVANCE_DELAY_MS
            try { am.setExact(AlarmManager.RTC, trigger, pi) }
            catch (_: SecurityException) { am.set(AlarmManager.RTC, trigger, pi) }
        } catch (_: Exception) {}
    }

    private fun cancelAutoAdvance(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildAutoAdvancePI(context))
        } catch (_: Exception) {}
    }

    // ── SharedPreferences helpers ───────────────────────────────────────────

    private fun prefs(context: Context) =
        context.getSharedPreferences(ADHKAR_PREFS, Context.MODE_PRIVATE)

    private fun readPrayer(ctx: Context)        = prefs(ctx).getString(KEY_AW_PRAYER, "") ?: ""
    private fun readPhase(ctx: Context)          = prefs(ctx).getString(KEY_AW_PHASE, "after_prayer") ?: "after_prayer"
    private fun readIndex(ctx: Context)          = prefs(ctx).getInt(KEY_AW_INDEX, 0)
    private fun readCount(ctx: Context)          = prefs(ctx).getInt(KEY_AW_COUNT, 0)
    private fun readLastReset(ctx: Context)      = prefs(ctx).getString(KEY_AW_LAST_RESET, "") ?: ""
    private fun readDhikrDone(ctx: Context)      = prefs(ctx).getBoolean(KEY_AW_DHIKR_DONE, false)
    private fun readPhaseAnnounce(ctx: Context)  = prefs(ctx).getString(KEY_AW_PHASE_ANNOUNCE, "") ?: ""

    // ── Prayer time detection ───────────────────────────────────────────────

    private data class PrayerTimeInfo(val name: String, val time: Date)

    /**
     * Determine which prayer we are currently "after".
     * Uses same cached_prayer_times JSON as PrayerTimesWidget.
     */
    private fun detectCurrentPrayer(context: Context): String? {
        return try {
            val raw = prefs(context).getString(KEY_CACHED_PT, null) ?: return null
            val root = JSONObject(raw)
            val times = root.optJSONObject("times") ?: return null

            val cal = Calendar.getInstance()
            val todayKey = calToKey(cal)
            val yesterdayCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }
            val yesterdayKey = calToKey(yesterdayCal)

            val dayJson = times.optJSONObject(todayKey)
                ?: times.optJSONObject(yesterdayKey)
                ?: return null

            val now = Date()
            val prayers = listOf(
                PrayerTimeInfo("fajr",    parseIso(dayJson.optString("fajr", "")) ?: return null),
                PrayerTimeInfo("dhuhr",   parseIso(dayJson.optString("dhuhr", "")) ?: return null),
                PrayerTimeInfo("asr",     parseIso(dayJson.optString("asr", "")) ?: return null),
                PrayerTimeInfo("maghrib", parseIso(dayJson.optString("maghrib", "")) ?: return null),
                PrayerTimeInfo("isha",    parseIso(dayJson.optString("isha", "")) ?: return null),
            )

            var current: String? = null
            for (p in prayers) {
                if (!now.before(p.time)) current = p.name
            }
            // If nothing has passed yet (before Fajr), treat as isha from the night before
            current ?: "isha"
        } catch (_: Exception) { null }
    }

    /**
     * Check if the prayer has changed and we need to auto-reset.
     * Uses a dedup key "prayerName_yyyyMMdd" to avoid resetting within the same prayer window.
     */
    private fun maybeAutoReset(context: Context): Boolean {
        val detected = detectCurrentPrayer(context) ?: return false
        val todayKey = calToKey(Calendar.getInstance())
        val resetKey = "${detected}_$todayKey"
        val storedPrayer = readPrayer(context)
        val lastReset = readLastReset(context)

        if (resetKey != lastReset || detected != storedPrayer) {
            // New prayer → auto-reset
            prefs(context).edit()
                .putString(KEY_AW_PRAYER, detected)
                .putString(KEY_AW_PHASE, "after_prayer")
                .putInt(KEY_AW_INDEX, 0)
                .putInt(KEY_AW_COUNT, 0)
                .putBoolean(KEY_AW_DHIKR_DONE, false)
                .putString(KEY_AW_PHASE_ANNOUNCE, "")
                .putString(KEY_AW_LAST_RESET, resetKey)
                .apply()
            return true
        }
        return false
    }

    // ── Tap / increment logic ───────────────────────────────────────────────

    private fun handleTap(context: Context) {
        val phase = readPhase(context)
        if (phase == "done") return

        // If we're showing a phase-change announcement, tap dismisses it and enters the new phase
        val announce = readPhaseAnnounce(context)
        if (announce.isNotEmpty()) {
            prefs(context).edit()
                .putString(KEY_AW_PHASE_ANNOUNCE, "")
                .apply()
            return  // refresh will show the new phase
        }

        // If a dhikr just completed (full ring shown), tap advances immediately
        if (readDhikrDone(context)) {
            // Cancel the pending auto-advance alarm (user tapped before it fired)
            cancelAutoAdvance(context)
            prefs(context).edit()
                .putBoolean(KEY_AW_DHIKR_DONE, false)
                .apply()
            advanceAfterDhikrComplete(context)
            return
        }

        val items = adhkarForPhase(phase)
        val index = readIndex(context).coerceIn(0, items.size - 1)
        val item = items[index]
        val newCount = readCount(context) + 1

        if (newCount >= item.target) {
            // Dhikr complete → show full ring
            val nextIndex = index + 1
            val hasNextInPhase = nextIndex < items.size

            prefs(context).edit()
                .putInt(KEY_AW_COUNT, newCount)
                .putBoolean(KEY_AW_DHIKR_DONE, true)
                .apply()

            if (hasNextInPhase) {
                // Still within same phase → light vibration + auto-advance after a short delay
                doTapVibrate(context)
                scheduleAutoAdvance(context)
            } else {
                // Last dhikr in phase → stronger vibration, user must tap for phase announcement
                doTransitionVibrate(context)
            }
        } else {
            prefs(context).edit()
                .putInt(KEY_AW_COUNT, newCount)
                .apply()
            doTapVibrate(context)
        }
    }

    /**
     * Called on the tap AFTER the full-ring completion screen was shown.
     * Advances index, or transitions phase, or marks done.
     */
    private fun advanceAfterDhikrComplete(context: Context) {
        val phase = readPhase(context)
        val items = adhkarForPhase(phase)
        val index = readIndex(context).coerceIn(0, items.size - 1)
        val nextIndex = index + 1

        if (nextIndex < items.size) {
            // Move to next dhikr in same phase
            prefs(context).edit()
                .putInt(KEY_AW_INDEX, nextIndex)
                .putInt(KEY_AW_COUNT, 0)
                .apply()
        } else {
            // Completed all adhkar in this phase
            val prayer = readPrayer(context)
            if (phase == "after_prayer") {
                val followUp = followUpPhase(prayer)
                if (followUp != null) {
                    // Show phase-change announcement screen first
                    val msg = phaseAnnounceMessage(followUp, prayer)
                    prefs(context).edit()
                        .putString(KEY_AW_PHASE, followUp)
                        .putInt(KEY_AW_INDEX, 0)
                        .putInt(KEY_AW_COUNT, 0)
                        .putString(KEY_AW_PHASE_ANNOUNCE, msg)
                        .apply()
                    doPhaseChangeVibrate(context)
                } else {
                    // No follow-up (Dhuhr) → done
                    prefs(context).edit()
                        .putString(KEY_AW_PHASE, "done")
                        .putInt(KEY_AW_INDEX, 0)
                        .putInt(KEY_AW_COUNT, 0)
                        .apply()
                    doCompletionVibrate(context)
                }
            } else {
                // Completed follow-up phase → done
                prefs(context).edit()
                    .putString(KEY_AW_PHASE, "done")
                    .putInt(KEY_AW_INDEX, 0)
                    .putInt(KEY_AW_COUNT, 0)
                    .apply()
                doCompletionVibrate(context)
            }
        }
    }

    private fun handleReset(context: Context) {
        val prayer = detectCurrentPrayer(context) ?: readPrayer(context)
        val todayKey = calToKey(Calendar.getInstance())
        prefs(context).edit()
            .putString(KEY_AW_PRAYER, prayer)
            .putString(KEY_AW_PHASE, "after_prayer")
            .putInt(KEY_AW_INDEX, 0)
            .putInt(KEY_AW_COUNT, 0)
            .putBoolean(KEY_AW_DHIKR_DONE, false)
            .putString(KEY_AW_PHASE_ANNOUNCE, "")
            .putString(KEY_AW_LAST_RESET, "${prayer}_$todayKey")
            .apply()
    }

    // ── Vibration patterns ──────────────────────────────────────────────────

    /** Light tap feedback */
    private fun doTapVibrate(context: Context) {
        vibrateMs(context, 15L, 60)
    }

    /** Stronger vibration when transitioning to next dhikr */
    private fun doTransitionVibrate(context: Context) {
        vibratePattern(context, longArrayOf(0, 120, 80, 120), intArrayOf(0, 220, 0, 220))
    }

    /** Extra strong vibration when transitioning to new phase (morning/evening/sleep) */
    private fun doPhaseChangeVibrate(context: Context) {
        vibratePattern(context, longArrayOf(0, 200, 100, 200, 100, 200), intArrayOf(0, 255, 0, 255, 0, 255))
    }

    /** Completion vibration */
    private fun doCompletionVibrate(context: Context) {
        vibratePattern(context, longArrayOf(0, 150, 90, 150, 90, 300), intArrayOf(0, 200, 0, 200, 0, 255))
    }

    private fun vibrateMs(context: Context, ms: Long, amplitude: Int) {
        try {
            val appCtx = context.applicationContext
            val effect = android.os.VibrationEffect.createOneShot(ms, amplitude)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vm = appCtx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                        as? android.os.VibratorManager
                val attrs = android.os.VibrationAttributes.createForUsage(
                    android.os.VibrationAttributes.USAGE_NOTIFICATION
                )
                vm?.vibrate(android.os.CombinedVibration.createParallel(effect), attrs)
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                val vib = appCtx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                val attrs = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                vib?.vibrate(effect, attrs)
            } else {
                @Suppress("DEPRECATION")
                val vib = appCtx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                @Suppress("DEPRECATION")
                vib?.vibrate(ms)
            }
        } catch (_: Exception) {}
    }

    private fun vibratePattern(context: Context, timings: LongArray, amplitudes: IntArray) {
        try {
            val appCtx = context.applicationContext
            val effect = android.os.VibrationEffect.createWaveform(timings, amplitudes, -1)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vm = appCtx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                        as? android.os.VibratorManager
                val attrs = android.os.VibrationAttributes.createForUsage(
                    android.os.VibrationAttributes.USAGE_NOTIFICATION
                )
                vm?.vibrate(android.os.CombinedVibration.createParallel(effect), attrs)
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                val vib = appCtx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                val attrs = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                vib?.vibrate(effect, attrs)
            } else {
                @Suppress("DEPRECATION")
                val vib = appCtx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                @Suppress("DEPRECATION")
                vib?.vibrate(timings, -1)
            }
        } catch (_: Exception) {}
    }

    // ── Widget rendering ────────────────────────────────────────────────────

    private fun refreshWidgets(context: Context) {
        try {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, receiverClass))
            if (ids.isNotEmpty()) onUpdate(context, manager, ids)
        } catch (_: Exception) {}
    }

    private fun safeUpdateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        try {
            // Auto-reset if prayer has changed
            maybeAutoReset(context)

            val views = RemoteViews(context.packageName, layoutResId)
            val prayer = readPrayer(context)
            val phase  = readPhase(context)
            val count  = readCount(context)
            val index  = readIndex(context)
            val dhikrDone = readDhikrDone(context)
            val phaseAnnounce = readPhaseAnnounce(context)

            val items = adhkarForPhase(phase)
            val isDone = phase == "done"
            val density = context.resources.displayMetrics.density
            val bmpSize = (130 * density).roundToInt()

            // ── Single unified header ──
            views.setTextViewText(R.id.adhkar_phase_title, unifiedHeader(prayer, phase))
            // Hide the right-side label (was causing duplicate info) — use it for brief subtitle
            views.setTextViewText(R.id.adhkar_prayer_name, "")

            when {
                // ── State 1: Phase-change announcement ──────────────────────
                phaseAnnounce.isNotEmpty() -> {
                    views.setTextViewText(R.id.adhkar_count, "")
                    views.setTextViewText(R.id.adhkar_target, "")
                    views.setTextViewText(R.id.adhkar_dhikr_text, phaseAnnounce)
                    views.setTextViewText(R.id.adhkar_progress, "اضغط للمتابعة")
                    views.setViewVisibility(R.id.adhkar_done_label, View.GONE)
                    views.setViewVisibility(R.id.adhkar_tap_hint, View.GONE)
                    // Full ring to show completion of previous phase
                    val bmp = drawBeadRingBitmap(bmpSize, BEAD_COUNT, true, beadColor)
                    views.setImageViewBitmap(R.id.adhkar_bead_ring, bmp)
                }

                // ── State 2: All done ────────────────────────────────────────
                isDone -> {
                    views.setTextViewText(R.id.adhkar_count, "✓")
                    views.setTextViewText(R.id.adhkar_target, "")
                    views.setTextViewText(R.id.adhkar_dhikr_text, "بارك الله فيك وتقبل الله منك")
                    views.setTextViewText(R.id.adhkar_progress, "")
                    views.setViewVisibility(R.id.adhkar_done_label, View.VISIBLE)
                    views.setViewVisibility(R.id.adhkar_tap_hint, View.GONE)
                    val bmp = drawBeadRingBitmap(bmpSize, BEAD_COUNT, true, beadColor)
                    views.setImageViewBitmap(R.id.adhkar_bead_ring, bmp)
                }

                // ── State 3: Dhikr just completed — show full ring ───────────
                dhikrDone -> {
                    val safeIndex = index.coerceIn(0, items.size - 1)
                    val item = items[safeIndex]
                    views.setTextViewText(R.id.adhkar_count, toArabicNumerals("${item.target}"))
                    views.setTextViewText(R.id.adhkar_target, "✓ اكتمل")
                    views.setTextViewText(R.id.adhkar_dhikr_text, item.shortText)
                    views.setTextViewText(R.id.adhkar_progress,
                        "${toArabicNumerals("${safeIndex + 1}")} / ${toArabicNumerals("${items.size}")}")
                    views.setViewVisibility(R.id.adhkar_done_label, View.GONE)
                    views.setViewVisibility(R.id.adhkar_tap_hint, View.VISIBLE)
                    // Full ring
                    val bmp = drawBeadRingBitmap(bmpSize, BEAD_COUNT, false, beadColor)
                    views.setImageViewBitmap(R.id.adhkar_bead_ring, bmp)
                }

                // ── State 4: Normal counting ─────────────────────────────────
                else -> {
                    val safeIndex = index.coerceIn(0, items.size - 1)
                    val item = items[safeIndex]
                    val target = item.target

                    views.setTextViewText(R.id.adhkar_count, toArabicNumerals("$count"))
                    views.setTextViewText(R.id.adhkar_target, "من ${toArabicNumerals("$target")}")
                    views.setTextViewText(R.id.adhkar_dhikr_text, item.shortText)
                    views.setTextViewText(R.id.adhkar_progress,
                        "${toArabicNumerals("${safeIndex + 1}")} / ${toArabicNumerals("${items.size}")}")
                    views.setViewVisibility(R.id.adhkar_done_label, View.GONE)
                    views.setViewVisibility(R.id.adhkar_tap_hint,
                        if (count == 0) View.VISIBLE else View.GONE)

                    val filledBeads = if (target > 0)
                        (count.toDouble() / target * BEAD_COUNT).roundToInt().coerceIn(0, BEAD_COUNT)
                    else 0
                    val bmp = drawBeadRingBitmap(bmpSize, filledBeads, false, beadColor)
                    views.setImageViewBitmap(R.id.adhkar_bead_ring, bmp)
                }
            }

            // ── Click intents ──
            attachClickIntent(context, views, R.id.adhkar_tap_area, ACTION_ADHKAR_TAP, requestCode)
            attachClickIntent(context, views, R.id.adhkar_reset_btn, ACTION_ADHKAR_RESET, requestCode + 100)

            manager.updateAppWidget(widgetId, views)
        } catch (_: Exception) {}
    }

    private fun attachClickIntent(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        action: String,
        reqCode: Int,
    ) {
        val intent = Intent(context, receiverClass).apply { this.action = action }
        val pi = PendingIntent.getBroadcast(
            context, reqCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(viewId, pi)
    }

    // ── Bead ring drawing (same technique as TasbeehWidget) ─────────────────

    private fun drawBeadRingBitmap(
        sizePx: Int,
        filledCount: Int,
        isDone: Boolean,
        roundBeadColor: Int,
    ): Bitmap {
        val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = sizePx / 2f
        val cy = sizePx / 2f
        val ringR = sizePx / 2f - sizePx * 0.062f
        val beadR = (sizePx / 34f).coerceIn(sizePx * 0.038f, sizePx * 0.073f)
        val dividerR = beadR * 1.38f
        val anglePerBead = (2.0 * PI / BEAD_COUNT).toFloat()

        // Cord circle
        val cordPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = sizePx * 0.012f
            color = if (isDone) setAlpha(0xFFC9A227.toInt(), 115)
                    else setAlpha(roundBeadColor, cordAlpha)
        }
        canvas.drawCircle(cx, cy, ringR, cordPaint)

        // Beads
        for (i in 0 until BEAD_COUNT) {
            val angle = (-PI / 2 + i * anglePerBead).toFloat()
            val bx = cx + ringR * cos(angle)
            val by = cy + ringR * sin(angle)
            val r = if (i == 0) dividerR else beadR
            val isFilled = i < filledCount

            if (isFilled || isDone) {
                val baseColor = if (isDone) 0xFFC9A227.toInt() else roundBeadColor
                val lightColor = blendColor(baseColor, 0xFFFFFFFF.toInt(), 0.42f)
                val darkColor = blendColor(baseColor, 0xFF000000.toInt(), 0.42f)

                // Shadow
                val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = setAlpha(0xFF000000.toInt(), 51)
                    maskFilter = android.graphics.BlurMaskFilter(
                        sizePx * 0.019f, android.graphics.BlurMaskFilter.Blur.NORMAL
                    )
                }
                canvas.drawCircle(bx, by + r * 0.28f, r * 0.82f, shadowPaint)

                // Sphere gradient
                val gradientPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = RadialGradient(
                        bx - r * 0.38f, by - r * 0.38f, r * 1.96f,
                        intArrayOf(lightColor, baseColor, darkColor),
                        floatArrayOf(0f, 0.48f, 1f),
                        Shader.TileMode.CLAMP
                    )
                }
                canvas.drawCircle(bx, by, r, gradientPaint)

                // Specular highlight
                val specPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = setAlpha(0xFFFFFFFF.toInt(), 153)
                }
                canvas.drawOval(
                    bx - r * 0.61f, by - r * 0.61f,
                    bx - r * 0.61f + r * 0.70f, by - r * 0.61f + r * 0.50f,
                    specPaint
                )

                // Divider rim
                if (i == 0) {
                    val rimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        strokeWidth = sizePx * 0.009f
                        color = setAlpha(0xFFFFFFFF.toInt(), 102)
                    }
                    canvas.drawCircle(bx, by, r, rimPaint)
                }
            } else {
                // Empty bead
                val emptyFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = setAlpha(roundBeadColor, 25)
                    style = Paint.Style.FILL
                }
                canvas.drawCircle(bx, by, r, emptyFill)

                val emptyStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = setAlpha(roundBeadColor, 40)
                    style = Paint.Style.STROKE
                    strokeWidth = sizePx * 0.008f
                }
                canvas.drawCircle(bx, by, r, emptyStroke)
            }
        }
        return bmp
    }

    // ── Utility ─────────────────────────────────────────────────────────────

    private fun setAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha shl 24)

    private fun blendColor(base: Int, blend: Int, ratio: Float): Int {
        val inv = 1f - ratio
        val r = (Color.red(base) * inv + Color.red(blend) * ratio).roundToInt().coerceIn(0, 255)
        val g = (Color.green(base) * inv + Color.green(blend) * ratio).roundToInt().coerceIn(0, 255)
        val b = (Color.blue(base) * inv + Color.blue(blend) * ratio).roundToInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    private fun toArabicNumerals(s: String): String = s.map {
        when (it) {
            '0' -> '٠'; '1' -> '١'; '2' -> '٢'; '3' -> '٣'; '4' -> '٤'
            '5' -> '٥'; '6' -> '٦'; '7' -> '٧'; '8' -> '٨'; '9' -> '٩'
            else -> it
        }
    }.joinToString("")

    private fun calToKey(cal: Calendar): String = String.format(
        Locale.ENGLISH, "%04d-%02d-%02d",
        cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
    )

    private fun parseIso(iso: String): Date? {
        if (iso.isBlank()) return null
        return try {
            val isUtc = iso.endsWith("Z", ignoreCase = true)
            val base = iso.trim()
                .let { if ('.' in it) it.substringBefore('.') else it }
                .trimEnd('Z', 'z')
            val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ENGLISH).apply {
                timeZone = if (isUtc) TimeZone.getTimeZone("UTC") else TimeZone.getDefault()
            }
            fmt.parse(base)
        } catch (_: Exception) { null }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Concrete widget variants
// ═══════════════════════════════════════════════════════════════════════════════

class AdhkarWidget : BaseAdhkarWidget() {
    override val layoutResId    = R.layout.adhkar_widget
    override val receiverClass  = AdhkarWidget::class.java
    override val requestCode    = 7880
    override val beadColor      = 0xFFC9A227.toInt()   // gold
    override val cordAlpha      = 64
    override val accentColor    = 0xFFF0C040.toInt()
}

class AdhkarWidgetDark : BaseAdhkarWidget() {
    override val layoutResId    = R.layout.adhkar_widget_dark
    override val receiverClass  = AdhkarWidgetDark::class.java
    override val requestCode    = 7881
    override val beadColor      = 0xFF7AD5B0.toInt()   // teal
    override val cordAlpha      = 64
    override val accentColor    = 0xFF7AD5B0.toInt()
}

class AdhkarWidgetLight : BaseAdhkarWidget() {
    override val layoutResId    = R.layout.adhkar_widget_light
    override val receiverClass  = AdhkarWidgetLight::class.java
    override val requestCode    = 7882
    override val beadColor      = 0xFF0D5E3A.toInt()   // green
    override val cordAlpha      = 64
    override val accentColor    = 0xFF0D5E3A.toInt()
}
