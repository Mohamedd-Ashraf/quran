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
 * BroadcastReceiver for iqama (قد قامت الصلاة) alarms.
 *
 * Triggered by AlarmManager at iqama time — starts AdhanPlayerService with the
 * full iqama sound (iqama_sound_full) and shortMode=false so nothing is cut off.
 *
 * Also handles BOOT_COMPLETED to reschedule iqama alarms after a reboot.
 */
class IqamaAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE   = "com.example.quraan.IQAMA_FIRE"
        private const val TAG         = "IqamaAlarmReceiver"
        private const val PREFS_NAME  = "FlutterSharedPreferences"
        private const val KEY_ENABLED       = "flutter.iqama_enabled"
        private const val KEY_SCHEDULE      = "flutter.iqama_schedule_json"
        private const val SOUND_NAME        = "iqama_sound_new"  // updated to new iqama recording

        /**
         * Schedule a list of iqama alarms via AlarmManager.
         *
         * @param alarms  List of maps each with "id" (Int), "timeMs" (Long),
         *                "title" (String) and "body" (String).
         */
        fun scheduleAlarms(context: Context, alarms: List<Map<String, Any>>) {
            val am  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            var count = 0
            for (alarm in alarms) {
                val id     = (alarm["id"]     as? Number)?.toInt()  ?: continue
                val timeMs = (alarm["timeMs"] as? Number)?.toLong() ?: continue
                val title  = alarm["title"]  as? String ?: "إقامة الصلاة"
                val body   = alarm["body"]   as? String ?: "حان وقت الإقامة"
                if (timeMs <= now) continue
                val pi = pendingIntentFor(context, id, title, body)
                setExactAlarm(context, am, timeMs, pi)
                count++
            }
            Log.d(TAG, "Iqama: scheduled $count alarm(s)")
        }

        /** Cancel a list of previously scheduled iqama alarms by their IDs. */
        fun cancelAlarms(context: Context, ids: List<Int>) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) {
                val pi = PendingIntent.getBroadcast(
                    context, id + 50_000, // offset to avoid collision with adhan IDs
                    Intent(context, IqamaAlarmReceiver::class.java).apply {
                        action = ACTION_FIRE
                    },
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                ) ?: continue
                am.cancel(pi)
                pi.cancel()
            }
            Log.d(TAG, "Iqama: cancelled ${ids.size} alarm(s)")
        }

        // ── Helpers ─────────────────────────────────────────────────────────

        private fun pendingIntentFor(
            context: Context, id: Int, title: String, body: String
        ): PendingIntent {
            val intent = Intent(context, IqamaAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra("title", title)
                putExtra("body",  body)
            }
            return PendingIntent.getBroadcast(
                context, id + 50_000, // offset to avoid collision with adhan IDs
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
            Log.d(TAG, "Iqama disabled — ignoring alarm fire")
            return
        }

        val title = intent.getStringExtra("title") ?: "إقامة الصلاة"
        val body  = intent.getStringExtra("body")  ?: "حان وقت الإقامة"

        Log.d(TAG, "Iqama alarm fired — starting player: $SOUND_NAME")

        // Use the same alarm/ringtone stream as the user selected for the adhan.
        val useAlarmStream = prefs.getString("flutter.adhan_audio_stream", "ringtone") == "alarm"

        val serviceIntent = Intent(context, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND,                  SOUND_NAME)
            putExtra(AdhanPlayerService.EXTRA_SHORT_MODE,             false)   // play full sound — never cut off
            putExtra(AdhanPlayerService.EXTRA_USE_ALARM_STREAM,       useAlarmStream)
            putExtra(AdhanPlayerService.EXTRA_DISABLE_VOLUME_STOPPER, true)    // don't kill on volume key — use notification button
            putExtra(AdhanPlayerService.EXTRA_NOTIF_TITLE,            title)
            putExtra(AdhanPlayerService.EXTRA_NOTIF_BODY,             body)
            putExtra(AdhanPlayerService.EXTRA_STOP_LABEL,             "إيقاف الإقامة")
            putExtra(AdhanPlayerService.EXTRA_VOLUME_KEY,             "flutter.iqama_volume")
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
                Log.d(TAG, "Iqama disabled — skipping boot reschedule")
                return
            }

            val scheduleJson = prefs.getString(KEY_SCHEDULE, null) ?: run {
                Log.d(TAG, "No iqama schedule in prefs — cannot reschedule after boot")
                return
            }

            val jsonArray = JSONArray(scheduleJson)
            val alarms    = mutableListOf<Map<String, Any>>()
            val now       = System.currentTimeMillis()

            for (i in 0 until jsonArray.length()) {
                val item   = jsonArray.getJSONObject(i)
                val id     = item.optInt("id", -1)
                val timeMs = item.optLong("timeMs", -1L)
                val title  = item.optString("title", "إقامة الصلاة")
                val body   = item.optString("body",  "حان وقت الإقامة")
                if (id < 0 || timeMs <= 0 || timeMs <= now) continue
                alarms.add(mapOf("id" to id, "timeMs" to timeMs, "title" to title, "body" to body))
            }

            scheduleAlarms(context, alarms)
            Log.d(TAG, "Iqama boot reschedule: ${alarms.size} alarm(s) re-armed")
        } catch (e: Exception) {
            Log.e(TAG, "Iqama boot reschedule failed", e)
        }
    }
}
