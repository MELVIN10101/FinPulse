package com.redwing.Finpulse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log

/**
 * BroadcastReceiver that wakes up on incoming SMS.
 * Immediately delegates processing to SmsProcessorService so the work
 * continues even if the Activity is not alive.
 */
class SmsReceiver : BroadcastReceiver() {
    private val TAG = "SmsReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d(TAG, "onReceive: action = ${intent?.action}")

        if (context == null) return
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        Log.d(TAG, "onReceive: ${messages.size} messages found")

        for (message in messages) {
            val body = message.messageBody ?: continue
            val sender = message.displayOriginatingAddress ?: ""
            val date = message.timestampMillis

            Log.d(TAG, "Forwarding SMS from $sender to SmsProcessorService")

            val serviceIntent = Intent(context, SmsProcessorService::class.java).apply {
                putExtra(SmsProcessorService.EXTRA_BODY, body)
                putExtra(SmsProcessorService.EXTRA_SENDER, sender)
                putExtra(SmsProcessorService.EXTRA_DATE, date)
            }

            // On Android 8+ we must use startForegroundService for background-safe start
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
