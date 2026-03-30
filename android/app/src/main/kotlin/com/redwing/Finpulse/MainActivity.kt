package com.redwing.Finpulse

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {

    private val CHANNEL = "sms_channel"
    private val EVENT_CHANNEL = "sms_live_channel"

    companion object {
        /** Non-null when Flutter's EventChannel stream is active (app in foreground). */
        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel ─────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSms" -> {
                        val limit = call.argument<Int>("limit") ?: 500
                        result.success(readSms(limit))
                    }
                    // Drain the SharedPreferences SMS cache written by SmsProcessorService
                    "getPendingSms" -> {
                        result.success(drainPendingSms())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── EventChannel (foreground live stream) ─────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    // ── Read historical SMS from device inbox ─────────────────────────────

    private fun readSms(limit: Int): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val uri: Uri = Telephony.Sms.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE
        )
        val cursor: Cursor? = contentResolver.query(
            uri,
            projection,
            "${Telephony.Sms.TYPE} = 1",   // inbox only
            null,
            "${Telephony.Sms.DATE} DESC LIMIT $limit"
        )
        cursor?.use {
            val idIdx     = it.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addrIdx   = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIdx   = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIdx   = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (it.moveToNext()) {
                smsList.add(mapOf(
                    "id"     to (it.getString(idIdx) ?: ""),
                    "sender" to (it.getString(addrIdx) ?: ""),
                    "body"   to (it.getString(bodyIdx) ?: ""),
                    "date"   to it.getLong(dateIdx)
                ))
            }
        }
        return smsList
    }

    // ── Drain pending SMS cached by SmsProcessorService ───────────────────

    private fun drainPendingSms(): List<Map<String, Any>> {
        val prefs = getSharedPreferences(
            SmsProcessorService.PREF_FILE, Context.MODE_PRIVATE
        )
        val raw = prefs.getString(SmsProcessorService.PREF_KEY_PENDING, "[]") ?: "[]"
        val result = mutableListOf<Map<String, Any>>()
        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                result.add(mapOf(
                    "body"   to obj.getString("body"),
                    "sender" to obj.getString("sender"),
                    "date"   to obj.getLong("date")
                ))
            }
            // Clear the cache after draining
            prefs.edit().remove(SmsProcessorService.PREF_KEY_PENDING).apply()
        } catch (e: Exception) {
            // Malformed JSON — clear it
            prefs.edit().remove(SmsProcessorService.PREF_KEY_PENDING).apply()
        }
        return result
    }
}
