package com.nooraliman.quran

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

private const val PREFS_NAME         = "FlutterSharedPreferences"
private const val WIDGET_STATE_PREFS  = "hijri_widget_state"
private const val ACTION_HIJRI_UPDATE = "com.nooraliman.quran.HIJRI_WIDGET_UPDATE"
private const val ACTION_HIJRI_WEEK   = "com.nooraliman.quran.HIJRI_ZOOM_WEEK"
private const val ACTION_HIJRI_DAY    = "com.nooraliman.quran.HIJRI_ZOOM_DAY"
private const val ACTION_HIJRI_RESET  = "com.nooraliman.quran.HIJRI_RESET"

// Widget view states
private const val STATE_MONTHLY = 0
private const val STATE_WEEKLY  = 1
private const val STATE_DAILY   = 2

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
            val mgr = AppWidgetManager.getInstance(context)
            when (intent.action) {
                ACTION_HIJRI_UPDATE,
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_DATE_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED -> {
                    val ids = mgr.getAppWidgetIds(ComponentName(context, receiverClass))
                    if (ids.isNotEmpty()) ids.forEach { safeUpdateWidget(context, mgr, it) }
                    scheduleMidnightUpdate(context)
                }
                ACTION_HIJRI_WEEK -> {
                    val widgetId = intent.getIntExtra("wid", AppWidgetManager.INVALID_APPWIDGET_ID)
                    val row      = intent.getIntExtra("row", -1)
                    if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID && row >= 0) {
                        saveState(context, widgetId, STATE_WEEKLY, row, 0)
                        safeUpdateWidget(context, mgr, widgetId)
                    }
                }
                ACTION_HIJRI_DAY -> {
                    val widgetId = intent.getIntExtra("wid", AppWidgetManager.INVALID_APPWIDGET_ID)
                    val day      = intent.getIntExtra("day", 0)
                    if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID && day > 0) {
                        saveState(context, widgetId, STATE_DAILY, 0, day)
                        safeUpdateWidget(context, mgr, widgetId)
                    }
                }
                ACTION_HIJRI_RESET -> {
                    val widgetId = intent.getIntExtra("wid", AppWidgetManager.INVALID_APPWIDGET_ID)
                    if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                        clearState(context, widgetId)
                        safeUpdateWidget(context, mgr, widgetId)
                    }
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

    // ── State helpers ────────────────────────────────────────────────────

    private fun saveState(ctx: Context, wid: Int, state: Int, row: Int, day: Int) {
        ctx.getSharedPreferences(WIDGET_STATE_PREFS, Context.MODE_PRIVATE).edit()
            .putInt("st_$wid", state)
            .putInt("row_$wid", row)
            .putInt("day_$wid", day)
            .apply()
    }

    private fun getWidgetState(ctx: Context, wid: Int): Triple<Int, Int, Int> {
        val sp = ctx.getSharedPreferences(WIDGET_STATE_PREFS, Context.MODE_PRIVATE)
        return Triple(sp.getInt("st_$wid", STATE_MONTHLY), sp.getInt("row_$wid", 0), sp.getInt("day_$wid", 0))
    }

    private fun clearState(ctx: Context, wid: Int) {
        ctx.getSharedPreferences(WIDGET_STATE_PREFS, Context.MODE_PRIVATE).edit()
            .remove("st_$wid").remove("row_$wid").remove("day_$wid").apply()
    }

    // ── Widget update dispatcher ─────────────────────────────────────────

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, widgetId: Int, newOptions: android.os.Bundle,
    ) {
        safeUpdateWidget(context, manager, widgetId)
    }

    private fun safeUpdateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
        try {
            val minWidthDp = manager.getAppWidgetOptions(widgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val (state, row, day) = getWidgetState(context, widgetId)
            val views = when (state) {
                STATE_WEEKLY -> buildWeeklyViews(context, widgetId, row, minWidthDp)
                STATE_DAILY  -> buildDailyViews(context, widgetId, day)
                else         -> buildMonthlyViews(context, widgetId, minWidthDp)
            }
            manager.updateAppWidget(widgetId, views)
        } catch (_: Exception) {}
    }

    // ── Common: compute Hijri calendar grid data ─────────────────────────

    private data class GridData(
        val today: HijriDate,
        val daysInMonth: Int,
        val startCol: Int,          // column index (0-6) where day 1 starts
        val hijriMonthName: String,
        val hijriYear: String,
        val gregLabel: String,
    )

    private fun computeGrid(context: Context): GridData {
        val cal    = Calendar.getInstance()
        val offset = getHijriOffset(context)
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
        val gregMonths = arrayOf(
            "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
            "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
        )

        val firstOfMonthCal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -(today.day - 1))
        }
        val startCol = when (firstOfMonthCal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SATURDAY  -> 0  // col 0 = rightmost in forced-RTL layout
            Calendar.SUNDAY    -> 1
            Calendar.MONDAY    -> 2
            Calendar.TUESDAY   -> 3
            Calendar.WEDNESDAY -> 4
            Calendar.THURSDAY  -> 5
            else               -> 6  // FRIDAY = leftmost col
        }

        return GridData(
            today       = today,
            daysInMonth = hijriMonthLength(today.year, today.month),
            startCol    = startCol,
            hijriMonthName = months[today.month - 1],
            hijriYear   = toArabicNumerals(today.year.toString()),
            gregLabel   = "${gregMonths[cal.get(Calendar.MONTH)]} ${toArabicNumerals(cal.get(Calendar.YEAR).toString())}",
        )
    }

    // ── Cell / Row / Header IDs ─────────────────────────────────────────

    private val headerIds = intArrayOf(
        R.id.hdr_col0, R.id.hdr_col1, R.id.hdr_col2, R.id.hdr_col3,
        R.id.hdr_col4, R.id.hdr_col5, R.id.hdr_col6,
    )
    private val dayNamesShort = arrayOf("سب", "أح", "اث", "ثل", "أر", "خم", "جم")
    private val dayNamesFull  = arrayOf("السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة")

    private fun applyHeaders(views: RemoteViews, minWidthDp: Int) {
        val labels = if (minWidthDp >= 250) dayNamesFull else dayNamesShort
        val sizeSp = if (minWidthDp >= 250) 6f else 7f
        for (i in headerIds.indices) {
            views.setTextViewText(headerIds[i], labels[i])
            views.setTextViewTextSize(headerIds[i], android.util.TypedValue.COMPLEX_UNIT_SP, sizeSp)
        }
    }

    private val cellIds = arrayOf(
        intArrayOf(R.id.d_r1c1, R.id.d_r1c2, R.id.d_r1c3, R.id.d_r1c4, R.id.d_r1c5, R.id.d_r1c6, R.id.d_r1c7),
        intArrayOf(R.id.d_r2c1, R.id.d_r2c2, R.id.d_r2c3, R.id.d_r2c4, R.id.d_r2c5, R.id.d_r2c6, R.id.d_r2c7),
        intArrayOf(R.id.d_r3c1, R.id.d_r3c2, R.id.d_r3c3, R.id.d_r3c4, R.id.d_r3c5, R.id.d_r3c6, R.id.d_r3c7),
        intArrayOf(R.id.d_r4c1, R.id.d_r4c2, R.id.d_r4c3, R.id.d_r4c4, R.id.d_r4c5, R.id.d_r4c6, R.id.d_r4c7),
        intArrayOf(R.id.d_r5c1, R.id.d_r5c2, R.id.d_r5c3, R.id.d_r5c4, R.id.d_r5c5, R.id.d_r5c6, R.id.d_r5c7),
        intArrayOf(R.id.d_r6c1, R.id.d_r6c2, R.id.d_r6c3, R.id.d_r6c4, R.id.d_r6c5, R.id.d_r6c6, R.id.d_r6c7),
    )

    private val rowIds = intArrayOf(
        R.id.hijri_row1, R.id.hijri_row2, R.id.hijri_row3,
        R.id.hijri_row4, R.id.hijri_row5, R.id.hijri_row6,
    )

    /** Build a day→(row,col) mapping from startCol and daysInMonth */
    private fun dayGrid(startCol: Int, daysInMonth: Int): Array<IntArray> {
        // grid[day-1] = intArrayOf(row, col)
        val grid = Array(daysInMonth) { intArrayOf(0, 0) }
        var r = 0; var c = startCol
        for (d in 1..daysInMonth) {
            grid[d - 1] = intArrayOf(r, c)
            c++
            if (c >= 7) { c = 0; r++ }
        }
        return grid
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STATE 0: Monthly calendar (full month grid)
    // ══════════════════════════════════════════════════════════════════════

    private fun buildMonthlyViews(context: Context, widgetId: Int, minWidthDp: Int = 0): RemoteViews {
        val views = RemoteViews(context.packageName, layoutResId)
        val g     = computeGrid(context)

        views.setTextViewText(R.id.hijri_month_year, "${g.hijriMonthName}  ${g.hijriYear} هـ")
        views.setTextViewText(R.id.hijri_gregorian,  g.gregLabel)
        applyHeaders(views, minWidthDp)

        val grid = dayGrid(g.startCol, g.daysInMonth)
        val maxRowUsed = (g.startCol + g.daysInMonth - 1) / 7

        // Show only rows actually needed, hide the rest to avoid blank space
        for (i in rowIds.indices) {
            views.setViewVisibility(rowIds[i], if (i <= maxRowUsed) View.VISIBLE else View.GONE)
            views.setInt(rowIds[i], "setBackgroundColor", 0x00000000)
        }
        for (rowArr in cellIds) for (id in rowArr) {
            views.setTextViewText(id, "")
            views.setInt(id, "setBackgroundColor", 0x00000000)
        }
        // Reset text colors to per-theme default
        for (rowArr in cellIds) for (id in rowArr) {
            views.setTextColor(id, defaultCellTextColor)
        }

        // Fill day numbers + set per-cell click → zoom to week
        for (d in 1..g.daysInMonth) {
            val (r, c) = grid[d - 1]
            val cid = cellIds[r][c]
            views.setTextViewText(cid, toArabicNumerals(d.toString()))

            if (d == g.today.day) {
                views.setInt(cid, "setBackgroundColor", todayHighlightColor)
                views.setTextColor(cid, todayTextColor)
            }

            // Each cell taps → zoom to its week row
            val weekIntent = Intent(context, receiverClass).apply {
                action = ACTION_HIJRI_WEEK
                putExtra("wid", widgetId)
                putExtra("row", r)
                data = Uri.parse("hijri://week/$widgetId/$r/$d")
            }
            views.setOnClickPendingIntent(cid, PendingIntent.getBroadcast(
                context, 0, weekIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ))
        }

        // Event badge
        val event = getIslamicEvent(g.today.month, g.today.day)
        if (event != null) {
            views.setViewVisibility(R.id.hijri_event, View.VISIBLE)
            views.setTextViewText(R.id.hijri_event, "✦ $event")
        } else {
            views.setViewVisibility(R.id.hijri_event, View.GONE)
        }

        return views
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STATE 1: Weekly view — same grid, active row highlighted
    //  (Never hide rows — that causes the row to expand and fill all space)
    // ══════════════════════════════════════════════════════════════════════

    private fun buildWeeklyViews(context: Context, widgetId: Int, activeRow: Int, minWidthDp: Int = 0): RemoteViews {
        val views = RemoteViews(context.packageName, layoutResId)
        val g     = computeGrid(context)
        val grid  = dayGrid(g.startCol, g.daysInMonth)

        views.setTextViewText(R.id.hijri_month_year, "${g.hijriMonthName}  ${g.hijriYear} هـ")
        views.setTextViewText(R.id.hijri_gregorian,  "◀  اضغط على يوم لتفاصيله")
        applyHeaders(views, minWidthDp)

        // Keep ALL rows visible at equal height — reset backgrounds
        for (i in rowIds.indices) {
            views.setViewVisibility(rowIds[i], View.VISIBLE)
            views.setInt(rowIds[i], "setBackgroundColor", 0x00000000)
        }
        // Highlight the active row only
        views.setInt(rowIds[activeRow], "setBackgroundColor", 0x44F0C040)

        val maxRowUsed = (g.startCol + g.daysInMonth - 1) / 7

        // Clear all cells first; hide rows beyond what the month needs
        for (i in rowIds.indices) {
            views.setViewVisibility(rowIds[i], if (i <= maxRowUsed) View.VISIBLE else View.GONE)
        }
        for (rowArr in cellIds) for (id in rowArr) {
            views.setTextViewText(id, "")
            views.setInt(id, "setBackgroundColor", 0x00000000)
            views.setTextColor(id, dimmedCellTextColor)
        }

        // Fill ALL day numbers — active row bright, others dimmed
        for (d in 1..g.daysInMonth) {
            val (r, c) = grid[d - 1]
            val cid = cellIds[r][c]
            views.setTextViewText(cid, toArabicNumerals(d.toString()))

            if (r == activeRow) {
                // Active row: normal brightness, tap → daily detail
                if (d == g.today.day) {
                    views.setInt(cid, "setBackgroundColor", todayHighlightColor)
                    views.setTextColor(cid, todayTextColor)
                } else {
                    views.setTextColor(cid, activeCellTextColor)
                }
                val dayIntent = Intent(context, receiverClass).apply {
                    action = ACTION_HIJRI_DAY
                    putExtra("wid", widgetId)
                    putExtra("day", d)
                    data = Uri.parse("hijri://day/$widgetId/$d")
                }
                views.setOnClickPendingIntent(cid, PendingIntent.getBroadcast(
                    context, 0, dayIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ))
            } else {
                // Other rows: dimmed, tap → switch highlight to that row
                views.setTextColor(cid, dimmedCellTextColor)
                val weekIntent = Intent(context, receiverClass).apply {
                    action = ACTION_HIJRI_WEEK
                    putExtra("wid", widgetId)
                    putExtra("row", r)
                    data = Uri.parse("hijri://week/$widgetId/$r/$d")
                }
                views.setOnClickPendingIntent(cid, PendingIntent.getBroadcast(
                    context, 0, weekIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ))
            }
        }

        // Event badge — check active row
        var rowEvent: String? = null
        for (d in 1..g.daysInMonth) {
            val (r, _) = grid[d - 1]
            if (r != activeRow) continue
            val ev = getIslamicEvent(g.today.month, d)
            if (ev != null) { rowEvent = ev; break }
        }
        if (rowEvent != null) {
            views.setViewVisibility(R.id.hijri_event, View.VISIBLE)
            views.setTextViewText(R.id.hijri_event, "✦ $rowEvent")
        } else {
            views.setViewVisibility(R.id.hijri_event, View.GONE)
        }

        // Header / subheader tap → back to full monthly
        val resetIntent = Intent(context, receiverClass).apply {
            action = ACTION_HIJRI_RESET
            putExtra("wid", widgetId)
            data = Uri.parse("hijri://reset/$widgetId/w")
        }
        val resetPi = PendingIntent.getBroadcast(
            context, 0, resetIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.hijri_month_year, resetPi)
        views.setOnClickPendingIntent(R.id.hijri_gregorian, resetPi)

        return views
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STATE 2: Daily detail view
    // ══════════════════════════════════════════════════════════════════════

    private fun buildDailyViews(context: Context, widgetId: Int, zoomedDay: Int): RemoteViews {
        val views = RemoteViews(context.packageName, zoomedLayoutResId)
        val g     = computeGrid(context)

        // Calendar for the tapped day (offset from today)
        val tappedCal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, zoomedDay - g.today.day)
        }

        val dayNames = arrayOf("", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت")
        val gregMonths = arrayOf(
            "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
            "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
        )

        val dayName  = dayNames[tappedCal.get(Calendar.DAY_OF_WEEK)]
        val gregDate = "${toArabicNumerals(tappedCal.get(Calendar.DAY_OF_MONTH).toString())} " +
            "${gregMonths[tappedCal.get(Calendar.MONTH)]} " +
            toArabicNumerals(tappedCal.get(Calendar.YEAR).toString())

        views.setTextViewText(R.id.zoom_day_number,  toArabicNumerals(zoomedDay.toString()))
        views.setTextViewText(R.id.zoom_day_of_week, dayName)
        views.setTextViewText(R.id.zoom_hijri_label, "${g.hijriMonthName}  ${g.hijriYear} هـ")
        views.setTextViewText(R.id.zoom_gregorian,   gregDate)

        val event = getIslamicEvent(g.today.month, zoomedDay)
        if (event != null) {
            views.setViewVisibility(R.id.zoom_event, View.VISIBLE)
            views.setTextViewText(R.id.zoom_event, "✦ $event")
        } else {
            views.setViewVisibility(R.id.zoom_event, View.GONE)
        }

        // Entire widget taps → back to monthly calendar (NOT open app)
        val resetIntent = Intent(context, receiverClass).apply {
            action = ACTION_HIJRI_RESET
            putExtra("wid", widgetId)
            data = Uri.parse("hijri://reset/$widgetId/d")
        }
        val resetPi = PendingIntent.getBroadcast(
            context, 0, resetIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.zoom_back_area, resetPi)
        views.setOnClickPendingIntent(R.id.zoom_day_area, resetPi)
        views.setOnClickPendingIntent(R.id.hijri_widget_root, resetPi)

        return views
    }

    /** Zoomed layout resource — overridden per theme. */
    protected abstract val zoomedLayoutResId: Int

    /** Colors for today's highlight — overridden per theme */
    protected open val todayHighlightColor: Int = 0x44F0C040  // gold semi-transparent
    protected open val todayTextColor: Int = 0xFFF0C040.toInt() // bright gold

    /** Default day-number text color for all cells (overridden per theme) */
    protected open val defaultCellTextColor: Int = 0xCCFFFFFF.toInt()  // white for dark/balanced
    /** Dimmed text color for non-active rows in weekly view */
    protected open val dimmedCellTextColor: Int  = 0x44FFFFFF.toInt()  // faint white
    /** Active row text color in weekly view */
    protected open val activeCellTextColor: Int  = 0xEEFFFFFF.toInt()  // bright white

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
    override val zoomedLayoutResId = R.layout.hijri_widget_zoomed
    override val receiverClass = HijriCalendarWidget::class.java
    override val requestCode = 8000
}

class HijriCalendarWidgetDark : BaseHijriCalendarWidget() {
    override val layoutResId = R.layout.hijri_widget_dark
    override val zoomedLayoutResId = R.layout.hijri_widget_dark_zoomed
    override val receiverClass = HijriCalendarWidgetDark::class.java
    override val requestCode = 8001
}

class HijriCalendarWidgetLight : BaseHijriCalendarWidget() {
    override val layoutResId = R.layout.hijri_widget_light
    override val zoomedLayoutResId = R.layout.hijri_widget_light_zoomed
    override val receiverClass = HijriCalendarWidgetLight::class.java
    override val requestCode = 8002
    override val todayHighlightColor: Int = 0x33D4AF37
    override val todayTextColor: Int = 0xFF064E3B.toInt()
    // Light cream background needs dark text
    override val defaultCellTextColor: Int = 0xCC2F3A32.toInt()  // dark green
    override val dimmedCellTextColor: Int  = 0x552F3A32.toInt()  // faint dark green
    override val activeCellTextColor: Int  = 0xEE1A2E1A.toInt()  // rich dark green
}
