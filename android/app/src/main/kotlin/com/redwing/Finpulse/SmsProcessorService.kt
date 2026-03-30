package com.redwing.Finpulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * A foreground Service that processes incoming SMS messages.
 *
 * When an SMS arrives:
 *  - If the Flutter EventChannel is active (app in foreground), push directly.
 *  - Otherwise, append the SMS data to a SharedPreferences JSON queue so that
 *    MainActivity can drain it the next time the app is opened.
 *
 * The service shows a persistent foreground notification (required by Android 8+
 * for services that outlive the activity).
 */
class SmsProcessorService : Service() {

    companion object {
        private const val TAG = "SmsProcessorService"
        const val CHANNEL_ID = "sms_processor_channel"
        const val TRANSACTION_CHANNEL_ID = "transaction_channel"
        const val PREF_FILE = "finpulse_sms_cache"
        const val PREF_KEY_PENDING = "pending_sms"

        const val EXTRA_BODY = "body"
        const val EXTRA_SENDER = "sender"
        const val EXTRA_DATE = "date"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Start as foreground with a silent, low-importance notification
        startForeground(1, buildForegroundNotification())

        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""
        val sender = intent?.getStringExtra(EXTRA_SENDER) ?: ""
        val date = intent?.getLongExtra(EXTRA_DATE, System.currentTimeMillis()) ?: System.currentTimeMillis()

        Log.d(TAG, "Processing SMS from $sender")

        val smsData = mapOf(
            "body" to body,
            "sender" to sender,
            "date" to date
        )

        // Try to push to Flutter's EventChannel (works when app is in foreground)
        val eventSink = MainActivity.eventSink
        if (eventSink != null) {
            Log.d(TAG, "Pushing SMS to live EventChannel")
            // Post on the main thread — EventChannel requires it
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                eventSink.success(smsData)
            }
        } else {
            // App is in background — cache to SharedPreferences
            Log.d(TAG, "App in background, caching SMS to SharedPreferences")
            cacheSms(body, sender, date)
        }

        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun cacheSms(body: String, sender: String, date: Long) {
        val prefs = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
        val existing = prefs.getString(PREF_KEY_PENDING, "[]")
        val array = try {
            JSONArray(existing)
        } catch (e: Exception) {
            JSONArray()
        }

        val obj = JSONObject().apply {
            put("body", body)
            put("sender", sender)
            put("date", date)
        }
        array.put(obj)

        prefs.edit().putString(PREF_KEY_PENDING, array.toString()).apply()
        Log.d(TAG, "Cached SMS. Queue size: ${array.length()}")
    }

    private fun buildForegroundNotification() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FinPulse")
            .setContentText("Monitoring transaction SMS...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .build()

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)

            // Silent channel for foreground service
            mgr.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "SMS Processor",
                    NotificationManager.IMPORTANCE_MIN
                ).apply { description = "Background SMS monitoring" }
            )

            // Visible channel for new transaction alerts
            mgr.createNotificationChannel(
                NotificationChannel(
                    TRANSACTION_CHANNEL_ID,
                    "Transaction Alerts",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Notifications for auto-imported transactions" }
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
