package com.example.quraan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * BroadcastReceiver for pre-prayer approaching reminders (تنبيه ما قبل الصلاة).
 *
 * Triggered by AlarmManager N minutes before a prayer — starts AdhanPlayerService with
 * the prayer-specific reminder sound so the volume slider actually controls the level
 * (unlike flutter_local_notifications channel sounds which are system-volume-locked).
 *
 * Uses ALARM audio stream → plays even in Silent / Vibrate mode, same as adhan.
 * Also handles BOOT_COMPLETED to reschedule alarms after a reboot.
 */
class ApproachingAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE    = "com.example.quraan.APPROACHING_FIRE"
        private const val TAG         = "ApproachingAlarmReceiver"
        private const val PREFS_NAME  = "FlutterSharedPreferences"
        private const val KEY_ENABLED  = "flutter.approaching_enabled"
        private const val KEY_SCHEDULE = "flutter.approaching_schedule_json"
        private const val ID_OFFSET    = 100_000  // avoid collision with adhan (0) and iqama (50_000)

        /**
         * Schedule a list of approaching-reminder alarms via AlarmManager.
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
                val title  = alarm["title"]  as? String ?: "تنبيه الصلاة"
                val body   = alarm["body"]   as? String ?: "اقتربت الصلاة"
                val sound  = alarm["sound"]  as? String ?: "prayer_reminder_fajr"
                if (timeMs <= now) continue
                val pi = pendingIntentFor(context, id, title, body, sound)
                setExactAlarm(context, am, timeMs, pi)
                count++
            }
            Log.d(TAG, "Approaching: scheduled $count alarm(s)")
        }

        /** Cancel a list of previously scheduled approaching alarms by their IDs. */
        fun cancelAlarms(context: Context, ids: List<Int>) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) {
                val pi = PendingIntent.getBroadcast(
                    context, id + ID_OFFSET,
                    Intent(context, ApproachingAlarmReceiver::class.java).apply {
                        action = ACTION_FIRE
                    },
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                ) ?: continue
                am.cancel(pi)
                pi.cancel()
            }
            Log.d(TAG, "Approaching: cancelled ${ids.size} alarm(s)")
        }

        // ── Helpers ─────────────────────────────────────────────────────────

        private fun pendingIntentFor(
            context: Context, id: Int, title: String, body: String, sound: String
        ): PendingIntent {
            val intent = Intent(context, ApproachingAlarmReceiver::class.java).apply {
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
        }
    }

    // ── Fire ──────────────────────────────────────────────────────────────

    private fun handleFire(context: Context, intent: Intent) {
        val prefs   = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_ENABLED, false)
        if (!enabled) {
            Log.d(TAG, "Approaching reminder disabled — ignoring alarm fire")
            return
        }

        val title = intent.getStringExtra("title") ?: "تنبيه الصلاة"
        val body  = intent.getStringExtra("body")  ?: "اقتربت الصلاة"
        val sound = intent.getStringExtra("sound") ?: "prayer_reminder_fajr"

        // Use the same alarm/ringtone stream as the user selected for the adhan.
        val useAlarmStream = prefs.getString("flutter.adhan_audio_stream", "ringtone") == "alarm"

        Log.d(TAG, "Approaching alarm fired — stream=${if (useAlarmStream) "alarm" else "ringtone"}, sound=$sound")

        val serviceIntent = Intent(context, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND,                  sound)
            putExtra(AdhanPlayerService.EXTRA_SHORT_MODE,             false)
            putExtra(AdhanPlayerService.EXTRA_USE_ALARM_STREAM,       useAlarmStream)
            putExtra(AdhanPlayerService.EXTRA_DISABLE_VOLUME_STOPPER, true)    // don't kill on volume key
            putExtra(AdhanPlayerService.EXTRA_NOTIF_TITLE,            title)
            putExtra(AdhanPlayerService.EXTRA_NOTIF_BODY,             body)
            putExtra(AdhanPlayerService.EXTRA_STOP_LABEL,             "إيقاف التذكير")
            putExtra(AdhanPlayerService.EXTRA_VOLUME_KEY,             "flutter.approaching_volume")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    // ── Boot reschedule ───────────────────────────────────────────────────

    private fun handleBoot(context: Context) {
        try {
            val prefs   = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, false)
            if (!enabled) {
                Log.d(TAG, "Approaching reminder disabled — skipping boot reschedule")
                return
            }

            val scheduleJson = prefs.getString(KEY_SCHEDULE, null) ?: run {
                Log.d(TAG, "No approaching schedule in prefs — cannot reschedule after boot")
                return
            }

            val jsonArray = JSONArray(scheduleJson)
            val alarms    = mutableListOf<Map<String, Any>>()
            val now       = System.currentTimeMillis()

            for (i in 0 until jsonArray.length()) {
                val item   = jsonArray.getJSONObject(i)
                val id     = item.optInt("id", -1)
                val timeMs = item.optLong("timeMs", -1L)
                val title  = item.optString("title", "تنبيه الصلاة")
                val body   = item.optString("body",  "اقتربت الصلاة")
                val sound  = item.optString("sound", "prayer_reminder_fajr")
                if (id < 0 || timeMs <= 0 || timeMs <= now) continue
                alarms.add(mapOf("id" to id, "timeMs" to timeMs, "title" to title, "body" to body, "sound" to sound))
            }

            scheduleAlarms(context, alarms)
            Log.d(TAG, "Boot: rescheduled ${alarms.size} approaching alarm(s)")
        } catch (e: Exception) {
            Log.e(TAG, "Boot reschedule failed", e)
        }
    }
}
