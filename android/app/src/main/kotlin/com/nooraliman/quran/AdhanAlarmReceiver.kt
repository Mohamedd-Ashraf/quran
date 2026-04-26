package com.nooraliman.quran

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date

/**
 * BroadcastReceiver for two purposes:
 *
 * 1. ACTION_FIRE — triggered by AlarmManager at each prayer time.
 *    Starts AdhanPlayerService to play audio even when the app is dead.
 *
 * 2. BOOT_COMPLETED / MY_PACKAGE_REPLACED — reschedules AlarmManager alarms
 *    from the schedule persisted in SharedPreferences so alarms survive reboots.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE   = "com.nooraliman.quran.ADHAN_FIRE"
        private const val TAG         = "AdhanAlarmReceiver"
        private const val PREFS_NAME  = "FlutterSharedPreferences"
        private const val KEY_ENABLED       = "flutter.adhan_notifications_enabled"
        private const val KEY_SOUND          = "flutter.selected_adhan_sound"
        private const val KEY_SCHEDULE       = "flutter.adhan_schedule_preview"
        private const val KEY_SHORT_MODE     = "flutter.adhan_short_mode"
        private const val KEY_SHORT_CUTOFF   = "flutter.adhan_short_cutoff_seconds"
        private const val KEY_AUDIO_STREAM   = "flutter.adhan_audio_stream"
        private const val KEY_ONLINE_URL     = "flutter.adhan_online_url"
        private const val KEY_ALARM_TIMES    = "flutter.adhan_alarm_times" // JSON map of alarm ID → timeMs

        // ── Prayer-time text notification ────────────────────────────────────
        private const val PRAYER_NOTIF_CHANNEL_ID = "prayer_time_info_v1"
        private const val PRAYER_NOTIF_ID = 9_999 // Unique ID — separate from adhan foreground notification (7777) and fallback (8888)

        // English prayer names keyed by Arabic name
        private val englishPrayerNames = mapOf(
            "الفجر" to "Fajr",
            "الظهر" to "Dhuhr",
            "العصر" to "Asr",
            "المغرب" to "Maghrib",
            "العشاء" to "Isha"
        )

        // Motivational quotes — Arabic
        private val motivationalAr = listOf(
            "أقِم صلاتك تجد راحة قلبك 🕌",
            "الصلاة نور، فلا تُطفئ نورك 🌟",
            "حيّ على الصلاة.. حيّ على الفلاح 🤲",
            "إن الصلاة كانت على المؤمنين كتاباً موقوتاً 📖",
            "الصلاة عماد الدين، فحافظ عليها 💪",
            "بين العبد والكفر ترك الصلاة، فأقمها 🕋",
            "أقرب ما يكون العبد من ربه وهو ساجد 🤲",
            "الصلاة خير موضوع، فأكثر أو أقل 🌙",
            "من حافظ عليها كانت له نوراً يوم القيامة 🌟",
            "فاستبقوا الخيرات 🏃"
        )

        // Motivational quotes — English
        private val motivationalEn = listOf(
            "Establish your prayer and find peace of heart 🕌",
            "Prayer is light — don't extinguish yours 🌟",
            "Come to prayer.. Come to success 🤲",
            "Indeed, prayer has been decreed upon the believers at fixed times 📖",
            "Prayer is the pillar of the religion — guard it 💪",
            "The closest a servant is to his Lord is when prostrating 🤲",
            "Race to all that is good 🏃",
            "Prayer is the best deed, so increase in it 🌙",
            "Whoever guards their prayer, it will be a light for them 🌟",
            "Verily, in the remembrance of Allah do hearts find rest 🕋"
        )

        /**
         * Schedule a list of alarms via AlarmManager.
         *
         * @param alarms  List of maps each with "id" (Int) and "timeMs" (Long).
         * @param soundName  The raw resource name (e.g. "adhan_1").
         */
        fun scheduleAlarms(context: Context, alarms: List<Map<String, Any>>, soundName: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            var count = 0
            // Build a map of alarm ID → timeMs for later retrieval when alarms fire
            val alarmTimesMap = mutableMapOf<String, Long>()
            for (alarm in alarms) {
                val id     = (alarm["id"]     as? Number)?.toInt()  ?: continue
                val timeMs = (alarm["timeMs"] as? Number)?.toLong() ?: continue
                if (timeMs <= now) continue
                val arabicName = alarm["arabicName"] as? String ?: ""
                alarmTimesMap[id.toString()] = timeMs // Store for later retrieval
                val pi = pendingIntentFor(context, id, soundName, arabicName)
                setExactAlarm(context, am, timeMs, pi)
                count++
            }
            // Persist the alarm times map to SharedPreferences
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_ALARM_TIMES, JSONObject(alarmTimesMap).toString()).apply()
            Log.d(TAG, "Scheduled $count alarm(s) and stored times")
        }

        /**
         * Cancel a list of previously scheduled alarms by their IDs.
         */
        fun cancelAlarms(context: Context, ids: List<Int>) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) {
                // The Intent MUST have the same action as the one used in pendingIntentFor().
                // Android matches PendingIntents by action (among other fields); without it
                // FLAG_NO_CREATE returns null and the alarm is never cancelled.
                val pi = PendingIntent.getBroadcast(
                    context, id,
                    Intent(context, AdhanAlarmReceiver::class.java).apply {
                        action = ACTION_FIRE
                    },
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                ) ?: continue
                am.cancel(pi)
                pi.cancel()
            }
            Log.d(TAG, "Cancelled ${ids.size} alarm(s)")
        }

        // ── Helpers ───────────────────────────────────────────────────────────

        private fun pendingIntentFor(context: Context, id: Int, soundName: String,
                                       arabicName: String = ""): PendingIntent {
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra("alarmId", id) // Pass alarm ID for later retrieval of prayer time
                putExtra("soundName", soundName)
                if (arabicName.isNotEmpty()) putExtra("arabicName", arabicName)
            }
            return PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun setExactAlarm(context: Context, am: AlarmManager, timeMs: Long, pi: PendingIntent) {
            // setAlarmClock() has the HIGHEST system priority — fires exactly on time even in
            // deep Doze mode and grants explicit permission to start foreground services from
            // background at fire time. Never batched or delayed by any OEM battery manager.
            val showIntent = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.setAlarmClock(AlarmManager.AlarmClockInfo(timeMs, showIntent), pi)
        }

        /** Parse Flutter ISO local datetime string → epoch millis. */
        private fun parseIsoToMillis(iso: String): Long? {
            return try {
                // Flutter DateTime.toLocal().toIso8601String() → "2026-02-21T05:30:00.000000"
                val ldt = LocalDateTime.parse(iso.take(19)) // trim to "yyyy-MM-dd'T'HH:mm:ss"
                ldt.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            } catch (e: Exception) {
                Log.w(TAG, "Cannot parse time: $iso — ${e.message}")
                null
            }
        }
    }

    // ── BroadcastReceiver ────────────────────────────────────────────────────

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FIRE                            -> handleFire(context, intent)
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> handleBoot(context)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "Time/timezone changed — rescheduling adhan alarms")
                handleBoot(context)
            }
        }
    }

    // ── Fire ─────────────────────────────────────────────────────────────────

    private fun handleFire(context: Context, intent: Intent) {
        // Safety check: don't play if the user has disabled Adhan notifications.
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_ENABLED, true)
        if (!enabled) {
            Log.d(TAG, "Adhan disabled — ignoring alarm fire")
            return
        }
        val alarmId     = intent.getIntExtra("alarmId", -1)
        val soundName   = intent.getStringExtra("soundName") ?: "adhan_1"
        val arabicName  = intent.getStringExtra("arabicName") ?: ""

        // Write a "fired" marker for reliability-test alarms (ID ≥ 990000)
        if (alarmId >= 990000) {
            prefs.edit().putString(
                "flutter.adhan_test_fired_$alarmId",
                System.currentTimeMillis().toString()
            ).apply()
            Log.d(TAG, "Wrote test-fired marker for alarm $alarmId")
        }
        val shortMode   = prefs.getBoolean(KEY_SHORT_MODE, false)
        val shortCutoff = prefs.getInt(KEY_SHORT_CUTOFF, 15)
        val useAlarm    = prefs.getString(KEY_AUDIO_STREAM, "alarm") != "ringtone"
        val onlineUrl   = prefs.getString(KEY_ONLINE_URL, "")?.takeIf { it.isNotBlank() }
        val forceSpeaker = prefs.getBoolean("flutter.adhan_force_speaker", false)
        
        // Retrieve the prayer time from SharedPreferences
        var prayerTimeMs = 0L
        val alarmTimesJson = prefs.getString(KEY_ALARM_TIMES, "{}") ?: "{}"
        try {
            val alarmTimesMap = JSONObject(alarmTimesJson)
            prayerTimeMs = alarmTimesMap.optLong("${alarmId}", 0L)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse alarm times: ${e.message}")
        }
        
        // Determine display language
        val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"
        val englishName = englishPrayerNames[arabicName] ?: "Prayer"

        // Format the prayer time for display (e.g., "5:30 AM").
        // timeDisplay uses Arabic locale — kept for postPrayerTimeNotification which re-parses it internally.
        val timeDisplay = if (prayerTimeMs > 0) {
            val formatter = SimpleDateFormat("h:mm a", Locale("ar"))
            formatter.format(Date(prayerTimeMs))
        } else {
            ""
        }
        // Localized time for the foreground player notification.
        val localizedTimeDisplay = if (prayerTimeMs > 0) {
            val locale = if (isArabic) Locale("ar") else Locale.ENGLISH
            SimpleDateFormat("h:mm a", locale).format(Date(prayerTimeMs))
        } else {
            ""
        }

        Log.d(TAG, "Adhan alarm fired: $soundName (shortMode=$shortMode, cutoff=${shortCutoff}s, alarmStream=$useAlarm, time=$timeDisplay)")
        val serviceIntent = Intent(context, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND, soundName)
            putExtra(AdhanPlayerService.EXTRA_SHORT_MODE, shortMode)
            putExtra(AdhanPlayerService.EXTRA_SHORT_CUTOFF_SECONDS, shortCutoff)
            putExtra(AdhanPlayerService.EXTRA_USE_ALARM_STREAM, useAlarm)
            putExtra(AdhanPlayerService.EXTRA_FORCE_SPEAKER, forceSpeaker)
            if (onlineUrl != null) putExtra(AdhanPlayerService.EXTRA_ONLINE_URL, onlineUrl)
            if (arabicName.isNotEmpty()) {
                val notifTitle = if (isArabic) "أذان $arabicName" else "Adhan – $englishName"
                val notifBody = if (isArabic) {
                    if (localizedTimeDisplay.isNotEmpty()) "$localizedTimeDisplay - اضغط لإيقاف الأذان"
                    else "اضغط لإيقاف الأذان"
                } else {
                    if (localizedTimeDisplay.isNotEmpty()) "$localizedTimeDisplay – Tap to stop"
                    else "Tap to stop"
                }
                val stopLabel = if (isArabic) "إيقاف الأذان" else "Stop Adhan"
                putExtra(AdhanPlayerService.EXTRA_NOTIF_TITLE, notifTitle)
                putExtra(AdhanPlayerService.EXTRA_NOTIF_BODY, notifBody)
                putExtra(AdhanPlayerService.EXTRA_STOP_LABEL, stopLabel)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                context.startForegroundService(serviceIntent)
            } catch (e: Exception) {
                Log.e(TAG, "startForegroundService failed — posting fallback notification", e)
                postFallbackNotification(context, arabicName, timeDisplay)
            }
        } else {
            context.startService(serviceIntent)
        }

        // Post a separate persistent text notification alongside the adhan audio.
        // This stays visible after the adhan player stops so the user can confirm
        // that the adhan fired even if they were asleep or in a noisy place.
        postPrayerTimeNotification(context, arabicName, timeDisplay)
    }

    // ── Prayer-time info notification ──────────────────────────────────────

    /**
     * Posts a separate, auto-dismissable text notification that tells the user
     * which prayer time has arrived, the clock time, and a motivational quote.
     *
     * This notification is independent of the foreground adhan player notification
     * and remains visible after the adhan audio stops — confirming to the user that
     * the adhan did fire even if they were asleep or in a noisy environment.
     *
     * Supports Arabic and English based on the app language setting.
     * Uses the app logo (Splash_dark_transparent.png) as the large icon.
     */
    private fun postPrayerTimeNotification(context: Context, arabicName: String, timeDisplay: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"

            // ── Create / ensure notification channel (Android 8+) ──
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channelName = if (isArabic) "إشعار وقت الصلاة" else "Prayer Time Alert"
                val channelDesc = if (isArabic) "إشعار نصّي عند حلول وقت كل صلاة" else "Text notification when each prayer time arrives"
                val ch = NotificationChannel(
                    PRAYER_NOTIF_CHANNEL_ID, channelName,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = channelDesc
                    setShowBadge(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableVibration(true)
                }
                nm.createNotificationChannel(ch)
            }

            // ── Build title ──
            val englishName = englishPrayerNames[arabicName] ?: "Prayer"
            val title = if (isArabic) {
                "🕌 حان الآن موعد صلاة $arabicName"
            } else {
                "🕌 It's time for $englishName prayer"
            }

            // ── Build body: prayer time + motivational quote ──
            // Use a persistent counter so the quote genuinely changes every prayer.
            val quotes = if (isArabic) motivationalAr else motivationalEn
            val counterKey = "flutter.prayer_notif_quote_counter"
            val counter = prefs.getInt(counterKey, 0)
            val quote = quotes[counter % quotes.size]
            prefs.edit().putInt(counterKey, counter + 1).apply()

            val body = buildString {
                if (timeDisplay.isNotEmpty()) {
                    if (isArabic) {
                        append("⏰ الساعة $timeDisplay")
                    } else {
                        // Format time in English locale
                        val englishTime = try {
                            // Re-parse from the Arabic time string and format in English
                            val arFormatter = SimpleDateFormat("h:mm a", Locale("ar"))
                            val date = arFormatter.parse(timeDisplay)
                            val enFormatter = SimpleDateFormat("h:mm a", Locale.ENGLISH)
                            if (date != null) enFormatter.format(date) else timeDisplay
                        } catch (_: Exception) { timeDisplay }
                        append("⏰ $englishTime")
                    }
                    append("\n")
                }
                append(quote)
            }

            // ── Load app logo as large icon ──
            val largeIcon: Bitmap? = try {
                context.assets.open("flutter_assets/assets/logo/files/transparent/Splash_dark_transparent.png").use { input ->
                    BitmapFactory.decodeStream(input)
                }
            } catch (_: Exception) {
                // Fallback: try mosque.jpg
                try {
                    context.assets.open("flutter_assets/assets/logo/files/mosque.jpg").use { input ->
                        BitmapFactory.decodeStream(input)
                    }
                } catch (_: Exception) { null }
            }

            // ── Small icon — must be a monochrome drawable for Android 15 ──
            val smallIconRes = context.resources.getIdentifier("ic_notification", "drawable", context.packageName)
                .takeIf { it != 0 } ?: android.R.drawable.ic_lock_idle_alarm

            // ── Open app on tap → navigate to prayer times screen ──
            val openPi = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                it.putExtra("navigate_to", "prayer_times")
                it.addFlags(android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)
                PendingIntent.getActivity(context, 2, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            // ── Build the notification ──
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, PRAYER_NOTIF_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION") Notification.Builder(context)
            }

            builder
                .setSmallIcon(smallIconRes)
                .setContentTitle(title)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setContentText(body.replace('\n', ' '))  // single-line for collapsed view
                .setAutoCancel(true)
                .setColor(0xFF1B5E20.toInt()) // Islamic dark green
                .setVisibility(Notification.VISIBILITY_PUBLIC)

            if (largeIcon != null) builder.setLargeIcon(largeIcon)
            if (openPi != null) builder.setContentIntent(openPi)

            nm.notify(PRAYER_NOTIF_ID, builder.build())
            Log.d(TAG, "Posted prayer-time info notification: $title")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post prayer-time info notification", e)
        }
    }

    private fun postFallbackNotification(context: Context, arabicName: String, timeDisplay: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(
                    "adhan_fallback",
                    if (isArabic) "أذان (احتياطي)" else "Adhan (fallback)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Fallback adhan notification" }
                nm.createNotificationChannel(ch)
            }
            val englishName = englishPrayerNames[arabicName] ?: "Prayer"
            val title = if (isArabic) {
                if (arabicName.isNotEmpty()) "أذان $arabicName" else "حان وقت الصلاة"
            } else {
                if (arabicName.isNotEmpty()) "Adhan – $englishName" else "It's prayer time"
            }
            val body = if (isArabic) {
                if (timeDisplay.isNotEmpty()) timeDisplay else "اضغط لفتح التطبيق"
            } else {
                "Tap to open the app"
            }
            val openPi = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                it.putExtra("navigate_to", "prayer_times")
                it.addFlags(android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }
            val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(context, "adhan_fallback")
            } else {
                @Suppress("DEPRECATION") android.app.Notification.Builder(context)
            }.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .also { b -> openPi?.let { b.setContentIntent(it) } }
                .build()
            nm.notify(8888, notif)
        } catch (e2: Exception) {
            Log.e(TAG, "Fallback notification also failed", e2)
        }
    }

    // ── Boot reschedule ──────────────────────────────────────────────────────

    private fun handleBoot(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, true)
            if (!enabled) {
                Log.d(TAG, "Adhan disabled — skipping boot reschedule")
                return
            }

            val soundName    = prefs.getString(KEY_SOUND, "adhan_1") ?: "adhan_1"
            val scheduleJson = prefs.getString(KEY_SCHEDULE, null) ?: run {
                Log.d(TAG, "No schedule in prefs — cannot reschedule after boot")
                return
            }

            val jsonArray = JSONArray(scheduleJson)
            val alarms    = mutableListOf<Map<String, Any>>()
            val now       = System.currentTimeMillis()

            for (i in 0 until jsonArray.length()) {
                val item   = jsonArray.getJSONObject(i)
                val id     = item.optInt("id", -1)
                val timeStr = item.optString("time", "")
                if (id < 0 || timeStr.isEmpty()) continue
                val timeMs = parseIsoToMillis(timeStr) ?: continue
                if (timeMs <= now) continue
                val prayer = item.optString("prayer", "")
                val arabicName = when (prayer) {
                    "fajr"    -> "الفجر"
                    "dhuhr"   -> "الظهر"
                    "asr"     -> "العصر"
                    "maghrib" -> "المغرب"
                    "isha"    -> "العشاء"
                    else      -> item.optString("label", "")
                }
                alarms.add(mapOf("id" to id, "timeMs" to timeMs, "arabicName" to arabicName))
            }

            scheduleAlarms(context, alarms, soundName)
            Log.d(TAG, "Boot reschedule complete: ${alarms.size} alarm(s) re-armed")
        } catch (e: Exception) {
            Log.e(TAG, "Boot reschedule failed", e)
        }
    }
}
