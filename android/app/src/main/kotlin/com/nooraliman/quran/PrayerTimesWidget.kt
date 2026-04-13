package com.nooraliman.quran

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.location.Geocoder
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

private const val PREFS_NAME = "FlutterSharedPreferences"
private const val KEY_CACHED_CONTENT = "flutter.cached_prayer_times"
private const val ACTION_UPDATE_WIDGET = "com.nooraliman.quran.PRAYER_WIDGET_UPDATE"
private const val ACTION_ADHAN_STARTED = "com.nooraliman.quran.ADHAN_STARTED"
private const val UPDATE_INTERVAL_MS = 1 * 60 * 1000L  // 1 minute instead of 15 minutes

object PrayerWidgetUpdateDispatcher {
    fun refreshAll(context: Context) {
        val providers = listOf(
            PrayerTimesWidget::class.java,
            PrayerTimesWidgetDark::class.java,
            PrayerTimesWidgetLight::class.java,
        )
        providers.forEach { provider ->
            try {
                val intent = Intent(context, provider).apply { action = ACTION_UPDATE_WIDGET }
                context.sendBroadcast(intent)
            } catch (_: Exception) {
            }
        }
    }
}

abstract class BasePrayerTimesWidget : AppWidgetProvider() {
    protected abstract val layoutResId: Int
    protected abstract val receiverClass: Class<out AppWidgetProvider>
    protected abstract val requestCode: Int
    protected abstract val defaultTimeColor: Int
    protected abstract val currentTimeColor: Int
    protected abstract val nextTimeColor: Int
    protected abstract val currentHighlightDrawable: Int
    protected abstract val currentBadgeDrawable: Int
    protected abstract val nextCircleDrawable: Int

    // ─── AppWidgetProvider overrides ─────────────────────────────────────────

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        try {
            appWidgetIds.forEach { widgetId ->
                safeUpdateWidget(context, appWidgetManager, widgetId)
            }
        } catch (_: Exception) {
        }
        scheduleNextUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (_: Exception) {
        }
        try {
            when (intent.action) {
                ACTION_UPDATE_WIDGET,
                ACTION_ADHAN_STARTED,
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_USER_PRESENT,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                "android.intent.action.QUICKBOOT_POWERON",
                "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                    val manager = AppWidgetManager.getInstance(context)
                    val ids = manager.getAppWidgetIds(ComponentName(context, receiverClass))
                    if (ids.isNotEmpty()) {
                        onUpdate(context, manager, ids)
                    }
                }
            }
        } catch (_: Exception) {
        }
    }

    override fun onEnabled(context: Context) {
        try {
            super.onEnabled(context)
        } catch (_: Exception) {
        }
        scheduleNextUpdate(context)
    }

    override fun onDisabled(context: Context) {
        try {
            super.onDisabled(context)
        } catch (_: Exception) {
        }
        cancelScheduledUpdate(context)
    }

    // ─── AlarmManager ────────────────────────────────────────────────────────

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, receiverClass).apply { action = ACTION_UPDATE_WIDGET }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleNextUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = buildPendingIntent(context)
            val triggerAt = System.currentTimeMillis() + UPDATE_INTERVAL_MS
            try {
                alarmManager.setExact(AlarmManager.RTC, triggerAt, pendingIntent)
            } catch (_: SecurityException) {
                alarmManager.set(AlarmManager.RTC, triggerAt, pendingIntent)
            }
        } catch (_: Exception) {
        }
    }

    private fun cancelScheduledUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(buildPendingIntent(context))
        } catch (_: Exception) {
        }
    }

    // ─── Widget rendering ─────────────────────────────────────────────────────

    private fun safeUpdateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        try {
            val views = RemoteViews(context.packageName, layoutResId)
            attachLaunchIntent(context, views)
            val bundle = loadPrayerBundle(context)
            bindHeader(context, views, bundle?.locationName)
            if (bundle != null) {
                renderPrayerData(views, bundle, Date())
            } else {
                renderNoData(views)
            }
            manager.updateAppWidget(widgetId, views)
        } catch (_: Exception) {
            try {
                val fallback = RemoteViews(context.packageName, layoutResId)
                renderNoData(fallback)
                manager.updateAppWidget(widgetId, fallback)
            } catch (_: Exception) {
            }
        }
    }

    private fun attachLaunchIntent(context: Context, views: RemoteViews) {
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    requestCode,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
        } catch (_: Exception) {
        }
    }

    private fun bindHeader(context: Context, views: RemoteViews, locationName: String?) {
        val now = Date()
        val arabicFormatter = SimpleDateFormat("EEEE، d MMMM yyyy", Locale("ar"))
        views.setTextViewText(R.id.widget_date, toArabicNumerals(arabicFormatter.format(now)))
        views.setTextViewText(R.id.widget_hijri_date, formatHijriDate(context, now))
        views.setTextViewText(R.id.widget_location, locationName ?: "الموقع المحفوظ")
    }

    private fun renderPrayerData(views: RemoteViews, bundle: PrayerBundle, now: Date) {
        views.setTextViewText(R.id.fajr_time, formatTime(bundle.today.fajr))
        views.setTextViewText(R.id.dhuhr_time, formatTime(bundle.today.dhuhr))
        views.setTextViewText(R.id.asr_time, formatTime(bundle.today.asr))
        views.setTextViewText(R.id.maghrib_time, formatTime(bundle.today.maghrib))
        views.setTextViewText(R.id.isha_time, formatTime(bundle.today.isha))

        val state = determinePrayerState(bundle.today, now)

        val currentName = state.currentName
        val currentTime = state.currentTime
        val nextName: String?
        val nextTime: Date?
        val isTomorrow: Boolean

        when {
            state.nextTime != null -> {
                nextName = state.nextName
                nextTime = state.nextTime
                isTomorrow = false
            }
            bundle.tomorrow != null -> {
                nextName = "الفجر"
                nextTime = bundle.tomorrow.fajr
                isTomorrow = true
            }
            else -> {
                nextName = null
                nextTime = null
                isTomorrow = false
            }
        }

        // Card always shows next prayer
        val cardName: String? = nextName
        val cardTime: Date? = nextTime
        val cardLabel: String = if (isTomorrow) "القادمة غدًا" else "الصلاة القادمة"

        views.setTextViewText(R.id.label_next_prayer, cardLabel)
        views.setTextViewText(R.id.next_prayer_name, cardName ?: "—")
        views.setTextViewText(R.id.next_prayer_time, cardTime?.let(::formatTime) ?: "—")
        views.setTextViewText(
            R.id.next_prayer_countdown,
            when {
                nextTime != null -> formatCountdown(nextTime.time - now.time)
                else -> "—"
            },
        )

        clearColumnHighlights(views)
        highlightCurrent(views, currentName)
        accentNext(views, nextName, currentName)
    }

    private fun renderNoData(views: RemoteViews) {
        views.setTextViewText(R.id.label_next_prayer, "الصلاة القادمة")
        views.setTextViewText(R.id.next_prayer_name, "—")
        views.setTextViewText(R.id.next_prayer_time, "—")
        views.setTextViewText(R.id.next_prayer_countdown, "—")
        for (id in listOf(R.id.fajr_time, R.id.dhuhr_time,
                          R.id.asr_time, R.id.maghrib_time, R.id.isha_time)) {
            views.setTextViewText(id, "—")
        }
        clearColumnHighlights(views)
    }

    // ─── Column highlight helpers ─────────────────────────────────────────────

    /**
     * Reset all five prayer columns to a transparent background and their default text color.
     */
    private fun clearColumnHighlights(views: RemoteViews) {
        val colIds  = listOf(R.id.fajr_col, R.id.dhuhr_col, R.id.asr_col,
                             R.id.maghrib_col, R.id.isha_col)
        val timeIds = listOf(R.id.fajr_time, R.id.dhuhr_time, R.id.asr_time,
                             R.id.maghrib_time, R.id.isha_time)
        val badgeIds = listOf(R.id.fajr_badge, R.id.dhuhr_badge, R.id.asr_badge,
                              R.id.maghrib_badge, R.id.isha_badge)
        for (col  in colIds)  views.setInt(col,  "setBackgroundResource", 0)
        for (time in timeIds) views.setTextColor(time, defaultTimeColor)
        for (badge in badgeIds) views.setViewVisibility(badge, android.view.View.GONE)
    }

    private fun highlightCurrent(views: RemoteViews, name: String?) {
        val time = timeIdFor(name) ?: return
        views.setTextColor(time, currentTimeColor)
    }

    private fun accentNext(views: RemoteViews, next: String?, current: String?) {
        if (next == null || next == current) return
        val col  = colIdFor(next) ?: return
        val time = timeIdFor(next) ?: return
        views.setInt(col, "setBackgroundResource", currentHighlightDrawable)
        views.setTextColor(time, nextTimeColor)
    }

    private fun colIdFor(name: String?): Int? = when (name) {
        "الفجر"  -> R.id.fajr_col
        "الظهر"  -> R.id.dhuhr_col
        "العصر"  -> R.id.asr_col
        "المغرب" -> R.id.maghrib_col
        "العشاء" -> R.id.isha_col
        else     -> null
    }

    private fun timeIdFor(name: String?): Int? = when (name) {
        "الفجر"  -> R.id.fajr_time
        "الظهر"  -> R.id.dhuhr_time
        "العصر"  -> R.id.asr_time
        "المغرب" -> R.id.maghrib_time
        "العشاء" -> R.id.isha_time
        else     -> null
    }

    private fun badgeIdFor(name: String?): Int? = when (name) {
        "الفجر" -> R.id.fajr_badge
        "الظهر" -> R.id.dhuhr_badge
        "العصر" -> R.id.asr_badge
        "المغرب" -> R.id.maghrib_badge
        "العشاء" -> R.id.isha_badge
        else -> null
    }

    // ─── Prayer state logic ───────────────────────────────────────────────────

    private data class PrayerState(
        val currentName: String?,
        val currentTime: Date?,
        val nextName: String?,
        val nextTime: Date?,
    )

    /**
     * Determine which prayer is currently active and which one comes next.
     *
     * Walk the prayers in chronological order; the last one whose start time
     * has already passed is "current".  The one immediately after is "next".
     * Sunrise is excluded from the named-prayer sequence intentionally.
     */
    private fun determinePrayerState(data: PrayerData, now: Date): PrayerState {
        val prayers = listOf(
            "الفجر"  to data.fajr,
            "الظهر"  to data.dhuhr,
            "العصر"  to data.asr,
            "المغرب" to data.maghrib,
            "العشاء" to data.isha,
        )
        var currentIdx = -1
        for (i in prayers.indices) {
            if (!now.before(prayers[i].second)) currentIdx = i
        }
        val current = if (currentIdx >= 0) prayers[currentIdx] else null
        val next    = if (currentIdx + 1 < prayers.size) prayers[currentIdx + 1] else null
        return PrayerState(current?.first, current?.second, next?.first, next?.second)
    }

    // ─── SharedPreferences / data loading ────────────────────────────────────

    private data class PrayerData(
        val fajr: Date,
        val sunrise: Date,
        val dhuhr: Date,
        val asr: Date,
        val maghrib: Date,
        val isha: Date,
    )

    private data class PrayerBundle(
        val today: PrayerData,
        val tomorrow: PrayerData?,
        val locationName: String?,
    )

    /**
     * Parse today's prayer times from Flutter's cached JSON.
     *
     * Reads from "FlutterSharedPreferences" (the file Flutter's
     * shared_preferences plugin uses on Android) under the key
     * "flutter.cached_prayer_times".  Returns null if any step fails.
     *
     * Fallback key resolution:
     *   1. Try today's date key  (YYYY-MM-DD)
     *   2. Try yesterday's date key  (handles midnight edge-case)
     */
    private fun loadPrayerBundle(context: Context): PrayerBundle? {
        return try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_CACHED_CONTENT, null) ?: return null

            val root = JSONObject(raw)
            val cachedAt = parseIso(root.optString("cachedAt", "")) ?: return null

            if ((System.currentTimeMillis() - cachedAt.time) / 86_400_000L > 8) return null

            val times = root.optJSONObject("times") ?: return null
            val todayCal = Calendar.getInstance()
            val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            val yesterdayCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }

            val todayJson = times.optJSONObject(calToKey(todayCal))
                ?: times.optJSONObject(calToKey(yesterdayCal))
                ?: return null

            PrayerBundle(
                today = parsePrayerData(todayJson) ?: return null,
                tomorrow = times.optJSONObject(calToKey(tomorrowCal))?.let(::parsePrayerData),
                locationName = resolveLocationName(context, prefs, root),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveLocationName(
        context: Context,
        prefs: android.content.SharedPreferences,
        root: JSONObject,
    ): String? {
        val directCandidates = listOf(
            root.optString("locationName", ""),
            root.optString("location", ""),
            root.optString("city", ""),
            root.optString("area", ""),
            root.optString("address", ""),
            prefs.getString("flutter.location_name", "") ?: "",
            prefs.getString("flutter.last_place_name", "") ?: "",
            prefs.getString("flutter.place_name", "") ?: "",
            prefs.getString("flutter.cached_location_name", "") ?: "",
        )
        val direct = directCandidates
            .map { it.trim() }
            .firstOrNull { it.isNotEmpty() }
        if (direct != null) return direct

        val cachedLat = readNullableDouble(root, "latitude")
            ?: readNullableDoubleFromPrefs(prefs, "flutter.last_known_lat")
        val cachedLng = readNullableDouble(root, "longitude")
            ?: readNullableDoubleFromPrefs(prefs, "flutter.last_known_lng")

        if (cachedLat != null && cachedLng != null) {
            reverseGeocodePlaceName(context, cachedLat, cachedLng)?.let { return it }
            return "الموقع المحفوظ"
        }

        return null
    }

    private fun readNullableDouble(root: JSONObject, key: String): Double? {
        if (!root.has(key)) return null
        val value = root.optDouble(key, Double.NaN)
        return if (value.isNaN()) null else value
    }

    private fun readNullableDoubleFromPrefs(
        prefs: android.content.SharedPreferences,
        key: String,
    ): Double? {
        if (!prefs.contains(key)) return null
        val raw = prefs.all[key] ?: return null
        return when (raw) {
            is Double -> raw
            is Float -> raw.toDouble()
            is Int -> raw.toDouble()
            is Long -> raw.toDouble()
            is String -> parseFlutterDoubleString(raw)
            else -> null
        }
    }

    private fun parseFlutterDoubleString(raw: String): Double? {
        raw.toDoubleOrNull()?.let { return it }

        val knownPrefixes = listOf(
            "This is the prefix for a double.",
            "This is the prefix for Double.",
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGRvdWJsZS4",
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu",
        )

        for (prefix in knownPrefixes) {
            if (raw.startsWith(prefix)) {
                val suffix = raw.removePrefix(prefix).trim()
                val cleaned = suffix
                    .removePrefix("u")
                    .removePrefix("U")
                    .trim()
                cleaned.toDoubleOrNull()?.let { return it }
            }
        }
        return null
    }

    private fun reverseGeocodePlaceName(context: Context, lat: Double, lng: Double): String? {
        return try {
            if (!Geocoder.isPresent()) return null
            val geocoder = Geocoder(context, Locale("ar"))
            @Suppress("DEPRECATION")
            val results = geocoder.getFromLocation(lat, lng, 1)
            val address = results?.firstOrNull() ?: return null
            val city = listOf(
                address.locality,
                address.subAdminArea,
                address.adminArea,
            ).firstOrNull { !it.isNullOrBlank() }?.trim()
            val country = address.countryName?.trim()
            when {
                !city.isNullOrBlank() && !country.isNullOrBlank() -> "$city، $country"
                !city.isNullOrBlank() -> city
                !country.isNullOrBlank() -> country
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun parsePrayerData(day: JSONObject): PrayerData? {
        return try {
            PrayerData(
                fajr = parseIso(day.optString("fajr", "")) ?: return null,
                sunrise = parseIso(day.optString("sunrise", "")) ?: return null,
                dhuhr = parseIso(day.optString("dhuhr", "")) ?: return null,
                asr = parseIso(day.optString("asr", "")) ?: return null,
                maghrib = parseIso(day.optString("maghrib", "")) ?: return null,
                isha = parseIso(day.optString("isha", "")) ?: return null,
            )
        } catch (_: Exception) {
            null
        }
    }

    // ─── Formatting helpers ───────────────────────────────────────────────────

    /** Build "YYYY-MM-DD" key from a Calendar — pure function, no side-effects. */
    private fun calToKey(cal: Calendar): String = String.format(
        Locale.ENGLISH,
        "%04d-%02d-%02d",
        cal.get(Calendar.YEAR),
        cal.get(Calendar.MONTH) + 1,
        cal.get(Calendar.DAY_OF_MONTH),
    )

    /**
     * Parse a Dart DateTime.toIso8601String() value.
     *
     * Dart produces strings like:
     *   "2026-03-12T04:36:00.000"     (local, milliseconds)
     *   "2026-03-12T04:36:00.000000"  (local, microseconds)
     *   "2026-03-12T04:36:00.000Z"    (UTC — rare for prayer times)
     *
     * Strategy: strip fractional seconds, detect Z suffix for UTC vs local.
     */
    private fun parseIso(iso: String): Date? {
        if (iso.isBlank()) return null
        return try {
            val isUtc = iso.endsWith("Z", ignoreCase = true)
            val base = iso.trim()
                .let { if ('.' in it) it.substringBefore('.') else it }
                .trimEnd('Z', 'z')
            val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ENGLISH).apply {
                timeZone = if (isUtc) TimeZone.getTimeZone("UTC")
                           else       TimeZone.getDefault()
            }
            fmt.parse(base)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Convert Western Arabic digits (0-9) to Eastern Arabic digits (٠-٩).
     */
    private fun toArabicNumerals(s: String): String {
        return s.map {
            when (it) {
                '0' -> '٠'; '1' -> '١'; '2' -> '٢'; '3' -> '٣'; '4' -> '٤'
                '5' -> '٥'; '6' -> '٦'; '7' -> '٧'; '8' -> '٨'; '9' -> '٩'
                else -> it
            }
        }.joinToString("")
    }

    /**
     * Format a Date as "hh:mm ص/م" using a 12-hour Arabic clock.
     * Example: ٠٤:٣٦ ص  |  ٠٥:٥١ م
     */
    private fun formatTime(date: Date): String {
        val cal = Calendar.getInstance().apply { time = date }
        val hour = cal.get(Calendar.HOUR).let { if (it == 0) 12 else it }
        val minute = cal.get(Calendar.MINUTE)
        val amPm = if (cal.get(Calendar.AM_PM) == Calendar.AM) "ص" else "م"
        return toArabicNumerals(String.format(Locale.ENGLISH, "%02d:%02d %s", hour, minute, amPm))
    }

    /**
     * Format a millisecond duration as "Xس YYد" or "Yد".
     * Clamps negative values to zero.
     */
    private fun formatCountdown(millis: Long): String {
        val totalMin = millis.coerceAtLeast(0L) / 60_000L
        val h = totalMin / 60
        val m = totalMin % 60
        return if (h > 0) {
            toArabicNumerals(String.format(Locale.ENGLISH, "%dس %02dد", h, m))
        } else {
            toArabicNumerals(String.format(Locale.ENGLISH, "%dد", m))
        }
    }

    private fun formatHijriDate(context: Context, date: Date): String {
        val countryCode = resolveCountryCode(context)

        tryFormatHijriWithDeviceLocale(countryCode, date)?.let { return it }

        val cal = Calendar.getInstance().apply {
            time = date
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val jd = gregorianToJulianDay(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
            ) + regionalHijriOffsetDays(context, countryCode)
        val hijri = islamicFromJulianDay(jd)
        val months = arrayOf(
            "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
            "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
        )
        return "${toArabicNumerals(hijri.day.toString())} ${months[hijri.month - 1]} ${toArabicNumerals(hijri.year.toString())} هـ"
    }

    private fun resolveCountryCode(context: Context): String {
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale
        }
        return locale.country.uppercase(Locale.ENGLISH)
    }

    private fun tryFormatHijriWithDeviceLocale(countryCode: String, date: Date): String? {
        val localeTag = when (countryCode) {
            "EG" -> "ar-EG-u-ca-islamic"
            "SA", "AE", "QA", "KW", "BH", "OM", "YE" -> "ar-SA-u-ca-islamic-umalqura"
            "MA", "DZ", "TN", "LY" -> "ar-MA-u-ca-islamic-civil"
            "JO", "PS", "SY", "LB", "IQ" -> "ar-EG-u-ca-islamic"
            else -> "ar-u-ca-islamic"
        }

        return try {
            val locale = Locale.forLanguageTag(localeTag)
            val formatter = SimpleDateFormat("d MMMM yyyy", locale)
            val value = formatter.format(date)
            if (looksGregorianMonth(value)) null else toArabicNumerals("$value هـ")
        } catch (_: Exception) {
            null
        }
    }

    private fun looksGregorianMonth(value: String): Boolean {
        val gregorianMonths = arrayOf(
            "يناير", "فبراير", "مارس", "أبريل", "ابريل", "مايو", "يونيو",
            "يوليو", "أغسطس", "اغسطس", "سبتمبر", "أكتوبر", "اكتوبر", "نوفمبر", "ديسمبر",
        )
        return gregorianMonths.any { value.contains(it) }
    }

    private fun regionalHijriOffsetDays(context: Context, countryCode: String): Int {
        return when (countryCode) {
            // Gulf countries — Umm al-Qura often runs a day ahead of naked-eye sighting elsewhere.
            "SA", "AE", "QA", "KW", "BH", "OM", "YE" -> 1
            // Maghreb — local ruya sighting tends to be a day behind the tabular calculation.
            "MA", "DZ", "TN", "LY" -> -1
            else -> 0
        }
    }

    private fun isEgyptLocale(context: Context): Boolean {
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale
        }
        val localeStr = locale.toString().uppercase(Locale.ENGLISH)
        return localeStr.contains("EG") || localeStr.startsWith("AR_EG")
    }

    private fun isEgyptTimezone(): Boolean {
        val timezoneId = TimeZone.getDefault().id.uppercase(Locale.ENGLISH)
        return timezoneId.contains("CAIRO") || timezoneId == "AFRICA/CAIRO"
    }

    private fun gregorianToJulianDay(year: Int, month: Int, day: Int): Int {
        val a = (14 - month) / 12
        val y = year + 4800 - a
        val m = month + 12 * a - 3
        return day + ((153 * m + 2) / 5) + 365 * y + (y / 4) - (y / 100) + (y / 400) - 32045
    }

    private data class HijriDate(val year: Int, val month: Int, val day: Int)

    private fun islamicFromJulianDay(julianDay: Int): HijriDate {
        val l0 = julianDay - 1948440 + 10632
        val n = (l0 - 1) / 10631
        var l = l0 - 10631 * n + 354
        val j1 = ((10985 - l) / 5316)
        val j2 = ((50 * l) / 17719)
        val j3 = (l / 5670)
        val j4 = ((43 * l) / 15238)
        val j = j1 * j2 + j3 * j4
        l = l - ((30 - j) / 15) * ((17719 * j) / 50) - (j / 16) * ((15238 * j) / 43) + 29
        val month = (24 * l) / 709
        val day = l - (709 * month) / 24
        val year = 30 * n + j - 30
        return HijriDate(year, month, day)
    }
}

class PrayerTimesWidget : BasePrayerTimesWidget() {
    companion object {
        fun triggerImmediateUpdate(context: Context) {
            PrayerWidgetUpdateDispatcher.refreshAll(context)
        }
    }

    override val layoutResId = R.layout.prayer_widget
    override val receiverClass = PrayerTimesWidget::class.java
    override val requestCode = 7867
    override val defaultTimeColor = 0xFFFDFBF6.toInt()
    override val currentTimeColor = 0xFF2C2416.toInt()
    override val nextTimeColor = 0xFFE8D79A.toInt()
    override val currentHighlightDrawable = R.drawable.widget_current_highlight_balanced
    override val currentBadgeDrawable = R.drawable.widget_badge_balanced
    override val nextCircleDrawable = R.drawable.widget_next_circle_balanced
}

class PrayerTimesWidgetDark : BasePrayerTimesWidget() {
    override val layoutResId = R.layout.prayer_widget_dark
    override val receiverClass = PrayerTimesWidgetDark::class.java
    override val requestCode = 7868
    override val defaultTimeColor = 0xFFE9EEF2.toInt()
    override val currentTimeColor = 0xFFF7E7B0.toInt()
    override val nextTimeColor = 0xFF9FD5C0.toInt()
    override val currentHighlightDrawable = R.drawable.widget_current_highlight_dark
    override val currentBadgeDrawable = R.drawable.widget_badge_dark
    override val nextCircleDrawable = R.drawable.widget_next_circle_dark
}

class PrayerTimesWidgetLight : BasePrayerTimesWidget() {
    override val layoutResId = R.layout.prayer_widget_light
    override val receiverClass = PrayerTimesWidgetLight::class.java
    override val requestCode = 7869
    override val defaultTimeColor = 0xFF2F3A32.toInt()
    override val currentTimeColor = 0xFF2C2416.toInt()
    override val nextTimeColor = 0xFF0D5E3A.toInt()
    override val currentHighlightDrawable = R.drawable.widget_current_highlight_light
    override val currentBadgeDrawable = R.drawable.widget_badge_light
    override val nextCircleDrawable = R.drawable.widget_next_circle_light
}
