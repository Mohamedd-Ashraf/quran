package com.nooraliman.quran

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.database.ContentObserver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.MediaPlayer
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import java.io.File

/**
 * Foreground Service that plays Adhan audio even when the app process is dead.
 *
 * Triggered by:
 *  - AdhanAlarmReceiver (scheduled via AlarmManager -- fires even when app is closed)
 *  - MainActivity MethodChannel "startAdhanService" (when app is running)
 *
 * Audio stream: USAGE_NOTIFICATION_RINGTONE (ring stream).
 *   � Respects the user's ring volume � not the alarm volume.
 *
 * Stop mechanisms:
 *   1. Tap "????? ??????" in the foreground notification (works anywhere).
 *   2. Press any hardware volume key � layered mechanisms:
 *       a) MediaSession VolumeProvider (PRIMARY � intercepts the key press itself, works
 *          regardless of screen state, OEM, foreground app, or volume level).
 *       b) dispatchKeyEvent() in MainActivity (when our Activity has window focus).
 *       c) ContentObserver on ring/alarm volume URIs (backup for VolumeProvider fallthrough).
 *       d) VOLUME_CHANGED_ACTION BroadcastReceiver (tertiary, screen-on, guarded 1.5 s).
 *   3. Incoming phone call: audio-focus loss ? service stops automatically.
 */
class AdhanPlayerService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // -- Audio focus (API 26+) ------------------------------------------------
    private var legacyFocusListener: AudioManager.OnAudioFocusChangeListener? = null
    private var focusRequest: AudioFocusRequest? = null   // API 26+ only

    /**
     * BroadcastReceiver for android.media.VOLUME_CHANGED_ACTION.
     *
     * First line of defence: works on most devices when screen is on and for
     * many OEMs when the screen is off.
     */
    private var volumeReceiver: BroadcastReceiver? = null

    /**
     * MediaSession with a remote VolumeProvider � PRIMARY stop mechanism.
     *
     * When active, ALL hardware volume key presses are routed directly to
     * VolumeProvider.onAdjustVolume, regardless of:
     *  � Screen state (on / off / keyguard / doze)
     *  � Which app is in the foreground
     *  � OEM restrictions on broadcasts
     *  � Current volume level (even at min/max where volume can't actually change)
     *
     * This is the same mechanism used by phone-call ringtone apps.
     */
    private var adhanMediaSession: MediaSession? = null

    /**
     * ContentObserver on Settings.System � backup stop mechanism.
     *
     * Watches the Android system-settings database for ring/alarm volume changes.
     * Unlike VOLUME_CHANGED_ACTION broadcast (which some OEMs block in doze/
     * screen-off state), the ContentObserver is notified directly by the
     * ContentProvider � works on ALL OEMs. Fires only when the volume actually
     * changes (not when already at min/max), so VolumeProvider handles those edge cases.
     */
    private var volumeObserver: ContentObserver? = null
    private var shortModeHandler: Handler? = null
    private var shortModeRunnable: Runnable? = null

    /**
     * Nuclear-option polling fallback.
     *
     * VolumeProvider (MediaSession) is the primary mechanism, but on Samsung Android 15/16
     * it can fail to fire when just_audio_background's MediaSession competes for routing
     * priority. ContentObserver and BroadcastReceiver also fail when Samsung routes the
     * key to the lock-screen media controller or shows a media-volume slider.
     *
     * This thread polls AudioManager.getStreamVolume() every 500 ms and stops the adhan
     * when any relevant stream changes � guaranteed to work regardless of OEM quirks,
     * MediaSession priority, or volume routing paths.
     */
    private var volumePollThread: Thread? = null

    companion object {
        const val CHANNEL_ID      = "adhan_ch_v3"
        const val NOTIF_ID        = 7_777
        const val EXTRA_SOUND               = "soundName"
        /** Pass true to auto-stop playback after shortCutoffSeconds. */
        const val EXTRA_SHORT_MODE           = "shortMode"
        /** Per-sound cutoff in seconds for short-adhan mode. */
        const val EXTRA_SHORT_CUTOFF_SECONDS = "shortCutoffSeconds"
        /** True ? use STREAM_ALARM (alarm volume). False ? STREAM_RING (ring volume, default). */
        const val EXTRA_USE_ALARM_STREAM     = "useAlarmStream"
        /** For online sounds: direct streaming URL used if cache file is missing. */
        const val EXTRA_ONLINE_URL           = "onlineUrl"
        /** Optional: custom foreground notification title (e.g. for iqama). */
        const val EXTRA_NOTIF_TITLE         = "notifTitle"
        /** Optional: custom foreground notification body text. */
        const val EXTRA_NOTIF_BODY          = "notifBody"
        /** Optional: custom stop-button label. */
        const val EXTRA_STOP_LABEL          = "stopLabel"
        /** Optional: SharedPreferences key for the playback volume (default: flutter.adhan_volume). */
        const val EXTRA_VOLUME_KEY          = "volumeKey"
        /**
         * Pass true to disable the VOLUME_CHANGED_ACTION receiver.
         * Use for iqama / approaching / salawat where the sound must play fully and
         * should only be stopped by the notification button or audio-focus loss.
         * Default: false (volume key stops the adhan, which is the desired adhan behaviour).
         */
        const val EXTRA_DISABLE_VOLUME_STOPPER = "disableVolumeStopper"
        /** Pass true to force audio output to the device speaker, bypassing Bluetooth/headphones. */
        const val EXTRA_FORCE_SPEAKER = "forceSpeaker"
        const val ACTION_STOP               = "com.nooraliman.quran.STOP_ADHAN"
        private const val TAG               = "AdhanPlayerService"
        /** Default fallback cutoff when none provided (� 2 takbeers). */
        private const val DEFAULT_SHORT_CUTOFF_SECONDS = 15

        /** True while Adhan audio is actively playing.
         *  Checked by MainActivity to intercept volume key presses. */
        @Volatile var isPlaying: Boolean = false
            private set

        /** Name of the sound currently playing (or last started). Used to de-duplicate
         *  simultaneous starts from AlarmReceiver + MainActivity for the same alarm. */
        @Volatile private var currentPlayingSound: String? = null

        /** Epoch ms when the current playback session was started. Used together with
         *  [currentPlayingSound] to ignore duplicate starts within a 3-second window. */
        @Volatile private var playbackStartedAt: Long = 0L
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

        val soundName          = intent?.getStringExtra(EXTRA_SOUND) ?: "adhan_1"
        val isShortMode        = intent?.getBooleanExtra(EXTRA_SHORT_MODE, false) ?: false
        val shortCutoffSeconds = intent?.getIntExtra(EXTRA_SHORT_CUTOFF_SECONDS, DEFAULT_SHORT_CUTOFF_SECONDS)
                                   ?: DEFAULT_SHORT_CUTOFF_SECONDS
        val useAlarmStream     = intent?.getBooleanExtra(EXTRA_USE_ALARM_STREAM, false) ?: false
        val onlineUrl          = intent?.getStringExtra(EXTRA_ONLINE_URL)?.takeIf { it.isNotBlank() }
        val notifTitle         = intent?.getStringExtra(EXTRA_NOTIF_TITLE)
        val notifBody          = intent?.getStringExtra(EXTRA_NOTIF_BODY)
        val stopLabel          = intent?.getStringExtra(EXTRA_STOP_LABEL)
        val volumeKey          = intent?.getStringExtra(EXTRA_VOLUME_KEY) ?: "flutter.adhan_volume"
        val disableVolumeStopper = intent?.getBooleanExtra(EXTRA_DISABLE_VOLUME_STOPPER, false) ?: false
        val forceSpeaker       = intent?.getBooleanExtra(EXTRA_FORCE_SPEAKER, false) ?: false

        // Guard: deduplicate simultaneous starts that happen when AlarmReceiver and
        // MainActivity both call startForegroundService() for the same prayer alarm.
        // If the SAME sound started within the last 3 seconds, this is a duplicate � ignore it.
        if (isPlaying && currentPlayingSound == soundName &&
                System.currentTimeMillis() - playbackStartedAt < 3_000L) {
            Log.w(TAG, "onStartCommand: duplicate start for '$soundName' within 3 s � ignoring")
            return START_NOT_STICKY
        }
        if (isPlaying) {
            Log.w(TAG, "onStartCommand: adhan already playing � restarting for $soundName")
        }

        // Must call startForeground() within 5 s of startForegroundService().
        // Create MediaSession FIRST so the notification can embed the session token
        // (enables lock-screen controls and activates VolumeProvider routing).
        createAdhanMediaSession(disableVolumeStopper, notifTitle)
        startForeground(NOTIF_ID, buildNotification(notifTitle, notifBody, stopLabel))
        playAdhan(soundName, isShortMode, shortCutoffSeconds, useAlarmStream, onlineUrl, volumeKey, disableVolumeStopper, forceSpeaker)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        cancelShortModeTimer()
        stopAdhan()  // already calls abandonAudioFocus() + releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // -- Audio focus ------------------------------------------------------------

    /**
     * Request AUDIOFOCUS_GAIN on the RING stream.
     *
     * Benefits:
     *  � Other apps (music, podcasts) are paused while the adhan plays.
     *  � If an incoming phone call arrives, we receive AUDIOFOCUS_LOSS
     *    and stop the adhan automatically.
     *
     * @return true if focus was granted (we can play), false otherwise.
     */
    private fun requestAudioFocus(audioAttributes: AudioAttributes): Boolean {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS -> {
                    // Permanent focus loss = phone call or another exclusive audio stream.
                    // Stop the adhan gracefully.
                    Log.d(TAG, "Audio focus permanently lost ($change) � stopping adhan")
                    stopAdhan()
                    stopSelf()
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    // Transient loss can be a phone call or another app momentarily
                    // requesting focus. Check TelephonyManager: if a call is active/ringing,
                    // stop the adhan. Otherwise, keep playing � the other app will yield.
                    val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                    @Suppress("DEPRECATION")
                    val callActive = tm != null && tm.callState != TelephonyManager.CALL_STATE_IDLE
                    if (callActive) {
                        Log.d(TAG, "Audio focus transiently lost ($change) + phone call active � stopping adhan")
                        stopAdhan()
                        stopSelf()
                    } else {
                        Log.d(TAG, "Audio focus transiently lost ($change) � ignored, adhan continues (no active call)")
                    }
                }
                // AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK: duck request � also ignored.
                // AUDIOFOCUS_GAIN: focus returned to us (e.g. call ended) � no action needed,
                // MediaPlayer is already playing.
            }
        }
        legacyFocusListener = listener

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener(listener, Handler(Looper.getMainLooper()))
                .setWillPauseWhenDucked(false)
                .build()
            focusRequest = req
            am.requestAudioFocus(req) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            // Pre-API 26: map AudioAttributes usage ? legacy stream type.
            val legacyStream = if (audioAttributes.usage == AudioAttributes.USAGE_ALARM)
                AudioManager.STREAM_ALARM
            else
                AudioManager.STREAM_RING
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                listener, legacyStream, AudioManager.AUDIOFOCUS_GAIN
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        val am = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            legacyFocusListener?.let { am.abandonAudioFocus(it) }
        }
        legacyFocusListener = null
    }

    // -- Playback ---------------------------------------------------------------

    private fun cancelShortModeTimer() {
        shortModeRunnable?.let { shortModeHandler?.removeCallbacks(it) }
        shortModeHandler = null
        shortModeRunnable = null
    }

    private fun playAdhan(soundName: String, shortMode: Boolean = false, shortCutoffSeconds: Int = DEFAULT_SHORT_CUTOFF_SECONDS, useAlarmStream: Boolean = false, onlineUrl: String? = null, volumeKey: String = "flutter.adhan_volume", disableVolumeStopper: Boolean = false, forceSpeaker: Boolean = false) {
        cancelShortModeTimer()
        stopAdhan()
        // Set active immediately after stopping any previous playback.
        // This allows dispatchKeyEvent + VolumeProvider to stop this attempt
        // even during MediaPlayer.prepare() (which runs before isPlaying is set
        // inside startPlayback). stopAdhan() above already cleared isPlaying,
        // so setting it here is safe and won't be overwritten by it.
        isPlaying = true
        currentPlayingSound = soundName
        playbackStartedAt   = System.currentTimeMillis()
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quraan:AdhanWakeLock")
            wakeLock?.acquire(10 * 60 * 1_000L) // max 10 minutes

            // -- Audio attributes: Ring (default) or Alarm -----------------------------
            //  Ring (USAGE_NOTIFICATION_RINGTONE):
            //    � Volume controlled by the ring slider.
            //    � Volume-key on lock screen ? VOLUME_CHANGED_ACTION ? adhan stops.
            //    � Respects Silent/Vibrate / Do Not Disturb mode.
            //  Alarm (USAGE_ALARM):
            //    � Volume controlled by the alarm slider.
            //    � Bypasses Silent/Vibrate and DND on most devices.
            //
            // DND Auto-Override:
            //   If the user chose RING stream but Do Not Disturb is active in a mode
            //   that blocks ring sounds, requestAudioFocus() will be denied and the
            //   adhan will silently fail. To prevent this, we automatically upgrade
            //   to ALARM stream when DND is active � ensuring the adhan always plays.
            val isDndActive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
            } else false

            val effectiveUseAlarmStream = useAlarmStream || isDndActive
            if (!useAlarmStream && isDndActive) {
                Log.d(TAG, "DND active � auto-upgrading from RING to ALARM stream so adhan plays")
            }

            val audioUsage = if (effectiveUseAlarmStream)
                AudioAttributes.USAGE_ALARM
            else
                AudioAttributes.USAGE_NOTIFICATION_RINGTONE
            val audioAttrs = AudioAttributes.Builder()
                .setUsage(audioUsage)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            Log.d(TAG, "Audio stream: ${if (effectiveUseAlarmStream) "ALARM${if (isDndActive && !useAlarmStream) " (DND override)" else ""}" else "RING"}")

            val player = MediaPlayer()
            player.setAudioAttributes(audioAttrs)

            // -- Force speaker: bypass Bluetooth / wired headphones ---------
            if (forceSpeaker) {
                val am = getSystemService(AUDIO_SERVICE) as AudioManager
                if (am.isBluetoothA2dpOn || am.isBluetoothScoOn || am.isWiredHeadsetOn) {
                    // Temporarily route to device speaker by disabling SCO and setting
                    // speaker mode. Restored in stopAdhan() via setSpeakerphoneOn(false).
                    am.mode = AudioManager.MODE_IN_COMMUNICATION
                    @Suppress("DEPRECATION")
                    am.isSpeakerphoneOn = true
                    Log.d(TAG, "Force speaker: routing audio to device speaker (BT/headset detected)")
                }
            }

            // -- Resolve audio source -------------------------------------------
            // Priority order for online sounds:
            //  1. Cached local file (? instant, no network needed)
            //  2. Direct URL streaming (? needs network, no cache required)
            //  3. Offline fallback adhan_1 (? used only when URL is also absent)
            var sourceLoaded = false
            var isStreamingFromUrl = false
            if (soundName.startsWith("online_")) {
                val cachedFile = File("${filesDir.absolutePath}/adhan_cache/${soundName}.mp3")
                if (cachedFile.exists() && cachedFile.length() > 1024) {
                    player.setDataSource(cachedFile.absolutePath)
                    sourceLoaded = true
                    Log.d(TAG, "Adhan: playing cached file: ${cachedFile.name}")
                } else if (!onlineUrl.isNullOrBlank()) {
                    // Stream directly from URL � works even without a pre-downloaded cache.
                    player.setDataSource(onlineUrl)
                    sourceLoaded = true
                    isStreamingFromUrl = true
                    Log.d(TAG, "Adhan: streaming from URL (no cache): $onlineUrl")
                } else {
                    Log.w(TAG, "Adhan: no cache and no URL for '$soundName' � falling back to adhan_1")
                }
            }

            if (!sourceLoaded) {
                val effectiveName = if (soundName.startsWith("online_")) "adhan_1" else soundName
                val resId = resources.getIdentifier(effectiveName, "raw", packageName)
                if (resId == 0) {
                    Log.e(TAG, "Sound resource not found: $effectiveName")
                    player.release()
                    releaseWakeLock()
                    stopSelf(); return
                }
                val afd = resources.openRawResourceFd(resId)
                player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            }

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

            val prefs  = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val volume = readVolumeFromPrefs(prefs, volumeKey)
            Log.d(TAG, "Volume resolved: key=$volumeKey raw=${prefs.all[volumeKey]} parsed=$volume")

            /** Common post-prepare: set volume, start, register receiver, set short-mode timer. */
            fun startPlayback(mp: MediaPlayer) {

                mp.setVolume(volume, volume)
                mp.start()
                mediaPlayer = mp
                isPlaying = true
                
                // Notify widget to update immediately when adhan starts
                try {
                    val updateIntent = Intent("com.nooraliman.quran.ADHAN_STARTED")
                    this@AdhanPlayerService.sendBroadcast(updateIntent)
                } catch (_: Exception) {
                }
                
                // Only register the volume stopper for adhan sounds.
                // Iqama / approaching / salawat pass disableVolumeStopper=true so they play
                // fully regardless of spurious VOLUME_CHANGED_ACTION from OEMs.
                if (!disableVolumeStopper) {
                    // VolumeProvider (MediaSession) is the PRIMARY mechanism and fires on the
                    // key press itself � no delay needed for it.
                    // ContentObserver watches the actual settings DB: no spurious events,
                    // register immediately as backup for when VolumeProvider is bypassed.
                    registerVolumeObserver()   // backup: settings DB (immediate)
                    // Broadcast: register immediately. Samsung lock screen sometimes routes
                    // volume keys through VOLUME_CHANGED_ACTION but NOT Settings.System,
                    // so we need this to fire alongside the ContentObserver.
                    registerVolumeReceiver()   // tertiary: broadcast (immediate)
                    // Polling: absolute failsafe � works even when Samsung routes volume
                    // keys to a competing MediaSession and all other mechanisms are silent.
                    startVolumePolling()       // failsafe: 500 ms poll (no OEM can block this)
                }
                Log.d(TAG, "Adhan playing: $soundName (shortMode=$shortMode, cutoff=${shortCutoffSeconds}s, streaming=$isStreamingFromUrl)")
                if (shortMode) {
                    val cutoffMs = shortCutoffSeconds * 1000L
                    val handler  = Handler(Looper.getMainLooper())
                    val runnable = Runnable {
                        Log.d(TAG, "Short mode: auto-stopping adhan after ${shortCutoffSeconds}s")
                        stopAdhan()
                        stopSelf()
                    }
                    handler.postDelayed(runnable, cutoffMs)
                    shortModeHandler  = handler
                    shortModeRunnable = runnable
                }
            }

            if (isStreamingFromUrl) {
                // Network source: prepareAsync() avoids blocking; start inside OnPreparedListener.
                player.setOnPreparedListener { mp ->
                    // Guard: stop may be requested during network prepare (can take seconds).
                    if (!isPlaying) {
                        Log.d(TAG, "Adhan: streaming prepare done but stop was requested � aborting")
                        mp.release()
                        releaseWakeLock()
                        stopSelf()
                        return@setOnPreparedListener
                    }
                    // Request audio focus as a courtesy so other apps (music, podcasts) pause.
                    // Never abort on denial � an adhan/alarm MUST play regardless of focus state.
                    // On Android 15, just_audio_background (same process) may hold focus and the
                    // system denies our request; aborting would silently skip the prayer call.
                    if (!requestAudioFocus(audioAttrs)) {
                        Log.w(TAG, "Audio focus denied (streaming) � continuing adhan playback anyway")
                    }
                    startPlayback(mp)
                }
                player.prepareAsync()
            } else {
                player.prepare()
                // Request audio focus as a courtesy so other apps (music, podcasts) pause.
                // Never abort on denial � an adhan/alarm MUST play regardless of focus state.
                // On Android 15, just_audio_background (same process) may hold focus and the
                // system denies our request; aborting would silently skip the prayer call.
                if (!requestAudioFocus(audioAttrs)) {
                    Log.w(TAG, "Audio focus denied � continuing adhan playback anyway")
                }
                startPlayback(player)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Playback failed: $soundName", e)
            isPlaying = false
            releaseWakeLock()
            stopSelf()
        }
    }

    /**
     * Reads a volume value from Flutter SharedPreferences and normalizes it to [0.0, 1.0].
     *
     * Depending on plugin/version/migration path, doubles can be stored as different native
     * types. Supporting all numeric/string variants prevents falling back to full volume.
     */
    private fun readVolumeFromPrefs(
        prefs: SharedPreferences,
        key: String,
        fallback: Float = 1.0f
    ): Float {
        val raw = prefs.all[key]
        val parsed = when (raw) {
            is Float -> raw
            is Double -> raw.toFloat()
            is Int -> raw.toFloat()
            is Long -> raw.toFloat()
            is String -> parseFlutterDoubleString(raw)
            else -> null
        }
        return (parsed ?: fallback).coerceIn(0.0f, 1.0f)
    }

    /**
     * shared_preferences on Android may store doubles as encoded strings (legacy format).
     * Accepts plain numeric strings and known Flutter double prefixes.
     */
    private fun parseFlutterDoubleString(raw: String): Float? {
        raw.toFloatOrNull()?.let { return it }

        val knownPrefixes = listOf(
            "This is the prefix for a double.",
            "This is the prefix for Double.",
            // Base64 of the same prefix used by some plugin versions/migrations.
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGRvdWJsZS4",
            // Base64 variant observed on device logs (capital D in Double).
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
        )

        for (prefix in knownPrefixes) {
            if (raw.startsWith(prefix)) {
                val suffix = raw.removePrefix(prefix).trim()
                // Some plugin variants prefix the numeric part with a marker (e.g. "u0.1").
                val cleaned = suffix
                    .removePrefix("u")
                    .removePrefix("U")
                    .trim()
                cleaned.toFloatOrNull()?.let { return it }
            }
        }

        // Do not guess from arbitrary mixed strings (e.g. base64 blobs) because this
        // can incorrectly resolve to 0.0 and mute alarms. Return null so caller falls
        // back to the safe default.
        return null
    }

    private fun stopAdhan() {
        cancelShortModeTimer()
        stopVolumePolling()            // stop polling before deactivating everything else
        releaseAdhanMediaSession()     // deactivate VolumeProvider first
        unregisterVolumeReceiver()
        unregisterVolumeObserver()
        // Reset speaker mode if we forced it
        try {
            val am = getSystemService(AUDIO_SERVICE) as? AudioManager
            if (am != null && am.isSpeakerphoneOn) {
                @Suppress("DEPRECATION")
                am.isSpeakerphoneOn = false
                am.mode = AudioManager.MODE_NORMAL
            }
        } catch (_: Exception) {}
        try { mediaPlayer?.stop() }    catch (_: Exception) {}
        try { mediaPlayer?.release() } catch (_: Exception) {}
        mediaPlayer = null
        isPlaying = false
        currentPlayingSound = null
        abandonAudioFocus()
        releaseWakeLock()
    }

    // -- MediaSession: primary volume-key interceptor --------------------------

    /**
     * Creates a [MediaSession] with a remote [VolumeProvider].
     *
     * Setting [MediaSession.setPlaybackToRemote] routes ALL hardware volume key
     * events to [VolumeProvider.onAdjustVolume] instead of the system volume slider.
     * This works with the screen off, with any other app in the foreground, and
     * even when the device volume is already at min or max (the key press still fires).
     *
     * When [disableVolumeStopper] is true (iqama / salawat / approaching alerts),
     * we create the session WITHOUT a VolumeProvider so volume keys work normally.
     */
    private fun createAdhanMediaSession(disableVolumeStopper: Boolean, title: String? = null) {
        releaseAdhanMediaSession()
        val session = MediaSession(this, "quraan_adhan")

        // Set MediaMetadata so the OS compact-player widget and lock screen
        // show the correct prayer name and artwork instead of a blank card.
        val artBitmap = getAssetBitmap("assets/logo/files/mosque.jpg")
        // Use non-breaking spaces to prevent Samsung's MediaStyle from word-wrapping Arabic.
        fun String.nbsps() = replace(' ', '\u00A0')
        val metaTitle = (title ?: "??????").nbsps()
        val meta = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE,            metaTitle)
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE,    metaTitle)
            .putString(MediaMetadata.METADATA_KEY_ARTIST,           "???\u00A0????\u00A0????\u00A0??????")
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE, "????\u00A0??????\u00A0??????")
            .putString(MediaMetadata.METADATA_KEY_ALBUM,            "?????\u00A0??????")
            .also { b -> if (artBitmap != null) {
                b.putBitmap(MediaMetadata.METADATA_KEY_ART,       artBitmap)
                b.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, artBitmap)
            }}
            .build()
        session.setMetadata(meta)

        // Required: without these flags the session does NOT receive media button
        // or volume key events from the system. Many OEMs require this to route
        // hardware volume key presses to our VolumeProvider.
        @Suppress("DEPRECATION")
        session.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
        )

        if (!disableVolumeStopper) {
            val volumeProvider = object : VolumeProvider(
                VOLUME_CONTROL_RELATIVE,
                100,  // maxVolume (arbitrary � we don't actually track volume)
                50    // currentVolume (mid-point so both up and down register)
            ) {
                override fun onAdjustVolume(direction: Int) {
                    // Stop unconditionally � if this session is active, Adhan is playing.
                    // No isPlaying guard here: the race condition fix in onStartCommand
                    // (isPlaying = true before playAdhan) makes the guard redundant,
                    // and a stale guard was the original cause of silent failure.
                    Log.d(TAG, "VolumeProvider: volume key (dir=$direction) � stopping Adhan")
                    Handler(Looper.getMainLooper()).post { stopAdhan(); stopSelf() }
                }
                override fun onSetVolumeTo(volume: Int) {
                    Log.d(TAG, "VolumeProvider: setVolumeTo($volume) � stopping Adhan")
                    Handler(Looper.getMainLooper()).post { stopAdhan(); stopSelf() }
                }
            }
            session.setPlaybackToRemote(volumeProvider)
        }

        session.setCallback(object : MediaSession.Callback() {
            override fun onStop() {
                Log.d(TAG, "MediaSession.onStop() � stopping Adhan")
                Handler(Looper.getMainLooper()).post { stopAdhan(); stopSelf() }
            }
            override fun onPause() = onStop()
        })

        session.setPlaybackState(
            PlaybackState.Builder()
                .setState(PlaybackState.STATE_PLAYING, 0L, 1.0f)
                .setActions(PlaybackState.ACTION_STOP or PlaybackState.ACTION_PAUSE)
                .build()
        )
        session.isActive = true
        adhanMediaSession = session
        Log.d(TAG, "AdhanMediaSession activated (volumeStopper=${!disableVolumeStopper})")
    }

    private fun releaseAdhanMediaSession() {
        try {
            adhanMediaSession?.isActive = false
            adhanMediaSession?.release()
        } catch (_: Exception) {}
        adhanMediaSession = null
    }

    // -- Volume stopper: broadcast + ContentObserver (backup) ------------------

    private fun registerVolumeReceiver() {
        if (volumeReceiver != null) return
        val registeredAt = System.currentTimeMillis()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                // Only react to audible stream volume changes that a user could
                // intentionally use to signal "stop". Ignore streams like DTMF (8),
                // system (1), or accessibility (10) which fire for unrelated reasons.
                val stream = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                val relevant = stream in listOf(
                    AudioManager.STREAM_RING,          // 2 � default adhan stream
                    AudioManager.STREAM_ALARM,         // 4 � alarm-stream adhan
                    AudioManager.STREAM_MUSIC,         // 3 � Samsung lock screen routes here
                    AudioManager.STREAM_NOTIFICATION   // 5 � some OEMs use this
                )
                if (!relevant) {
                    Log.d(TAG, "Volume broadcast ignored (stream=$stream)")
                    return
                }
                // 500 ms startup guard: some OEMs send a spurious VOLUME_CHANGED_ACTION
                // when a new audio stream opens (e.g. ring stream starts after ExoPlayer stops).
                // 500 ms is sufficient to absorb Samsung's spurious event (fires <200 ms after
                // stream open) while keeping the unprotected window as short as possible.
                if (System.currentTimeMillis() - registeredAt < 500L) {
                    Log.d(TAG, "Volume broadcast suppressed (startup guard 500 ms, stream=$stream)")
                    return
                }
                Log.d(TAG, "Volume changed broadcast received (stream=$stream) -- stopping Adhan")
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

    /**
     * Register a ContentObserver on the RING and ALARM volume URIs only.
     *
     * We intentionally watch only volume-specific URIs (not all of
     * Settings.System) to avoid false positives from other system-settings
     * changes such as brightness, font size, Wi-Fi, etc.
     *
     * - Ring stream (USAGE_NOTIFICATION_RINGTONE): VOLUME_RING changes.
     * - Alarm stream (USAGE_ALARM): VOLUME_ALARM changes.
     * We register both so the correct one fires regardless of which stream
     * the adhan is currently using.
     *
     * Fires on volume key press regardless of screen state or OEM restrictions
     * because it watches the ContentProvider database directly.
     * Guarded by [isPlaying] so double-fires are harmless.
     */
    private fun registerVolumeObserver() {
        if (volumeObserver != null) return
        val registeredAt = System.currentTimeMillis()
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                if (!isPlaying) return   // already stopping � ignore
                // 500 ms startup guard: when adhan requests audio focus, ExoPlayer
                // (just_audio_background) may pause and the system can auto-adjust
                // STREAM_MUSIC. 500 ms is enough to absorb that transient change while
                // keeping the unprotected window short.
                if (System.currentTimeMillis() - registeredAt < 500L) {
                    Log.d(TAG, "Volume setting changed (ContentObserver) � suppressed (startup guard 500 ms)")
                    return
                }
                Log.d(TAG, "Volume setting changed (ContentObserver) � stopping Adhan")
                stopAdhan()
                stopSelf()
            }
        }
        try {
            // Watch ring, alarm, music, AND notification volume URIs.
            //
            // Why watch all four?
            //  � Ring  (volume_ring)  � adhan on RING stream changes this.
            //  � Alarm (volume_alarm) � adhan on ALARM stream changes this.
            //  � Music (volume_music) � Samsung lock screen shows MEDIA volume slider when
            //    ExoPlayer (just_audio_background) was last active. Pressing volume key on
            //    lock screen changes STREAM_MUSIC even while ring-stream adhan is playing.
            //  � Notification (volume_notification) � some OEMs route to this stream.
            //
            // Only one key will actually fire per press depending on the device state.
            val ringUri  = Settings.System.getUriFor("volume_ring")
            val alarmUri = Settings.System.getUriFor("volume_alarm")
            val musicUri = Settings.System.getUriFor("volume_music")
            val notifUri = Settings.System.getUriFor("volume_notification")
            contentResolver.registerContentObserver(ringUri,  false, observer)
            contentResolver.registerContentObserver(alarmUri, false, observer)
            contentResolver.registerContentObserver(musicUri, false, observer)
            contentResolver.registerContentObserver(notifUri, false, observer)
            volumeObserver = observer
            Log.d(TAG, "Volume ContentObserver registered (ring + alarm + music + notification URIs)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register volume ContentObserver", e)
        }
    }

    private fun unregisterVolumeObserver() {
        volumeObserver?.let {
            try { contentResolver.unregisterContentObserver(it) } catch (_: Exception) {}
        }
        volumeObserver = null
    }

    /**
     * Start a background thread that polls AudioManager volume levels every 500 ms.
     *
     * Why polling works when everything else fails:
     *  � VolumeProvider can be bypassed if Samsung routes volume keys to another MediaSession.
     *  � ContentObserver only fires if the volume setting *changes* � fails at min/max.
     *  � BroadcastReceiver can be suppressed by OEMs in doze/screen-off.
     *  � Polling directly calls AudioManager.getStreamVolume() � no routing, no OEM blocking.
     *
     * Starts after 1 500 ms to match the startup guard on the other mechanisms, so a
     * spurious volume change during adhan initialisation does not cause an instant stop.
     * Once any relevant stream deviates from the baseline captured in this function, the
     * adhan is stopped on the main thread.
     */
    private fun startVolumePolling() {
        stopVolumePolling()
        val am = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        // Capture baseline BEFORE sleeping so we always have a valid reference.
        val baselineRing  = am.getStreamVolume(AudioManager.STREAM_RING)
        val baselineAlarm = am.getStreamVolume(AudioManager.STREAM_ALARM)
        val baselineMusic = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        Log.d(TAG, "Volume polling started (ring=$baselineRing alarm=$baselineAlarm music=$baselineMusic)")

        volumePollThread = Thread {
            // Match the startup guard used by ContentObserver / BroadcastReceiver.
            try { Thread.sleep(500L) } catch (_: InterruptedException) { return@Thread }

            while (isPlaying && !Thread.currentThread().isInterrupted) {
                try {
                    val ring  = am.getStreamVolume(AudioManager.STREAM_RING)
                    val alarm = am.getStreamVolume(AudioManager.STREAM_ALARM)
                    val music = am.getStreamVolume(AudioManager.STREAM_MUSIC)

                    if (ring != baselineRing || alarm != baselineAlarm || music != baselineMusic) {
                        Log.d(TAG, "Volume poll: change detected " +
                            "(ring $baselineRing?$ring | alarm $baselineAlarm?$alarm | " +
                            "music $baselineMusic?$music) � stopping adhan")
                        Handler(Looper.getMainLooper()).post {
                            if (isPlaying) { stopAdhan(); stopSelf() }
                        }
                        break
                    }
                    Thread.sleep(500L)
                } catch (_: InterruptedException) {
                    break
                }
            }
            Log.d(TAG, "Volume polling ended")
        }.also { it.isDaemon = true; it.name = "AdhanVolumePoll"; it.start() }
    }

    private fun stopVolumePolling() {
        volumePollThread?.interrupt()
        volumePollThread = null
    }

    private fun releaseWakeLock() {
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null
    }

    // Notification

    /** Renders any drawable resource to a 512�512 Bitmap for media artwork. */
    private fun getDrawableBitmap(resId: Int): Bitmap? = try {
        val size = 256
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val drawable = resources.getDrawable(resId, theme)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        bmp
    } catch (_: Exception) { null }

    /** Decodes a Flutter asset into a Bitmap for notification artwork.
     *
     * Flutter stores declared assets inside the APK under flutter_assets/<declared-path>.
     * Android's AssetManager sees the path relative to the APK's assets/ directory, so
     * the full AssetManager key is "flutter_assets/<pubspec-relative-path>".
     * e.g. pubspec: "assets/logo/files/mosque.jpg" ? key: "flutter_assets/assets/logo/files/mosque.jpg"
     */
    private fun getAssetBitmap(assetPath: String): Bitmap? {
        // Normalise: strip a leading "flutter_assets/" to avoid double-prefixing.
        val normalised = assetPath.removePrefix("flutter_assets/")
        val key = "flutter_assets/$normalised"
        return try {
            assets.open(key).use { input -> BitmapFactory.decodeStream(input) }
        } catch (_: Exception) { null }
    }

    private fun buildNotification(
        title: String? = null,
        body: String? = null,
        stopLabel: String? = null
    ): Notification {
        val stopIntent = Intent(this, AdhanPlayerService::class.java).apply { action = ACTION_STOP }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Opens the app only when the user intentionally taps the notification body.
        val openPi = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 1, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        val iconRes = resources.getIdentifier("ic_notification", "drawable", packageName)
            .takeIf { it != 0 } ?: R.mipmap.ic_launcher

        val largeIcon = getAssetBitmap("assets/logo/files/mosque.jpg")

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        if (largeIcon != null) builder.setLargeIcon(largeIcon)

        // Replace regular spaces with non-breaking spaces (\u00A0) in both title and body.
        // Samsung's MediaStyle notification word-wraps at regular spaces, which causes
        // multi-word Arabic strings like "???? ?????? ??????" to be clipped to just the
        // first word. Non-breaking spaces prevent that line break.
        fun String.nbsps() = replace(' ', '\u00A0')
        val isArabic = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.app_language", "ar") == "ar"
        val safeTitle = (title ?: if (isArabic) "أذان" else "Adhan").nbsps()
        val safeBody  = (body  ?: if (isArabic) "اضغط\u00A0لإيقاف\u00A0الأذان" else "Tap\u00A0to\u00A0stop").nbsps()

        // Use a system stop/close icon so the action button renders visibly on
        // Android 15 Samsung "Live Notifications" compact cards (null icons are invisible).
        @Suppress("DEPRECATION")
        val stopAction = Notification.Action.Builder(
            android.R.drawable.ic_media_pause,
            stopLabel?.replace(' ', '\u00A0') ?: if (isArabic) "إيقاف\u00A0الأذان" else "Stop\u00A0Adhan",
            stopPi
        ).build()

        return builder
            .setSmallIcon(iconRes)
            .setColor(0xFF1B5E20.toInt()) // Islamic dark green accent
            .setColorized(true)
            .setContentTitle(safeTitle)
            .setContentText(safeBody)
            .setContentIntent(openPi)
            .setVisibility(Notification.VISIBILITY_PUBLIC)  // show on lock screen so stop is accessible
            .setOngoing(true)
            .setStyle(
                Notification.MediaStyle().also { style ->
                    adhanMediaSession?.sessionToken?.let { style.setMediaSession(it) }
                    style.setShowActionsInCompactView(0) // show stop button in compact view
                }
            )
            .addAction(stopAction)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val isAr = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.app_language", "ar") == "ar"
            val channel = NotificationChannel(
                CHANNEL_ID,
                if (isAr) "أذان" else "Adhan",
                NotificationManager.IMPORTANCE_HIGH   // shows heads-up banner when screen is on
            ).apply {
                description = "Adhan prayer time alert"
                setSound(null, null)          // audio comes from MediaPlayer, not the notification
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC  // show stop controls on lock screen
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }
}