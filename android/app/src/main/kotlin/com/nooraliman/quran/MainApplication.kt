package com.nooraliman.quran

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

/**
 * Custom Application class.
 *
 * Creates notification channels at process start so they are guaranteed to exist
 * before any foreground service (including the prayer-times background service
 * which may start on boot) calls startForeground().
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannels()
        }
    }

    private fun createNotificationChannels() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Prayer-times persistent notification channel.
        // Used by flutter_background_service (id: prayer_times_persistent).
        val prayerChannel = NotificationChannel(
            "prayer_times_persistent",
            "مواقيت الصلاة",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "إشعار ثابت يعرض الصلاة الحالية والقادمة والوقت المتبقي"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        nm.createNotificationChannel(prayerChannel)
    }
}
