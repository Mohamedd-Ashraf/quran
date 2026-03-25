package com.example.quraan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * BroadcastReceiver that silences the phone during prayer time.
 *
 * Two actions:
 *   ACTION_SILENT_START — triggered at (prayer_time + delay_minutes): silences the phone.
 *   ACTION_SILENT_END   — triggered at (prayer_time + delay_minutes + duration_minutes):
 *                         restores the original ringer mode.
 *
 * Also handles BOOT_COMPLETED / time-change events to reschedule from persisted JSON.
 *
 * ── Overlap handling (e.g. Maghrib end overlaps Isha start) ───────────────────
 * Uses an INT counter (KEY_ACTIVE_COUNT) instead of a boolean flag so that
 * overlapping START/END pairs never restore the ringer too early.
 * Rule: silence when count 0→1; restore when count 1→0.
 *
 * ── ID offset scheme (prevents PendingIntent collisions) ─────────────────────
 * Base adhan IDs are ~202_000_000.  +200_000 / +250_000 offsets push us to
 * ~202_200_000 / ~202_250_000 — still far from all other receivers ranges
 * (iqama: 600M+50k, approaching: 300M+100k, salawat: unique IDs+150k).
 */
class SilentModeAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_SILENT_START = "com.example.quraan.SILENT_MODE_START"
        const val ACTION_SILENT_END   = "com.example.quraan.SILENT_MODE_END"

        private const val TAG        = "SilentModeReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        // SharedPreference keys (flutter. prefix for consistency with Dart prefs).
        const val KEY_ENABLED       = "flutter.silent_during_prayer"
        private const val KEY_ORIG_RINGER  = "flutter.silent_original_ringer"
        /** How many START alarms have fired without a matching END. 0 = not silencing. */
        private const val KEY_ACTIVE_COUNT = "flutter.silent_active_count"
        const val KEY_SCHEDULE      = "flutter.silent_alarm_ids"

        const val OFFSET_START = 200_000
        const val OFFSET_END   = 250_000

        // ── Public API ──────────────────────────────────────────────────────

        /**
         * Schedule a list of silent-mode alarms via AlarmManager.
         * Each entry needs: "id" (Int), "timeMs" (Long), "isStart" (Boolean).
         */
        fun scheduleAlarms(context: Context, alarms: List<Map<String, Any>>) {
            val am  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            var count = 0
            for (alarm in alarms) {
                val id      = (alarm["id"]      as? Number)?.toInt()  ?: continue
                val timeMs  = (alarm["timeMs"]  as? Number)?.toLong() ?: continue
                val isStart = alarm["isStart"]  as? Boolean           ?: true
                if (timeMs <= now) continue
                val pi = if (isStart) startPendingIntent(context, id)
                         else         endPendingIntent(context, id)
                setExactAlarm(am, timeMs, pi)
                count++
            }
            Log.d(TAG, "Scheduled $count silent-mode alarm(s)")
        }

        /**
         * Cancel both the start and end alarms for each base ID.
         */
        fun cancelAlarms(context: Context, ids: List<Int>) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) {
                listOf(
                    startPendingIntentNoCreate(context, id),
                    endPendingIntentNoCreate(context, id),
                ).forEach { pi ->
                    if (pi != null) {
                        am.cancel(pi)
                        pi.cancel()
                    }
                }
            }
            Log.d(TAG, "Cancelled silent-mode alarms for ${ids.size} base ID(s)")
        }

        /**
         * Immediately restore the ringer and reset internal state.
         * Called from MainActivity when user disables the feature or disables adhan.
         * Safe to call even when phone is not currently silenced by us.
         */
        fun restoreNow(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val count = prefs.getInt(KEY_ACTIVE_COUNT, 0)

            // Always reset state so we never leave stale flags.
            prefs.edit().putInt(KEY_ACTIVE_COUNT, 0).apply()

            if (count <= 0) {
                Log.d(TAG, "restoreNow: not active - nothing to do")
                return
            }

            if (!hasDndAccess(context)) {
                Log.w(TAG, "restoreNow: no DND access - state reset but ringer untouched")
                return
            }

            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (am.ringerMode == AudioManager.RINGER_MODE_SILENT) {
                val original = prefs.getInt(KEY_ORIG_RINGER, AudioManager.RINGER_MODE_NORMAL)
                am.ringerMode = original
                Log.d(TAG, "restoreNow: ringer restored to mode $original (count was $count)")
            } else {
                Log.d(TAG, "restoreNow: phone not silent (mode=${am.ringerMode}) - no action")
            }
        }

        // ── Private helpers ─────────────────────────────────────────────────

        private fun startPendingIntent(context: Context, id: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, id + OFFSET_START,
                Intent(context, SilentModeAlarmReceiver::class.java).apply {
                    action = ACTION_SILENT_START
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun endPendingIntent(context: Context, id: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, id + OFFSET_END,
                Intent(context, SilentModeAlarmReceiver::class.java).apply {
                    action = ACTION_SILENT_END
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun startPendingIntentNoCreate(context: Context, id: Int): PendingIntent? =
            PendingIntent.getBroadcast(
                context, id + OFFSET_START,
                Intent(context, SilentModeAlarmReceiver::class.java).apply {
                    action = ACTION_SILENT_START
                },
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )

        private fun endPendingIntentNoCreate(context: Context, id: Int): PendingIntent? =
            PendingIntent.getBroadcast(
                context, id + OFFSET_END,
                Intent(context, SilentModeAlarmReceiver::class.java).apply {
                    action = ACTION_SILENT_END
                },
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )

        /**
         * Use setExactAndAllowWhileIdle() for reliable firing in Doze mode.
         * Falls back to set() if SCHEDULE_EXACT_ALARM was revoked at runtime.
         * Does NOT use setAlarmClock() - avoids showing alarm icon in status bar.
         */
        private fun setExactAlarm(am: AlarmManager, timeMs: Long, pi: PendingIntent) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, timeMs, pi)
                }
            } catch (e: SecurityException) {
                // SCHEDULE_EXACT_ALARM revoked by user - fall back to inexact alarm.
                Log.w(TAG, "Exact alarm permission gone - using inexact fallback: ${e.message}")
                try {
                    am.set(AlarmManager.RTC_WAKEUP, timeMs, pi)
                } catch (e2: Exception) {
                    Log.e(TAG, "Cannot schedule alarm at all: ${e2.message}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "setExactAlarm failed: ${e.message}")
            }
        }

        private fun hasDndAccess(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as android.app.NotificationManager
            return nm.isNotificationPolicyAccessGranted
        }
    }

    // ── BroadcastReceiver ──────────────────────────────────────────────────

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SILENT_START -> handleSilentStart(context)
            ACTION_SILENT_END   -> handleSilentEnd(context)
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> handleBoot(context)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "Time/timezone changed - rescheduling silent mode alarms")
                handleBoot(context)
            }
        }
    }

    // ── Silence ─────────────────────────────────────────────────────────────

    private fun handleSilentStart(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            Log.d(TAG, "Silent mode disabled - ignoring START alarm")
            return
        }
        if (!hasDndAccess(context)) {
            Log.w(TAG, "No DND access permission - cannot silence phone")
            return
        }

        val am      = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prevCnt = prefs.getInt(KEY_ACTIVE_COUNT, 0)

        if (prevCnt <= 0) {
            // First start: record the real ringer mode so we know what to restore.
            val currentMode = am.ringerMode
            prefs.edit()
                .putInt(KEY_ORIG_RINGER, currentMode)
                .putInt(KEY_ACTIVE_COUNT, 1)
                .apply()
            am.ringerMode = AudioManager.RINGER_MODE_SILENT
            Log.d(TAG, "Phone silenced (START, count 0->1, saved mode=$currentMode)")
        } else {
            // Overlapping prayer window: already silent, just increment counter.
            prefs.edit().putInt(KEY_ACTIVE_COUNT, prevCnt + 1).apply()
            Log.d(TAG, "Overlap START: count ${prevCnt}->${prevCnt + 1} (already silent)")
        }
    }

    // ── Restore ─────────────────────────────────────────────────────────────

    private fun handleSilentEnd(context: Context) {
        val prefs   = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val prevCnt = prefs.getInt(KEY_ACTIVE_COUNT, 0)

        if (prevCnt <= 0) {
            // Count already 0 - restoreNow() was called, or we never silenced.
            Log.d(TAG, "Ignoring END: count was already 0 (feature may have been disabled)")
            return
        }

        val newCnt = prevCnt - 1
        prefs.edit().putInt(KEY_ACTIVE_COUNT, newCnt).apply()

        if (newCnt > 0) {
            // Another START is still active - keep silent.
            Log.d(TAG, "Overlap END: count ${prevCnt}->$newCnt (staying silent)")
            return
        }

        // Count reached 0 - restore ringer.
        if (!hasDndAccess(context)) {
            Log.w(TAG, "No DND access - cannot restore ringer after prayer")
            return
        }

        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (am.ringerMode == AudioManager.RINGER_MODE_SILENT) {
            val original = prefs.getInt(KEY_ORIG_RINGER, AudioManager.RINGER_MODE_NORMAL)
            am.ringerMode = original
            Log.d(TAG, "Ringer restored to mode $original after prayer (count 1->0)")
        } else {
            // User manually changed mode during prayer - respect their choice.
            Log.d(TAG, "Phone already non-silent (mode=${am.ringerMode}) - no restore needed")
        }
    }

    // ── Boot rescue ─────────────────────────────────────────────────────────

    private fun handleBoot(context: Context) {
        // Restore ringer if we were actively silencing before the reboot/update,
        // then reset the counter (restoreNow() handles both steps).
        // On a real reboot the OS already restores the ringer, so restoreNow is a safe no-op.
        // On an app update (MY_PACKAGE_REPLACED) the ringer may still be silent — restoreNow fixes it.
        restoreNow(context)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return

        val json = prefs.getString(KEY_SCHEDULE, null) ?: return
        if (json.isEmpty() || json == "[]") return

        try {
            val arr    = JSONArray(json)
            val alarms = ArrayList<Map<String, Any>>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                alarms.add(
                    mapOf(
                        "id"      to obj.getInt("id"),
                        "timeMs"  to obj.getLong("timeMs"),
                        "isStart" to obj.getBoolean("isStart"),
                    )
                )
            }
            scheduleAlarms(context, alarms)
            Log.d(TAG, "Boot: rescheduled ${alarms.size} silent-mode alarm(s)")
        } catch (e: Exception) {
            Log.e(TAG, "Boot reschedule failed: ${e.message}")
        }
    }
}