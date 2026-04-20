package com.nooraliman.quran

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

private const val PREFS_NAME = "FlutterSharedPreferences"
private const val ACTION_HIJRI_UPDATE = "com.nooraliman.quran.HIJRI_WIDGET_UPDATE"

object HijriWidgetUpdateDispatcher {
    fun refreshAll(context: Context) {
        val providers = listOf(
            HijriCalendarWidget::class.java,
            HijriCalendarWidgetDark::class.java,
            HijriCalendarWidgetLight::class.java,
        )
        providers.forEach { provider ->
            try {
                val intent = Intent(context, provider).apply { action = ACTION_HIJRI_UPDATE }
                context.sendBroadcast(intent)
            } catch (_: Exception) {}
        }
    }
}

abstract class BaseHijriCalendarWidget : AppWidgetProvider() {
    protected abstract val layoutResId: Int
    protected abstract val receiverClass: Class<out AppWidgetProvider>
    protected abstract val requestCode: Int

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        try {
            appWidgetIds.forEach { widgetId ->
                safeUpdateWidget(context, appWidgetManager, widgetId)
            }
        } catch (_: Exception) {}
        scheduleMidnightUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        try { super.onReceive(context, intent) } catch (_: Exception) {}
        try {
            when (intent.action) {
                ACTION_HIJRI_UPDATE,
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_DATE_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED -> {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, receiverClass))
                    if (ids.isNotEmpty()) {
                        ids.forEach { safeUpdateWidget(context, mgr, it) }
                    }
                    scheduleMidnightUpdate(context)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onEnabled(context: Context) {
        try { super.onEnabled(context) } catch (_: Exception) {}
        scheduleMidnightUpdate(context)
    }

    override fun onDisabled(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val intent = Intent(context, receiverClass).apply { action = ACTION_HIJRI_UPDATE }
            val pi = PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pi != null) alarmManager?.cancel(pi)
        } catch (_: Exception) {}
    }

    private fun safeUpdateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
        try {
            val views = buildRemoteViews(context)
            manager.updateAppWidget(widgetId, views)
        } catch (_: Exception) {}
    }

    private fun buildRemoteViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, layoutResId)

        // Open app when widget is tapped
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pi = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.hijri_widget_root, pi)
        }

        val cal = Calendar.getInstance()
        val offset = getHijriOffset(context)

        // Today's Hijri date
        val todayJd = gregorianToJulianDay(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
        ) + offset
        val today = islamicFromJulianDay(todayJd)

        val months = arrayOf(
            "محرم", "صفر", "ربيع الأول", "ربيع الآخر",
            "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
            "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
        )

        // Header: month + year
        views.setTextViewText(
            R.id.hijri_month_year,
            "${months[today.month - 1]}  ${toArabicNumerals(today.year.toString())} هـ",
        )

        // Gregorian sub-header
        val gregMonths = arrayOf(
            "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
            "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
        )
        views.setTextViewText(
            R.id.hijri_gregorian,
            "${gregMonths[cal.get(Calendar.MONTH)]} ${toArabicNumerals(cal.get(Calendar.YEAR).toString())}",
        )

        // Determine the number of days in the current Hijri month (29 or 30)
        val daysInMonth = hijriMonthLength(today.year, today.month)

        // Find what day-of-week the 1st of this Hijri month falls on.
        // We go back (today.day - 1) days from today's Gregorian date.
        val firstOfMonthCal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -(today.day - 1))
        }
        // Calendar.DAY_OF_WEEK: Sunday=1, Monday=2, ..., Saturday=7
        val calDow = firstOfMonthCal.get(Calendar.DAY_OF_WEEK)
        // Our grid columns (RTL): col0=Sat, col1=Fri, col2=Thu, col3=Wed, col4=Tue, col5=Mon, col6=Sun
        val startCol = when (calDow) {
            Calendar.SATURDAY  -> 0
            Calendar.FRIDAY    -> 1
            Calendar.THURSDAY  -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.TUESDAY   -> 4
            Calendar.MONDAY    -> 5
            Calendar.SUNDAY    -> 6
            else -> 0
        }

        // Grid cell IDs (6 rows x 7 cols)
        val cellIds = arrayOf(
            intArrayOf(R.id.d_r1c1, R.id.d_r1c2, R.id.d_r1c3, R.id.d_r1c4, R.id.d_r1c5, R.id.d_r1c6, R.id.d_r1c7),
            intArrayOf(R.id.d_r2c1, R.id.d_r2c2, R.id.d_r2c3, R.id.d_r2c4, R.id.d_r2c5, R.id.d_r2c6, R.id.d_r2c7),
            intArrayOf(R.id.d_r3c1, R.id.d_r3c2, R.id.d_r3c3, R.id.d_r3c4, R.id.d_r3c5, R.id.d_r3c6, R.id.d_r3c7),
            intArrayOf(R.id.d_r4c1, R.id.d_r4c2, R.id.d_r4c3, R.id.d_r4c4, R.id.d_r4c5, R.id.d_r4c6, R.id.d_r4c7),
            intArrayOf(R.id.d_r5c1, R.id.d_r5c2, R.id.d_r5c3, R.id.d_r5c4, R.id.d_r5c5, R.id.d_r5c6, R.id.d_r5c7),
            intArrayOf(R.id.d_r6c1, R.id.d_r6c2, R.id.d_r6c3, R.id.d_r6c4, R.id.d_r6c5, R.id.d_r6c6, R.id.d_r6c7),
        )

        // Clear all cells first
        for (row in cellIds) {
            for (cellId in row) {
                views.setTextViewText(cellId, "")
                views.setInt(cellId, "setBackgroundColor", 0x00000000) // transparent
            }
        }

        // Fill in day numbers
        var dayNum = 1
        var row = 0
        var col = startCol
        while (dayNum <= daysInMonth && row < 6) {
            val cellId = cellIds[row][col]
            views.setTextViewText(cellId, toArabicNumerals(dayNum.toString()))

            // Highlight today
            if (dayNum == today.day) {
                views.setInt(cellId, "setBackgroundColor", todayHighlightColor)
                views.setTextColor(cellId, todayTextColor)
            }

            dayNum++
            col++
            if (col >= 7) {
                col = 0
                row++
            }
        }

        // Islamic events for today
        val event = getIslamicEvent(today.month, today.day)
        if (event != null) {
            views.setViewVisibility(R.id.hijri_event, View.VISIBLE)
            views.setTextViewText(R.id.hijri_event, "✦ $event")
        } else {
            views.setViewVisibility(R.id.hijri_event, View.GONE)
        }

        return views
    }

    /** Colors for today's highlight — overridden per theme */
    protected open val todayHighlightColor: Int = 0x44F0C040  // gold semi-transparent
    protected open val todayTextColor: Int = 0xFFF0C040.toInt() // bright gold

    /**
     * Approximate Hijri month length.
     * Odd months (1,3,5,7,9,11) = 30 days, even months = 29 days,
     * except month 12 in leap years = 30 days.
     */
    private fun hijriMonthLength(year: Int, month: Int): Int {
        if (month % 2 == 1) return 30
        if (month == 12 && isHijriLeapYear(year)) return 30
        return 29
    }

    private fun isHijriLeapYear(year: Int): Boolean {
        return ((11 * year + 14) % 30) < 11
    }

    private fun scheduleMidnightUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, receiverClass).apply { action = ACTION_HIJRI_UPDATE }
            val pi = PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            // Schedule at midnight + 1 min
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, midnight.timeInMillis, pi,
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, midnight.timeInMillis, pi,
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, midnight.timeInMillis, pi,
                )
            }
        } catch (_: Exception) {}
    }

    private fun getHijriOffset(context: Context): Int {
        return try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            // Flutter stores int values as Long
            prefs.getLong("flutter.hijri_date_offset", 0).toInt()
        } catch (_: Exception) { 0 }
    }

    private fun getIslamicEvent(month: Int, day: Int): String? {
        val events = mapOf(
            Pair(1, 1) to "رأس السنة الهجرية",
            Pair(1, 10) to "يوم عاشوراء",
            Pair(3, 12) to "المولد النبوي الشريف",
            Pair(7, 27) to "ليلة الإسراء والمعراج",
            Pair(8, 15) to "نصف شعبان",
            Pair(9, 1) to "أول رمضان",
            Pair(9, 27) to "ليلة القدر",
            Pair(10, 1) to "عيد الفطر المبارك",
            Pair(12, 9) to "يوم عرفة",
            Pair(12, 10) to "عيد الأضحى المبارك",
        )
        return events[Pair(month, day)]
    }

    // ── Hijri calendar calculations ─────────────────────────────────────

    private data class HijriDate(val year: Int, val month: Int, val day: Int)

    private fun gregorianToJulianDay(year: Int, month: Int, day: Int): Int {
        val a = (14 - month) / 12
        val y = year + 4800 - a
        val m = month + 12 * a - 3
        return day + ((153 * m + 2) / 5) + 365 * y + (y / 4) - (y / 100) + (y / 400) - 32045
    }

    private fun islamicFromJulianDay(jd: Int): HijriDate {
        val l = jd - 1948440 + 10632
        val n = ((l - 1) / 10631)
        val l2 = l - 10631 * n + 354
        val j = ((10985 - l2) / 5316) * ((50 * l2) / 17719) + (l2 / 5670) * ((43 * l2) / 15238)
        val l3 = l2 - ((30 - j) / 15) * ((17719 * j) / 50) - ((j / 16)) * ((15238 * j) / 43) + 29
        val m = (24 * l3) / 709
        val d = l3 - (709 * m) / 24
        val y = 30 * n + j - 30
        return HijriDate(y, m, d)
    }

    private fun toArabicNumerals(input: String): String {
        val arabicDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        return input.map { ch ->
            if (ch in '0'..'9') arabicDigits[ch - '0'] else ch
        }.joinToString("")
    }
}

// ── Three theme variants ──────────────────────────────────────────────────

class HijriCalendarWidget : BaseHijriCalendarWidget() {
    override val layoutResId = R.layout.hijri_widget
    override val receiverClass = HijriCalendarWidget::class.java
    override val requestCode = 8000
}

class HijriCalendarWidgetDark : BaseHijriCalendarWidget() {
    override val layoutResId = R.layout.hijri_widget_dark
    override val receiverClass = HijriCalendarWidgetDark::class.java
    override val requestCode = 8001
}

class HijriCalendarWidgetLight : BaseHijriCalendarWidget() {
    override val layoutResId = R.layout.hijri_widget_light
    override val receiverClass = HijriCalendarWidgetLight::class.java
    override val requestCode = 8002
    override val todayHighlightColor: Int = 0x33D4AF37  // gold on light bg
    override val todayTextColor: Int = 0xFF064E3B.toInt() // dark green
}
