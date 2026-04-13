package com.nooraliman.quran

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * BroadcastReceiver for Salawat (الصلاة على النبي) periodic reminders.
 *
 * Triggered by AlarmManager at each scheduled salawat time — starts AdhanPlayerService
 * with the user-selected salawat sound so the app volume slider actually controls the
 * playback level (unlike flutter_local_notifications channel sounds which are
 * system-volume-locked and cannot be individually controlled).
 *
 * Also handles BOOT_COMPLETED to reschedule alarms after a reboot.
 */
class SalawatAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE    = "com.nooraliman.quran.SALAWAT_FIRE"
        private const val TAG         = "SalawatAlarmReceiver"
        private const val PREFS_NAME  = "FlutterSharedPreferences"
        private const val KEY_ENABLED  = "flutter.salawat_enabled"
        private const val KEY_SCHEDULE = "flutter.salawat_schedule_json"
        private const val ID_OFFSET    = 150_000  // avoid collision: adhan(0), iqama(50k), approaching(100k)

        /**
         * Schedule a list of salawat alarms via AlarmManager.
         *
         * @param alarms  List of maps each with "id" (Int), "timeMs" (Long),
         *                "title" (String), "body" (String), "sound" (String).
         */
        fun scheduleAlarms(context: Context, alarms: List<Map<String, Any>>) {
            val am  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            var count = 0
            for (alarm in alarms) {
                val id     = (alarm["id"]     as? Number)?.toInt()  ?: continue
                val timeMs = (alarm["timeMs"] as? Number)?.toLong() ?: continue
                val title  = alarm["title"]  as? String ?: "الصلاة على النبي"
                val body   = alarm["body"]   as? String ?: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ"
                val sound  = alarm["sound"]  as? String ?: "salawat_1"
                if (timeMs <= now) continue
                val pi = pendingIntentFor(context, id, title, body, sound)
                setExactAlarm(context, am, timeMs, pi)
                count++
            }
            Log.d(TAG, "Salawat: scheduled $count alarm(s)")
        }

        /** Cancel a list of previously scheduled salawat alarms by their IDs. */
        fun cancelAlarms(context: Context, ids: List<Int>) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) {
                val pi = PendingIntent.getBroadcast(
                    context, id + ID_OFFSET,
                    Intent(context, SalawatAlarmReceiver::class.java).apply {
                        action = ACTION_FIRE
                    },
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                ) ?: continue
                am.cancel(pi)
                pi.cancel()
            }
            Log.d(TAG, "Salawat: cancelled ${ids.size} alarm(s)")
        }

        // ── Helpers ─────────────────────────────────────────────────────────

        private fun pendingIntentFor(
            context: Context, id: Int, title: String, body: String, sound: String
        ): PendingIntent {
            val intent = Intent(context, SalawatAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra("title", title)
                putExtra("body",  body)
                putExtra("sound", sound)
            }
            return PendingIntent.getBroadcast(
                context, id + ID_OFFSET,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun setExactAlarm(context: Context, am: AlarmManager, timeMs: Long, pi: PendingIntent) {
            // setAlarmClock() grants the highest scheduling priority and permission to
            // start foreground services from background at fire time.
            val showIntent = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.setAlarmClock(AlarmManager.AlarmClockInfo(timeMs, showIntent), pi)
        }
    }

    // ── BroadcastReceiver ──────────────────────────────────────────────────

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FIRE                            -> handleFire(context, intent)
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> handleBoot(context)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "Time/timezone changed — rescheduling salawat alarms")
                handleBoot(context)
            }
        }
    }

    // ── Fire ──────────────────────────────────────────────────────────────

    private fun handleFire(context: Context, intent: Intent) {
        val prefs   = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_ENABLED, false)
        if (!enabled) {
            Log.d(TAG, "Salawat disabled — ignoring alarm fire")
            return
        }

        val title = intent.getStringExtra("title") ?: "🌙 الصلاة على النبي"
        val body  = intent.getStringExtra("body")  ?: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ"
        val sound = intent.getStringExtra("sound") ?: "salawat_1"

        // Use the same alarm/ringtone stream as the user selected for the adhan.
        val useAlarmStream = prefs.getString("flutter.adhan_audio_stream", "alarm") != "ringtone"

        Log.d(TAG, "Salawat alarm fired — stream=${if (useAlarmStream) "alarm" else "ringtone"}, sound=$sound")

        val serviceIntent = Intent(context, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND,                  sound)
            putExtra(AdhanPlayerService.EXTRA_SHORT_MODE,             false)
            putExtra(AdhanPlayerService.EXTRA_USE_ALARM_STREAM,       useAlarmStream)
            putExtra(AdhanPlayerService.EXTRA_DISABLE_VOLUME_STOPPER, true)    // don't kill on volume key
            putExtra(AdhanPlayerService.EXTRA_NOTIF_TITLE,            title)
            putExtra(AdhanPlayerService.EXTRA_NOTIF_BODY,             body)
            putExtra(AdhanPlayerService.EXTRA_STOP_LABEL,             "إيقاف الصلاة على النبي")
            putExtra(AdhanPlayerService.EXTRA_VOLUME_KEY,             "flutter.salawat_volume")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                context.startForegroundService(serviceIntent)
            } catch (e: Exception) {
                Log.e(TAG, "startForegroundService failed — posting fallback notification", e)
                postFallbackNotification(context, title, body)
            }
        } else {
            context.startService(serviceIntent)
        }

        // Self-renewal: when fewer than 5 alarms remain, schedule the next batch
        // so salawat never stops even if the app isn't opened for a long time.
        autoRenewIfNeeded(context)
    }

    private fun postFallbackNotification(context: Context, title: String, body: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(
                    "salawat_fallback", "صلاة على النبي (احتياطي)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Fallback salawat notification" }
                nm.createNotificationChannel(ch)
            }
            val openPi = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }
            val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(context, "salawat_fallback")
            } else {
                @Suppress("DEPRECATION") android.app.Notification.Builder(context)
            }.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .also { b -> openPi?.let { b.setContentIntent(it) } }
                .build()
            nm.notify(8891, notif)
        } catch (e2: Exception) {
            Log.e(TAG, "Fallback notification also failed", e2)
        }
    }

    // ── Auto-renewal ───────────────────────────────────────────────────────

    /**
     * Called after every salawat fire. If fewer than 5 future alarms remain in the
     * stored schedule, generates and registers the next 30 alarms purely from
     * SharedPreferences — no Flutter/Dart runtime needed.
     *
     * This ensures salawat reminders keep firing indefinitely, even if the user
     * hasn't opened the app in weeks.
     */
    private fun autoRenewIfNeeded(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val scheduleJson = prefs.getString(KEY_SCHEDULE, null) ?: return
            val now = System.currentTimeMillis()

            // Count how many scheduled alarms are still in the future.
            val futureCount = try {
                val arr = JSONArray(scheduleJson)
                (0 until arr.length()).count { i -> arr.getJSONObject(i).optLong("timeMs", 0) > now }
            } catch (e: Exception) { return }

            if (futureCount >= 5) return  // Plenty of alarms left — nothing to do.

            // Read user settings from SharedPreferences.
            val intervalMinutes = prefs.getInt("flutter.salawat_minutes", 30)
            if (intervalMinutes <= 0) return
            val sleepEnabled = prefs.getBoolean("flutter.salawat_sleep_enabled", false)
            val sleepStartH  = prefs.getInt("flutter.salawat_sleep_start_h", 22)
            val sleepEndH    = prefs.getInt("flutter.salawat_sleep_end_h", 6)
            val soundName    = prefs.getString("flutter.salawat_sound", "salawat_1") ?: "salawat_1"
            val isArabic     = prefs.getString("flutter.app_language", "ar") == "ar"

            val salawatTexts = if (isArabic) listOf(
                "\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0635\u064e\u0644\u0651\u0650 \u0639\u064e\u0644\u064e\u0649 \u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064d",
                "\u0635\u064e\u0644\u0651\u064e\u0649 \u0627\u0644\u0644\u0647\u064f \u0639\u064e\u0644\u064e\u064a\u0647\u0650 \u0648\u064e\u0633\u064e\u0644\u0651\u064e\u0645\u064e",
                "\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0635\u064e\u0644\u0651\u0650 \u0648\u064e\u0633\u064e\u0644\u0651\u0650\u0645\u0652 \u0639\u064e\u0644\u064e\u0649 \u0646\u064e\u0628\u0650\u064a\u0651\u0650\u0646\u064e\u0627 \u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064d"
            ) else listOf(
                "O Allah, send blessings upon Muhammad \u33ba",
                "Peace and blessings be upon the Prophet \u33ba",
                "O Allah, send peace upon our Prophet Muhammad \u33ba"
            )

            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val newAlarms = mutableListOf<Map<String, Any>>()
            var idx = 0

            // Iterate up to 60 steps (2× the target count) to skip sleep-hour slots.
            for (step in 1..60) {
                if (newAlarms.size >= 30) break
                val triggerMs = now + intervalMinutes * 60_000L * step
                if (sleepEnabled) {
                    val h = Calendar.getInstance().apply { timeInMillis = triggerMs }
                                      .get(Calendar.HOUR_OF_DAY)
                    val inSleep = if (sleepStartH > sleepEndH) h >= sleepStartH || h < sleepEndH
                                  else h >= sleepStartH && h < sleepEndH
                    if (inSleep) continue
                }
                // Reuse IDs 700_000_000..700_000_029 — FLAG_UPDATE_CURRENT overwrites
                // any still-pending PendingIntents cleanly.
                val id    = 700_000_000 + idx
                val text  = salawatTexts[idx % salawatTexts.size]
                val title = if (isArabic) "\uD83C\uDF19 \u0627\u0644\u0635\u0644\u0627\u0629 \u0639\u0644\u0649 \u0627\u0644\u0646\u0628\u064a"
                            else "\uD83C\uDF19 Salawat Reminder"
                val pi = PendingIntent.getBroadcast(
                    context, id + ID_OFFSET,
                    Intent(context, SalawatAlarmReceiver::class.java).apply {
                        action = ACTION_FIRE
                        putExtra("title", title)
                        putExtra("body",  text)
                        putExtra("sound", soundName)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setExactAlarm(context, am, triggerMs, pi)
                newAlarms.add(mapOf("id" to id, "timeMs" to triggerMs,
                                    "title" to title, "body" to text, "sound" to soundName))
                idx++
            }

            if (newAlarms.isEmpty()) return

            // Persist renewed schedule so boot reschedule can re-arm after a reboot.
            val newJson = JSONArray().also { arr ->
                newAlarms.forEach { a ->
                    arr.put(JSONObject().apply {
                        put("id",     (a["id"]     as? Number)?.toInt()  ?: 0)
                        put("timeMs", (a["timeMs"] as? Number)?.toLong() ?: 0L)
                        put("title",  a["title"]  as? String ?: "")
                        put("body",   a["body"]   as? String ?: "")
                        put("sound",  a["sound"]  as? String ?: "salawat_1")
                    })
                }
            }.toString()
            prefs.edit().putString(KEY_SCHEDULE, newJson).apply()
            Log.d(TAG, "Auto-renewed salawat: ${newAlarms.size} alarm(s) scheduled every ${intervalMinutes}m")
        } catch (e: Exception) {
            Log.e(TAG, "autoRenewIfNeeded failed", e)
        }
    }

    // ── Boot reschedule ───────────────────────────────────────────────────

    private fun handleBoot(context: Context) {
        try {
            val prefs   = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, false)
            if (!enabled) {
                Log.d(TAG, "Salawat disabled — skipping boot reschedule")
                return
            }

            val scheduleJson = prefs.getString(KEY_SCHEDULE, null) ?: run {
                Log.d(TAG, "No salawat schedule in prefs — cannot reschedule after boot")
                return
            }

            val jsonArray = JSONArray(scheduleJson)
            val alarms    = mutableListOf<Map<String, Any>>()
            val now       = System.currentTimeMillis()

            for (i in 0 until jsonArray.length()) {
                val item   = jsonArray.getJSONObject(i)
                val id     = item.optInt("id", -1)
                val timeMs = item.optLong("timeMs", -1L)
                val title  = item.optString("title", "🌙 الصلاة على النبي")
                val body   = item.optString("body",  "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ")
                val sound  = item.optString("sound", "salawat_1")
                if (id < 0 || timeMs <= 0 || timeMs <= now) continue
                alarms.add(mapOf("id" to id, "timeMs" to timeMs, "title" to title, "body" to body, "sound" to sound))
            }

            scheduleAlarms(context, alarms)
            Log.d(TAG, "Boot: rescheduled ${alarms.size} salawat alarm(s)")
        } catch (e: Exception) {
            Log.e(TAG, "Boot reschedule failed", e)
        }
    }
}
