package com.example.quraan

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * Foreground Service that plays Adhan audio even when the app process is dead.
 *
 * Triggered by:
 *  - AdhanAlarmReceiver (scheduled via AlarmManager -- fires even when app is closed)
 *  - MainActivity MethodChannel "startAdhanService" (when app is running)
 *
 * The user can stop playback by tapping the "Stop Adhan" notification action
 * OR by pressing any volume key (via android.media.VOLUME_CHANGED_ACTION broadcast).
 */
class AdhanPlayerService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * BroadcastReceiver for android.media.VOLUME_CHANGED_ACTION.
     * Android fires this broadcast whenever ANY volume stream changes,
     * including when the user presses volume-up or volume-down.
     * Works in foreground, background, and while the screen is locked.
     */
    private var volumeReceiver: BroadcastReceiver? = null

    companion object {
        const val CHANNEL_ID    = "adhan_player_service_ch"
        const val NOTIF_ID      = 7_777
        const val EXTRA_SOUND   = "soundName"
        const val ACTION_STOP   = "com.example.quraan.STOP_ADHAN"
        private const val TAG   = "AdhanPlayerService"

        /** True while Adhan audio is actively playing.
         *  Checked by MainActivity to intercept volume key presses. */
        @Volatile var isPlaying: Boolean = false
            private set
    }

    // Lifecycle

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "Stop action received -- stopping")
            stopAdhan()
            stopSelf()
            return START_NOT_STICKY
        }

        val soundName = intent?.getStringExtra(EXTRA_SOUND) ?: "adhan_1"
        // Must call startForeground() within 5 s of startForegroundService()
        startForeground(NOTIF_ID, buildNotification())
        playAdhan(soundName)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopAdhan()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // Audio

    private fun playAdhan(soundName: String) {
        stopAdhan()
        try {
            val resId = resources.getIdentifier(soundName, "raw", packageName)
            if (resId == 0) {
                Log.e(TAG, "Sound resource not found: $soundName")
                stopSelf(); return
            }

            val pm = getSystemService(POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quraan:AdhanWakeLock")
            wakeLock?.acquire(10 * 60 * 1_000L) // max 10 minutes

            val afd = resources.openRawResourceFd(resId)
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()

            player.setOnCompletionListener {
                Log.d(TAG, "Adhan completed")
                it.release()
                mediaPlayer = null
                isPlaying = false
                releaseWakeLock()
                stopSelf()
            }
            player.setOnErrorListener { mp, what, extra ->
                Log.e(TAG, "MediaPlayer error: what=$what extra=$extra")
                mp.release()
                mediaPlayer = null
                isPlaying = false
                releaseWakeLock()
                stopSelf()
                true
            }

            player.prepare()
            player.start()
            mediaPlayer = player
            isPlaying = true
            registerVolumeReceiver()
            Log.d(TAG, "Adhan playing: $soundName")
        } catch (e: Exception) {
            Log.e(TAG, "Playback failed: $soundName", e)
            releaseWakeLock()
            stopSelf()
        }
    }

    private fun stopAdhan() {
        unregisterVolumeReceiver()
        try { mediaPlayer?.stop() }   catch (_: Exception) {}
        try { mediaPlayer?.release() } catch (_: Exception) {}
        mediaPlayer = null
        isPlaying = false
        releaseWakeLock()
    }

    // Volume receiver

    private fun registerVolumeReceiver() {
        if (volumeReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                Log.d(TAG, "Volume changed broadcast received -- stopping Adhan")
                stopAdhan()
                stopSelf()
            }
        }
        try {
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }
            volumeReceiver = receiver
            Log.d(TAG, "Volume receiver registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register volume receiver", e)
        }
    }

    private fun unregisterVolumeReceiver() {
        volumeReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        volumeReceiver = null
    }

    private fun releaseWakeLock() {
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null
    }

    // Notification

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, AdhanPlayerService::class.java).apply { action = ACTION_STOP }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openPi = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 1, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        val iconRes = resources.getIdentifier("ic_notification", "drawable", packageName)
            .takeIf { it != 0 } ?: R.mipmap.ic_launcher

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(iconRes)
            .setContentTitle("الأذان")
            .setContentText("اضغط لوقف الأذان")
            .setContentIntent(openPi)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "ايقاف الاذان",
                    stopPi
                ).build()
            )
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Adhan Player",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Adhan audio playback foreground service"
                setSound(null, null)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }
}