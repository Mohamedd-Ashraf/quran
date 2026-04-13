package com.nooraliman.quran

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
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

// ─── Constants ───────────────────────────────────────────────────────────────

private const val PREFS_NAME = "FlutterSharedPreferences"

// Flutter shared_preferences stores ints as Long with "flutter." prefix
private const val KEY_COUNT   = "flutter.tasbeeh_count_v2"
private const val KEY_TOTAL   = "flutter.tasbeeh_total_v2"
private const val KEY_PRESET  = "flutter.tasbeeh_preset_v2"
private const val KEY_TARGET  = "flutter.tasbeeh_custom_target_v2"
// Flag: true = last reset action was a soft-reset that landed on 0 (next press = hard reset)
private const val KEY_RESET_WAS_ZERO = "widget_reset_was_zero"

private const val ACTION_TASBEEH_INCREMENT  = "com.nooraliman.quran.TASBEEH_INCREMENT"
private const val ACTION_TASBEEH_RESET      = "com.nooraliman.quran.TASBEEH_RESET"
private const val ACTION_TASBEEH_NEXT       = "com.nooraliman.quran.TASBEEH_NEXT"
private const val ACTION_TASBEEH_UPDATE     = "com.nooraliman.quran.TASBEEH_WIDGET_UPDATE"

// ─── Preset data (mirrors _kPresets in tasbeeh_screen.dart) ──────────────────

private data class DhikrPreset(val textAr: String, val target: Int)

private val PRESETS = listOf(
    DhikrPreset("سُبْحَانَ اللَّهِ", 33),
    DhikrPreset("الْحَمْدُ لِلَّهِ", 33),
    DhikrPreset("اللَّهُ أَكْبَرُ", 34),
    DhikrPreset("لَا إِلَٰهَ إِلَّا اللَّهُ", 100),
    DhikrPreset("أَسْتَغْفِرُ اللَّهَ", 100),
    DhikrPreset("الصَّلَاةُ عَلَى النَّبِيِّ ﷺ", 100),
    DhikrPreset("حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", 100),
    DhikrPreset("حرة", 0),  // custom / free
)

// ─── Dispatcher (broadcasts update to all widget variants) ───────────────────

object TasbeehWidgetUpdateDispatcher {
    fun refreshAll(context: Context) {
        val providers = listOf(
            TasbeehWidget::class.java,
            TasbeehWidgetDark::class.java,
            TasbeehWidgetLight::class.java,
        )
        providers.forEach { provider ->
            try {
                val intent = Intent(context, provider).apply { action = ACTION_TASBEEH_UPDATE }
                context.sendBroadcast(intent)
            } catch (_: Exception) {
            }
        }
    }
}

// ─── Abstract base ───────────────────────────────────────────────────────────

abstract class BaseTasbeehWidget : AppWidgetProvider() {
    protected abstract val layoutResId: Int
    protected abstract val receiverClass: Class<out AppWidgetProvider>
    protected abstract val requestCode: Int
    protected abstract val beadColor: Int      // theme bead color (e.g. gold, teal, green)
    protected abstract val cordAlpha: Int       // cord circle alpha (0-255)

    // ── AppWidgetProvider overrides ──────────────────────────────────────────

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
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (_: Exception) {
        }
        try {
            when (intent.action) {
                ACTION_TASBEEH_INCREMENT -> {
                    handleIncrement(context)
                    refreshWidgets(context)
                }
                ACTION_TASBEEH_RESET -> {
                    handleReset(context)
                    refreshWidgets(context)
                }
                ACTION_TASBEEH_NEXT -> {
                    handleNextPreset(context)
                    refreshWidgets(context)
                }
                ACTION_TASBEEH_UPDATE -> {
                    refreshWidgets(context)
                }
            }
        } catch (_: Exception) {
        }
    }

    // ── State helpers ────────────────────────────────────────────────────────

    private fun getPrefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun readCount(context: Context): Int =
        getPrefs(context).getLong(KEY_COUNT, 0L).toInt()

    private fun readTotal(context: Context): Int =
        getPrefs(context).getLong(KEY_TOTAL, 0L).toInt()

    private fun readPresetIndex(context: Context): Int =
        getPrefs(context).getLong(KEY_PRESET, 0L).toInt().coerceIn(0, PRESETS.size - 1)

    private fun readCustomTarget(context: Context): Int =
        getPrefs(context).getLong(KEY_TARGET, 33L).toInt()

    private fun getTarget(presetIndex: Int, customTarget: Int): Int {
        return if (presetIndex == PRESETS.size - 1) customTarget
        else PRESETS[presetIndex].target
    }

    private fun handleIncrement(context: Context) {
        val prefs = getPrefs(context)
        val newCount = prefs.getLong(KEY_COUNT, 0L) + 1
        val newTotal = prefs.getLong(KEY_TOTAL, 0L) + 1
        prefs.edit()
            .putLong(KEY_COUNT, newCount)
            .putLong(KEY_TOTAL, newTotal)
            .putBoolean(KEY_RESET_WAS_ZERO, false)  // clear double-reset flag on increment
            .apply()
        // Vibrate lightly when a round completes (count becomes a multiple of target)
        val target = getTarget(readPresetIndex(context), readCustomTarget(context))
        android.util.Log.d("TasbeehWidget", "increment: newCount=$newCount target=$target mod=${if (target > 0) newCount % target else -1}")
        if (target > 0 && newCount % target == 0L) {
            android.util.Log.d("TasbeehWidget", "increment: ROUND COMPLETE → calling doVibrate")
            doVibrate(context)
        }
    }

    private fun handleReset(context: Context) {
        val prefs = getPrefs(context)
        val count = prefs.getLong(KEY_COUNT, 0L)
        val wasAlreadyZero = prefs.getBoolean(KEY_RESET_WAS_ZERO, false)
        if (count == 0L || wasAlreadyZero) {
            // Double-reset: wipe total as well (hard reset)
            prefs.edit()
                .putLong(KEY_COUNT, 0L)
                .putLong(KEY_TOTAL, 0L)
                .putBoolean(KEY_RESET_WAS_ZERO, false)
                .apply()
        } else {
            // First reset: just zero the counter, mark that we're now at zero
            prefs.edit()
                .putLong(KEY_COUNT, 0L)
                .putBoolean(KEY_RESET_WAS_ZERO, true)
                .apply()
        }
    }

    private fun handleNextPreset(context: Context) {
        val prefs = getPrefs(context)
        val current = prefs.getLong(KEY_PRESET, 0L).toInt()
        val next = (current + 1) % PRESETS.size
        prefs.edit()
            .putLong(KEY_PRESET, next.toLong())
            .putLong(KEY_COUNT, 0L)
            .putBoolean(KEY_RESET_WAS_ZERO, false)
            .apply()
    }

    // ── Widget rendering ─────────────────────────────────────────────────────

    companion object {
        private const val BEAD_COUNT = 33
        private const val GOLD_COLOR = 0xFFC9A227.toInt()
        private const val LIGHT_GOLD = 0xFFF8DC6A.toInt()
        private const val DARK_GOLD  = 0xFF8B6600.toInt()

        // Colors used for successive rounds after the first (round 1 always uses the theme beadColor)
        // Cycles: purple → sky-blue → amber → rose → teal → lime → gold → repeat
        private val CYCLE_COLORS = listOf(
            0xFF9B59B6.toInt(),  // amethyst purple
            0xFF5DADE2.toInt(),  // sky blue
            0xFFE67E22.toInt(),  // warm amber
            0xFFEC407A.toInt(),  // rose pink
            0xFF26A69A.toInt(),  // teal-green
            0xFF7CB342.toInt(),  // lime green
            0xFFC9A227.toInt(),  // gold
        )
    }

    // ── Vibration on round completion ──────────────────────────────────────
    private fun doVibrate(context: Context) {
        android.util.Log.d("TasbeehWidget", "doVibrate: called on SDK ${android.os.Build.VERSION.SDK_INT}")
        try {
            val appCtx = context.applicationContext
            val effect = android.os.VibrationEffect.createOneShot(80L, 200)

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                // API 31+: use VibratorManager.vibrate(CombinedVibration, VibrationAttributes)
                // VibrationAttributes.USAGE_NOTIFICATION is not suppressed by Samsung One UI
                // battery optimizer for background callers, unlike plain vibrate() calls.
                val vm = appCtx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                        as? android.os.VibratorManager
                val vibAttrs = android.os.VibrationAttributes.createForUsage(
                    android.os.VibrationAttributes.USAGE_NOTIFICATION
                )
                android.util.Log.d("TasbeehWidget", "doVibrate: vm=$vm, vibAttrs=$vibAttrs")
                vm?.vibrate(android.os.CombinedVibration.createParallel(effect), vibAttrs)
                android.util.Log.d("TasbeehWidget", "doVibrate: vibrate() call completed (API 31+)")
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                // API 26-30: attach AudioAttributes with USAGE_NOTIFICATION
                @Suppress("DEPRECATION")
                val vib = appCtx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                val attrs = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                android.util.Log.d("TasbeehWidget", "doVibrate: vib=$vib")
                vib?.vibrate(effect, attrs)
                android.util.Log.d("TasbeehWidget", "doVibrate: vibrate() call completed (API 26-30)")
            } else {
                @Suppress("DEPRECATION")
                val vib = appCtx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                @Suppress("DEPRECATION")
                vib?.vibrate(80L)
                android.util.Log.d("TasbeehWidget", "doVibrate: vibrate() call completed (legacy)")
            }
        } catch (e: Exception) {
            android.util.Log.e("TasbeehWidget", "doVibrate FAILED: ${e.javaClass.simpleName}: ${e.message}")
        }
    }

    /**
     * Draws a bead ring bitmap matching the Flutter _BeadRingPainter.
     * Filled beads show as 3D spheres; empty beads are faint hollow circles.
     */
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
        val ringR = sizePx / 2f - sizePx * 0.062f   // ~8/130 ratio
        val beadR = (sizePx / 34f).coerceIn(sizePx * 0.038f, sizePx * 0.073f)
        val dividerR = beadR * 1.38f
        val anglePerBead = (2.0 * PI / BEAD_COUNT).toFloat()

        val bc = if (isDone) GOLD_COLOR else roundBeadColor

        // 1 ─ Cord circle
        val cordPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = sizePx * 0.012f
            color = if (isDone) setAlpha(GOLD_COLOR, 115) else setAlpha(roundBeadColor, cordAlpha)
        }
        canvas.drawCircle(cx, cy, ringR, cordPaint)

        // 2 ─ Each bead
        for (i in 0 until BEAD_COUNT) {
            val angle = (-PI / 2 + i * anglePerBead).toFloat()
            val bx = cx + ringR * cos(angle)
            val by = cy + ringR * sin(angle)
            val r = if (i == 0) dividerR else beadR
            val isFilled = i < filledCount

            if (isFilled || isDone) {
                val baseColor = if (isDone) GOLD_COLOR else roundBeadColor
                val lightColor = if (isDone) LIGHT_GOLD else blendColor(baseColor, 0xFFFFFFFF.toInt(), 0.42f)
                val darkColor = if (isDone) DARK_GOLD else blendColor(baseColor, 0xFF000000.toInt(), 0.42f)

                // Soft drop shadow
                val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = setAlpha(0xFF000000.toInt(), 51)
                    maskFilter = android.graphics.BlurMaskFilter(
                        sizePx * 0.019f, android.graphics.BlurMaskFilter.Blur.NORMAL
                    )
                }
                canvas.drawCircle(bx, by + r * 0.28f, r * 0.82f, shadowPaint)

                // Sphere body with radial gradient
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

                // Divider bead white rim
                if (i == 0) {
                    val rimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        strokeWidth = sizePx * 0.009f
                        color = setAlpha(0xFFFFFFFF.toInt(), 102)
                    }
                    canvas.drawCircle(bx, by, r, rimPaint)
                }
            } else {
                // Empty bead — faint filled + hollow ring (uses current round color)
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

    private fun setAlpha(color: Int, alpha: Int): Int {
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }

    private fun blendColor(base: Int, blend: Int, ratio: Float): Int {
        val inv = 1f - ratio
        val r = (Color.red(base) * inv + Color.red(blend) * ratio).roundToInt().coerceIn(0, 255)
        val g = (Color.green(base) * inv + Color.green(blend) * ratio).roundToInt().coerceIn(0, 255)
        val b = (Color.blue(base) * inv + Color.blue(blend) * ratio).roundToInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    private fun refreshWidgets(context: Context) {
        try {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, receiverClass))
            if (ids.isNotEmpty()) {
                onUpdate(context, manager, ids)
            }
        } catch (_: Exception) {
        }
    }

    private fun safeUpdateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        try {
            val views = RemoteViews(context.packageName, layoutResId)
            val presetIndex = readPresetIndex(context)
            val count = readCount(context)
            val total = readTotal(context)
            val customTarget = readCustomTarget(context)
            val target = getTarget(presetIndex, customTarget)
            val preset = PRESETS[presetIndex]
            val isDone = target > 0 && count > 0 && count % target == 0

            // Round-cycle logic:
            //   completedRounds = how many full rounds done so far
            //   countInCurrentRound = progress within the ongoing round
            //   Round 1 uses the theme beadColor; subsequent rounds cycle through CYCLE_COLORS.
            val completedRounds = if (target > 0) count / target else 0
            val countInCurrentRound = if (target > 0) count % target else count
            val currentBeadColor = when {
                completedRounds == 0 -> beadColor
                else -> CYCLE_COLORS[(completedRounds - 1) % CYCLE_COLORS.size]
            }

            // Bind text
            views.setTextViewText(R.id.tasbeeh_dhikr_name, preset.textAr)
            views.setTextViewText(R.id.tasbeeh_count, toArabicNumerals("$count"))
            views.setTextViewText(R.id.tasbeeh_total, toArabicNumerals("$total"))

            if (target > 0) {
                views.setTextViewText(R.id.tasbeeh_target, "من ${toArabicNumerals("$target")}")
                views.setViewVisibility(R.id.tasbeeh_target, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.tasbeeh_target, View.GONE)
            }

            // Draw dynamic bead ring bitmap
            val filledBeads = when {
                isDone -> BEAD_COUNT
                target > 0 -> (countInCurrentRound.toDouble() / target * BEAD_COUNT).roundToInt().coerceIn(0, BEAD_COUNT)
                else -> 0
            }
            val density = context.resources.displayMetrics.density
            val bitmapSizePx = (130 * density).roundToInt()
            val beadBitmap = drawBeadRingBitmap(bitmapSizePx, filledBeads, isDone, currentBeadColor)
            views.setImageViewBitmap(R.id.tasbeeh_bead_ring, beadBitmap)

            // Show/hide done label
            if (isDone) {
                views.setViewVisibility(R.id.tasbeeh_done_label, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.tasbeeh_done_label, View.GONE)
            }

            // Show "اضغط للتسبيح" hint only when counter is at zero
            views.setViewVisibility(R.id.tasbeeh_tap_hint,
                if (count == 0 && !isDone) View.VISIBLE else View.GONE)

            // Click intents
            attachClickIntent(context, views, R.id.tasbeeh_tap_area, ACTION_TASBEEH_INCREMENT, requestCode)
            attachClickIntent(context, views, R.id.tasbeeh_reset_btn, ACTION_TASBEEH_RESET, requestCode + 100)
            attachClickIntent(context, views, R.id.tasbeeh_next_btn, ACTION_TASBEEH_NEXT, requestCode + 200)

            manager.updateAppWidget(widgetId, views)
        } catch (_: Exception) {
        }
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
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(viewId, pi)
    }

    // ── Utility ──────────────────────────────────────────────────────────────

    private fun toArabicNumerals(s: String): String {
        return s.map {
            when (it) {
                '0' -> '٠'; '1' -> '١'; '2' -> '٢'; '3' -> '٣'; '4' -> '٤'
                '5' -> '٥'; '6' -> '٦'; '7' -> '٧'; '8' -> '٨'; '9' -> '٩'
                else -> it
            }
        }.joinToString("")
    }
}

// ─── Concrete widget variants ────────────────────────────────────────────────

class TasbeehWidget : BaseTasbeehWidget() {
    override val layoutResId = R.layout.tasbeeh_widget
    override val receiverClass = TasbeehWidget::class.java
    override val requestCode = 7870
    override val beadColor = 0xFFC9A227.toInt()  // gold
    override val cordAlpha = 64
}

class TasbeehWidgetDark : BaseTasbeehWidget() {
    override val layoutResId = R.layout.tasbeeh_widget_dark
    override val receiverClass = TasbeehWidgetDark::class.java
    override val requestCode = 7871
    override val beadColor = 0xFF7AD5B0.toInt()  // teal
    override val cordAlpha = 64
}

class TasbeehWidgetLight : BaseTasbeehWidget() {
    override val layoutResId = R.layout.tasbeeh_widget_light
    override val receiverClass = TasbeehWidgetLight::class.java
    override val requestCode = 7872
    override val beadColor = 0xFF0D5E3A.toInt()  // green
    override val cordAlpha = 64
}
