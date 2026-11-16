package com.lifesync.tracker.lifesync_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.telephony.SmsMessage
import org.json.JSONArray
import org.json.JSONObject

class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val PREFS_NAME = "lifesync_auto_payment_prefs"
        private const val KEY_PENDING_SMS = "pending_payment_sms"
        private const val MAX_BUFFER_SIZE = 50

        private val TRANSACTION_KEYWORDS = listOf(
            "debited", "credited", "spent", "paid", "txn", "acct", "a/c", "inr", "rs.", "rs ", "₹", "upi", "vpa", "withdrawn"
        )

        var onSmsReceived: ((Map<String, Any>) -> Unit)? = null

        fun getAndClearPendingSms(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_PENDING_SMS, "[]") ?: "[]"
            val result = mutableListOf<Map<String, Any>>()
            try {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val map = mutableMapOf<String, Any>()
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = obj.get(key)
                    }
                    result.add(map)
                }
            } catch (_: Exception) {}

            prefs.edit().remove(KEY_PENDING_SMS).apply()
            return result
        }

        fun savePendingSms(context: Context, data: Map<String, Any>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_PENDING_SMS, "[]") ?: "[]"
            try {
                val array = JSONArray(jsonStr)
                val newObj = JSONObject(data)
                array.put(newObj)

                // Limit buffer size
                val trimmedArray = JSONArray()
                val start = if (array.length() > MAX_BUFFER_SIZE) array.length() - MAX_BUFFER_SIZE else 0
                for (i in start until array.length()) {
                    trimmedArray.put(array.get(i))
                }

                prefs.edit().putString(KEY_PENDING_SMS, trimmedArray.toString()).apply()
            } catch (_: Exception) {}
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        val bundle: Bundle? = intent.extras
        if (bundle != null) {
            try {
                val pdus = bundle.get("pdus") as? Array<*> ?: return
                val format = bundle.getString("format")

                val senderBuilder = StringBuilder()
                val bodyBuilder = StringBuilder()
                var timestamp = System.currentTimeMillis()

                for (pdu in pdus) {
                    val pduBytes = pdu as? ByteArray ?: continue
                    val sms: SmsMessage = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        SmsMessage.createFromPdu(pduBytes, format)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsMessage.createFromPdu(pduBytes)
                    }

                    if (senderBuilder.isEmpty()) {
                        senderBuilder.append(sms.originatingAddress ?: "Bank")
                        timestamp = sms.timestampMillis
                    }
                    bodyBuilder.append(sms.messageBody ?: "")
                }

                val fullBody = bodyBuilder.toString()
                val sender = senderBuilder.toString()
                val lowerBody = fullBody.lowercase()

                // Check if this looks like a financial transaction message
                val isFinancial = TRANSACTION_KEYWORDS.any { lowerBody.contains(it) }
                if (!isFinancial) return

                val payload: Map<String, Any> = mapOf(
                    "sender" to sender,
                    "body" to fullBody,
                    "timestamp" to timestamp,
                    "source" to "sms"
                )

                onSmsReceived?.invoke(payload)
                savePendingSms(context, payload)
            } catch (_: Exception) {}
        }
    }
}

