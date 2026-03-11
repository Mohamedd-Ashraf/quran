package com.example.quraan

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {

    private val adhanChannel = "quraan/adhan_player"

    /** MediaPlayer used ONLY for short in-settings previews. */
    private var previewPlayer: MediaPlayer? = null

    /** Kept so we can invoke 'previewCompleted' back to Flutter. */
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, adhanChannel)
        channel = ch
        ch.setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Short preview in the settings screen ───────────────
                    "playAdhan" -> {
                        val soundName = call.argument<String>("soundName") ?: "adhan_1"
                        val volume    = (call.argument<Double>("volume") ?: 1.0).toFloat()
                            .coerceIn(0.0f, 1.0f)
                        result.success(playPreviewNative(soundName, volume))
                    }

                    // ── Full adhan — always via foreground service ──────────
                    "startAdhanService" -> {
                        val soundName          = call.argument<String>("soundName") ?: "adhan_1"
                        val shortMode          = call.argument<Boolean>("shortMode") ?: false
                        val shortCutoffSeconds = call.argument<Int>("shortCutoffSeconds") ?: 15
                        val useAlarmStream     = call.argument<Boolean>("useAlarmStream") ?: false
                        val onlineUrl          = call.argument<String>("onlineUrl")
                        val notifTitle         = call.argument<String>("notifTitle")
                        val notifBody          = call.argument<String>("notifBody")
                        val stopLabel          = call.argument<String>("stopLabel")
                        // Persist shortMode immediately so AlarmReceiver reads the latest value
                        // even if Flutter's own SharedPreferences haven’t flushed yet.
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.adhan_short_mode", shortMode)
                            .putString("flutter.adhan_online_url", onlineUrl ?: "")
                            .apply()
                        startAdhanService(
                            soundName,
                            shortMode,
                            shortCutoffSeconds,
                            useAlarmStream,
                            onlineUrl,
                            notifTitle,
                            notifBody,
                            stopLabel
                        )
                        result.success(true)
                    }

                    // ── Stop preview + stop service ────────────────────────
                    "stopAdhan" -> {
                        stopPreviewNative()
                        stopAdhanService()
                        result.success(null)
                    }

                    // ── AlarmManager scheduling ────────────────────────────
                    "scheduleAdhanAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val alarms             = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        val soundName          = call.argument<String>("soundName") ?: "adhan_1"
                        val shortMode          = call.argument<Boolean>("shortMode") ?: false
                        val shortCutoffSeconds = call.argument<Int>("shortCutoffSeconds") ?: 15
                        val useAlarmStream     = call.argument<Boolean>("useAlarmStream") ?: false
                        val onlineUrl          = call.argument<String>("onlineUrl") ?: ""
                        // Persist ALL settings so AdhanAlarmReceiver can use them after the app is killed.
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.adhan_short_mode", shortMode)
                            .putInt("flutter.adhan_short_cutoff_seconds", shortCutoffSeconds)
                            .putString("flutter.adhan_audio_stream", if (useAlarmStream) "alarm" else "ringtone")
                            .putString("flutter.adhan_online_url", onlineUrl)
                            .apply()
                        AdhanAlarmReceiver.scheduleAlarms(this, alarms, soundName)
                        result.success(null)
                    }

                    "cancelAdhanAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        AdhanAlarmReceiver.cancelAlarms(this, ids)
                        result.success(null)
                    }

                    // ── Iqama AlarmManager scheduling ────────────────────────────────
                    "scheduleIqamaAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val alarms = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        // Persist iqama enabled flag and schedule for boot reschedule.
                        val scheduleJson = org.json.JSONArray().also { arr ->
                            alarms.forEach { a ->
                                arr.put(org.json.JSONObject().apply {
                                    put("id",     (a["id"]     as? Number)?.toInt()  ?: 0)
                                    put("timeMs", (a["timeMs"] as? Number)?.toLong() ?: 0L)
                                    put("title",  a["title"]  as? String ?: "")
                                    put("body",   a["body"]   as? String ?: "")
                                })
                            }
                        }.toString()
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.iqama_enabled", enabled)
                            .putString("flutter.iqama_schedule_json", scheduleJson)
                            .apply()
                        IqamaAlarmReceiver.scheduleAlarms(this, alarms)
                        result.success(null)
                    }

                    "cancelIqamaAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        IqamaAlarmReceiver.cancelAlarms(this, ids)
                        result.success(null)
                    }

                    // ── Approaching-reminder AlarmManager scheduling ─────────────────────
                    "scheduleApproachingAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val alarms  = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val scheduleJson = org.json.JSONArray().also { arr ->
                            alarms.forEach { a ->
                                arr.put(org.json.JSONObject().apply {
                                    put("id",     (a["id"]     as? Number)?.toInt()  ?: 0)
                                    put("timeMs", (a["timeMs"] as? Number)?.toLong() ?: 0L)
                                    put("title",  a["title"]  as? String ?: "")
                                    put("body",   a["body"]   as? String ?: "")
                                    put("sound",  a["sound"]  as? String ?: "prayer_reminder_fajr")
                                })
                            }
                        }.toString()
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.approaching_enabled", enabled)
                            .putString("flutter.approaching_schedule_json", scheduleJson)
                            .apply()
                        ApproachingAlarmReceiver.scheduleAlarms(this, alarms)
                        result.success(null)
                    }

                    "cancelApproachingAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        ApproachingAlarmReceiver.cancelAlarms(this, ids)
                        result.success(null)
                    }

                    // ── Salawat AlarmManager scheduling ──────────────────────────────────
                    "scheduleSalawatAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val alarms  = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val scheduleJson = org.json.JSONArray().also { arr ->
                            alarms.forEach { a ->
                                arr.put(org.json.JSONObject().apply {
                                    put("id",     (a["id"]     as? Number)?.toInt()  ?: 0)
                                    put("timeMs", (a["timeMs"] as? Number)?.toLong() ?: 0L)
                                    put("title",  a["title"]  as? String ?: "")
                                    put("body",   a["body"]   as? String ?: "")
                                    put("sound",  a["sound"]  as? String ?: "salawat_1")
                                })
                            }
                        }.toString()
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.salawat_enabled", enabled)
                            .putString("flutter.salawat_schedule_json", scheduleJson)
                            .apply()
                        SalawatAlarmReceiver.scheduleAlarms(this, alarms)
                        result.success(null)
                    }

                    "cancelSalawatAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        SalawatAlarmReceiver.cancelAlarms(this, ids)
                        result.success(null)
                    }

                    // ── Battery optimization ───────────────────────────────────
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(null)
                    }

                    "isBatteryOptimizationDisabled" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val disabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true // pre-M: no battery optimization concept
                        }
                        result.success(disabled)
                    }

                    // Returns current volume of whichever stream the user has selected for adhan.
                    // Also returns 'streamType' so the Dart UI can show the right label.
                    "getAlarmVolume" -> {
                        val am      = getSystemService(AUDIO_SERVICE) as AudioManager
                        val prefs   = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val isAlarm = prefs.getString("flutter.adhan_audio_stream", "ringtone") == "alarm"
                        val stream  = if (isAlarm) AudioManager.STREAM_ALARM else AudioManager.STREAM_RING
                        val current = am.getStreamVolume(stream)
                        val max     = am.getStreamMaxVolume(stream)
                        result.success(mapOf("current" to current, "max" to max, "streamType" to if (isAlarm) "alarm" else "ringtone"))
                    }

                    "openSoundSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                        } catch (e: Exception) {
                            Log.w("MainActivity", "Cannot open sound settings: ${e.message}")
                        }
                        result.success(null)
                    }

                    // ── Direct vibration (for Tasbeeh counter) ───────────────
                    "vibrate" -> {
                        val duration  = (call.argument<Int>("duration")  ?: 40).toLong()
                        val amplitude = call.argument<Int>("amplitude") ?: VibrationEffect.DEFAULT_AMPLITUDE
                        try {
                            val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val vm = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
                                vm.defaultVibrator
                            } else {
                                @Suppress("DEPRECATION")
                                getSystemService(VIBRATOR_SERVICE) as Vibrator
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude))
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(duration)
                            }
                        } catch (e: Exception) {
                            Log.w("MainActivity", "Vibrate failed: ${e.message}")
                        }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Battery optimization ───────────────────────────────────────────────

    /**
     * Tries to open the system dialog to whitelist this app from battery optimization.
     * On Android 6+ this launches the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS intent which
     * directly asks the user for this app. Falls back to the general settings page.
     */
    private fun openBatterySettings() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                    // Direct per-app dialog – user taps "Allow" and we're whitelisted.
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    return
                }
            }
            // Already whitelisted or < Android 6 — open the general settings page.
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        } catch (e: Exception) {
            Log.w("MainActivity", "Cannot open battery settings: ${e.message}")
            // Final fallback: open main app settings
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (_: Exception) {}
        }
    }

    // ── Short preview ─────────────────────────────────────────────────────────

    private fun playPreviewNative(soundName: String, volume: Float = 1.0f): Boolean {
        return try {
            stopPreviewNative()
            val resId = resources.getIdentifier(soundName, "raw", packageName)
            if (resId == 0) {
                Log.e("MainActivity", "Preview sound not found: $soundName")
                return false
            }
            val afd = applicationContext.resources.openRawResourceFd(resId) ?: return false
            val player = MediaPlayer()
            player.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    // Preview is in-app: use media stream so it ducked by other media.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            player.setOnCompletionListener {
                it.release()
                if (previewPlayer === it) previewPlayer = null
                // Notify Flutter that the preview finished naturally
                runOnUiThread { channel?.invokeMethod("previewCompleted", null) }
            }
            player.setOnErrorListener { mp, _, _ ->
                mp.release()
                if (previewPlayer === mp) previewPlayer = null
                runOnUiThread { channel?.invokeMethod("previewCompleted", null) }
                true
            }
            player.prepare()
            player.setVolume(volume, volume)
            player.start()
            previewPlayer = player
            Log.d("MainActivity", "Preview started: $soundName")
            true
        } catch (e: Exception) {
            Log.e("MainActivity", "Preview failed: $soundName", e)
            false
        }
    }

    private fun stopPreviewNative() {
        try { previewPlayer?.stop()    } catch (_: Exception) {}
        try { previewPlayer?.release() } catch (_: Exception) {}
        previewPlayer = null
    }

    // ── Full adhan via foreground service ─────────────────────────────────────

    private fun startAdhanService(
        soundName: String,
        shortMode: Boolean = false,
        shortCutoffSeconds: Int = 15,
        useAlarmStream: Boolean = false,
        onlineUrl: String? = null,
        notifTitle: String? = null,
        notifBody: String? = null,
        stopLabel: String? = null
    ) {
        val intent = Intent(this, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND, soundName)
            putExtra(AdhanPlayerService.EXTRA_SHORT_MODE, shortMode)
            putExtra(AdhanPlayerService.EXTRA_SHORT_CUTOFF_SECONDS, shortCutoffSeconds)
            putExtra(AdhanPlayerService.EXTRA_USE_ALARM_STREAM, useAlarmStream)
            if (!onlineUrl.isNullOrBlank()) putExtra(AdhanPlayerService.EXTRA_ONLINE_URL, onlineUrl)
            if (!notifTitle.isNullOrBlank()) putExtra(AdhanPlayerService.EXTRA_NOTIF_TITLE, notifTitle)
            if (!notifBody.isNullOrBlank()) putExtra(AdhanPlayerService.EXTRA_NOTIF_BODY, notifBody)
            if (!stopLabel.isNullOrBlank()) putExtra(AdhanPlayerService.EXTRA_STOP_LABEL, stopLabel)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d("MainActivity", "AdhanPlayerService started: $soundName (shortMode=$shortMode, cutoff=${shortCutoffSeconds}s, alarmStream=$useAlarmStream)")
    }

    private fun stopAdhanService() {
        val intent = Intent(this, AdhanPlayerService::class.java).apply {
            action = AdhanPlayerService.ACTION_STOP
        }
        startService(intent)
    }

    override fun onDestroy() {
        stopPreviewNative()
        super.onDestroy()
    }

    // ── Volume key interception ─────────────────────────────────────────

    /**
     * Intercept volume-up / volume-down key presses when Adhan is playing.
     * Instead of changing the volume, the first press stops the Adhan.
     * Subsequent presses (once isPlaying is false) work normally.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
             event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            val adhanRunning   = AdhanPlayerService.isPlaying
            val previewRunning = previewPlayer != null
            Log.d("MainActivity", "Volume key DOWN: adhanRunning=$adhanRunning previewRunning=$previewRunning")

            if (adhanRunning || previewRunning) {
                Log.d("MainActivity", "Volume key — stopping ${if (adhanRunning) "Adhan service" else "preview"}")

                if (adhanRunning)   stopAdhanService()
                if (previewRunning) {
                    stopPreviewNative()
                    runOnUiThread { channel?.invokeMethod("previewCompleted", null) }
                }
                return true // consume the event: stop Adhan/preview, don’t change volume
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
