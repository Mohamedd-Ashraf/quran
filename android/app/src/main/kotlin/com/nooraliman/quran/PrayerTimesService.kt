package com.nooraliman.quran

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Foreground service that shows a persistent prayer-times notification.
 *
 * Displays the current prayer, next prayer, and remaining time.
 * Updates itself every 60 seconds via a Handler.
 *
 * Started / stopped from Dart via the `quraan/adhan_player` MethodChannel
 * (methods: startPrayerTimesService / stopPrayerTimesService).
 *
 * The notification channel is created in [MainApplication.onCreate] so it
 * always exists before the service starts.
 */
class PrayerTimesService : Service() {

    companion object {
        private const val TAG        = "PrayerTimesService"
        const  val CHANNEL_ID        = "prayer_times_persistent"
        const  val NOTIF_ID          = 7_700

        /** Sent as deleteIntent when the user swipes/clears the notification on Android 14+.
         *  Causes the service to immediately re-pin itself as a foreground notification. */
        private const val ACTION_RESTORE = "com.nooraliman.quran.RESTORE_PRAYER_NOTIF"

        private const val PREFS_NAME        = "FlutterSharedPreferences"
        private const val KEY_PRAYER_TIMES  = "flutter.cached_prayer_times"
        private const val KEY_LANGUAGE      = "flutter.app_language"

        private val PRAYER_KEYS = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")

        private val ARABIC_NAMES = mapOf(
            "fajr"    to "الفجر",
            "sunrise" to "الشروق",
            "dhuhr"   to "الظهر",
            "asr"     to "العصر",
            "maghrib" to "المغرب",
            "isha"    to "العشاء",
        )
        private val ENGLISH_NAMES = mapOf(
            "fajr"    to "Fajr",
            "sunrise" to "Sunrise",
            "dhuhr"   to "Dhuhr",
            "asr"     to "Asr",
            "maghrib" to "Maghrib",
            "isha"    to "Isha",
        )
    }

    private val handler  = Handler(Looper.getMainLooper())
    private val updateRunnable = object : Runnable {
        override fun run() {
            updateNotification()
            handler.postDelayed(this, 60_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_RESTORE) {
            // On Android 14+ the user dismissed the notification; re-pin it immediately.
            startForeground(NOTIF_ID, buildNotification())
            Log.d(TAG, "Notification restored after user dismissal")
            return START_STICKY
        }
        startForeground(NOTIF_ID, buildNotification())
        // Schedule periodic updates; first tick in 60 s (we just built on start).
        handler.removeCallbacks(updateRunnable)
        handler.postDelayed(updateRunnable, 60_000L)
        Log.d(TAG, "Started")
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        Log.d(TAG, "Stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Notification ─────────────────────────────────────────────────────────

    private fun updateNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val prefs    = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isArabic = prefs.getString(KEY_LANGUAGE, "ar")?.startsWith("ar") != false
        val json     = prefs.getString(KEY_PRAYER_TIMES, null)

        val (nextName, remaining) = parsePrayerData(json, isArabic)

        val title = nextName
        val content = if (isArabic) "باقي $remaining" else "Remaining: $remaining"

        // Large icon — app logo loaded from Flutter assets bundle
        val largeIcon = try {
            assets.open("flutter_assets/assets/logo/files/transparent/Splash_dark_transparent.png")
                .use { BitmapFactory.decodeStream(it) }
        } catch (_: Exception) { null }

        // Small icon — monochrome ic_notification (required for Android 5+)
        val smallIconRes = resources
            .getIdentifier("ic_notification", "drawable", packageName)
            .takeIf { it != 0 } ?: android.R.drawable.ic_lock_idle_alarm

        // Tap → open app
        val openPi = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        // On Android 14+ users can dismiss foreground-service notifications.
        // When that happens, call back into the service to re-pin immediately.
        val restorePi = PendingIntent.getService(
            this, 42,
            Intent(this, PrayerTimesService::class.java).setAction(ACTION_RESTORE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }

        builder
            .setSmallIcon(smallIconRes)
            .setContentTitle(title)
            .setContentText(content)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setColor(0xFFD4AF37.toInt())     // Gold
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(false)

        if (largeIcon != null) builder.setLargeIcon(largeIcon)
        if (openPi   != null) builder.setContentIntent(openPi)
        builder.setDeleteIntent(restorePi)

        val notif = builder.build()
        // FLAG_ONGOING_EVENT — excluded from "Clear all" swipe
        // FLAG_NO_CLEAR      — explicitly blocks user-initiated removal
        notif.flags = notif.flags or
                Notification.FLAG_ONGOING_EVENT or
                Notification.FLAG_NO_CLEAR
        return notif
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            "مواقيت الصلاة",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "إشعار ثابت يعرض الصلاة الحالية والقادمة والوقت المتبقي"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        nm.createNotificationChannel(ch)
    }

    // ── Prayer data parsing ───────────────────────────────────────────────────

    /** Parses cached prayer JSON (written by [PrayerTimesCacheService] in Dart). */
    private fun parsePrayerData(json: String?, isArabic: Boolean): Pair<String, String> {
        val loading = if (isArabic) "جاري التحميل..." else "Loading..."
        val dash    = "—"

        if (json.isNullOrBlank()) return Pair(dash, loading)

        return try {
            val root  = JSONObject(json)
            val times = root.optJSONObject("times") ?: return Pair(dash, loading)

            val now      = LocalDateTime.now()
            val fmt      = DateTimeFormatter.ofPattern("yyyy-MM-dd")
            val todayKey = now.format(fmt)
            val todayObj = times.optJSONObject(todayKey)

            fun parseDt(key: String, obj: JSONObject?): LocalDateTime? =
                obj?.optString(key)?.takeIf { it.isNotBlank() }
                    ?.let { s -> runCatching { LocalDateTime.parse(s.take(19)) }.getOrNull() }

            // Build ordered list: (key, time)
            val todayList = PRAYER_KEYS.mapNotNull { key ->
                parseDt(key, todayObj)?.let { key to it }
            }

            var nextKey:  String? = null
            var nextTime: LocalDateTime? = null

            for ((key, dt) in todayList) {
                if (dt.isAfter(now) && nextKey == null) {
                    nextKey = key; nextTime = dt
                }
            }

            // All prayers done → tomorrow's Fajr
            if (nextKey == null) {
                val tomorrowKey = now.plusDays(1).format(fmt)
                nextKey  = "fajr"
                nextTime = parseDt("fajr", times.optJSONObject(tomorrowKey))
            }

            val nextName = (if (isArabic) ARABIC_NAMES else ENGLISH_NAMES)[nextKey] ?: dash

            val remainingStr = nextTime?.let { nt ->
                val totalMins = ChronoUnit.MINUTES.between(now, nt).coerceAtLeast(0)
                val h = totalMins / 60
                val m = totalMins % 60
                if (isArabic) {
                    when {
                        h > 0 && m > 0 -> "$h ساعة و $m دقيقة"
                        h > 0          -> "$h ساعة"
                        else           -> "$m دقيقة"
                    }
                } else {
                    when {
                        h > 0 && m > 0 -> "${h}h ${m}m"
                        h > 0          -> "${h}h"
                        else           -> "${m}m"
                    }
                }
            } ?: dash

            Pair(nextName, remainingStr)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing prayer data", e)
            Pair(dash, loading)
        }
    }
}
