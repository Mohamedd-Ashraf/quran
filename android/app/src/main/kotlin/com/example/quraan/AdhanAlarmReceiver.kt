package com.example.quraan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import java.time.LocalDateTime
import java.time.ZoneId

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
        const val ACTION_FIRE   = "com.example.quraan.ADHAN_FIRE"
        private const val TAG         = "AdhanAlarmReceiver"
        private const val PREFS_NAME  = "FlutterSharedPreferences"
        private const val KEY_ENABLED  = "flutter.adhan_notifications_enabled"
        private const val KEY_SOUND    = "flutter.selected_adhan_sound"
        private const val KEY_SCHEDULE = "flutter.adhan_schedule_preview"

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
            for (alarm in alarms) {
                val id     = (alarm["id"]     as? Number)?.toInt()  ?: continue
                val timeMs = (alarm["timeMs"] as? Number)?.toLong() ?: continue
                if (timeMs <= now) continue

                val pi = pendingIntentFor(context, id, soundName)
                setExactAlarm(am, timeMs, pi)
                count++
            }
            Log.d(TAG, "Scheduled $count alarm(s)")
        }

        /**
         * Cancel a list of previously scheduled alarms by their IDs.
         */
        fun cancelAlarms(context: Context, ids: List<Int>) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) {
                val pi = PendingIntent.getBroadcast(
                    context, id,
                    Intent(context, AdhanAlarmReceiver::class.java),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                ) ?: continue
                am.cancel(pi)
                pi.cancel()
            }
            Log.d(TAG, "Cancelled ${ids.size} alarm(s)")
        }

        // ── Helpers ───────────────────────────────────────────────────────────

        private fun pendingIntentFor(context: Context, id: Int, soundName: String): PendingIntent {
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra("soundName", soundName)
            }
            return PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun setExactAlarm(am: AlarmManager, timeMs: Long, pi: PendingIntent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
                } catch (e: SecurityException) {
                    // Fallback if user revoked SCHEDULE_EXACT_ALARM
                    am.set(AlarmManager.RTC_WAKEUP, timeMs, pi)
                }
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, timeMs, pi)
            }
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
        }
    }

    // ── Fire ─────────────────────────────────────────────────────────────────

    private fun handleFire(context: Context, intent: Intent) {
        val soundName = intent.getStringExtra("soundName") ?: "adhan_1"
        Log.d(TAG, "Adhan alarm fired: $soundName")
        val serviceIntent = Intent(context, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND, soundName)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
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
                alarms.add(mapOf("id" to id, "timeMs" to timeMs))
            }

            scheduleAlarms(context, alarms, soundName)
            Log.d(TAG, "Boot reschedule complete: ${alarms.size} alarm(s) re-armed")
        } catch (e: Exception) {
            Log.e(TAG, "Boot reschedule failed", e)
        }
    }
}
