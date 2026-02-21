package com.example.quraan

import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val adhanChannel = "quraan/adhan_player"

    /** MediaPlayer used ONLY for short in-settings previews. */
    private var previewPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, adhanChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Short preview in the settings screen ───────────────
                    "playAdhan" -> {
                        val soundName = call.argument<String>("soundName") ?: "adhan_1"
                        result.success(playPreviewNative(soundName))
                    }

                    // ── Full adhan — always via foreground service ──────────
                    "startAdhanService" -> {
                        val soundName = call.argument<String>("soundName") ?: "adhan_1"
                        startAdhanService(soundName)
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
                        val alarms    = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        val soundName = call.argument<String>("soundName") ?: "adhan_1"
                        AdhanAlarmReceiver.scheduleAlarms(this, alarms, soundName)
                        result.success(null)
                    }

                    "cancelAdhanAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        AdhanAlarmReceiver.cancelAlarms(this, ids)
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

    private fun playPreviewNative(soundName: String): Boolean {
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
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            player.setOnCompletionListener {
                it.release()
                if (previewPlayer === it) previewPlayer = null
            }
            player.setOnErrorListener { mp, _, _ ->
                mp.release()
                if (previewPlayer === mp) previewPlayer = null
                true
            }
            player.prepare()
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

    private fun startAdhanService(soundName: String) {
        val intent = Intent(this, AdhanPlayerService::class.java).apply {
            putExtra(AdhanPlayerService.EXTRA_SOUND, soundName)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d("MainActivity", "AdhanPlayerService started: $soundName")
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
             event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) &&
            AdhanPlayerService.isPlaying
        ) {
            Log.d("MainActivity", "Volume key pressed — stopping Adhan")
            stopAdhanService()
            stopPreviewNative()
            return true // consume the event: don’t change volume, just stop Adhan
        }
        return super.dispatchKeyEvent(event)
    }
}
