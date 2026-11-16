package com.lifesync.tracker.lifesync_tracker

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val PREFS_NAME = "lifesync_auto_payment_prefs"
        private const val KEY_PENDING_NOTIFICATIONS = "pending_payment_notifications"
        private const val MAX_BUFFER_SIZE = 50

        // Comprehensive list of UPI apps, Private & Public Banks, and Neo-Banks in India
        private val TARGET_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay (Tez)
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                       // Paytm
            "com.dreamplug.androidapp",              // CRED
            "in.org.npci.upiapp",                    // BHIM UPI
            "com.amazon.mShop.android.shopping",     // Amazon Pay
            "com.freecharge.android",                // Freecharge
            "com.mobikwik_new",                      // MobiKwik
            "com.axis.mobile",                       // Axis Mobile
            "com.msf.kbank.mobile",                  // Kotak Bank
            "com.snapwork.hdfc",                     // HDFC Bank
            "com.csam.icici.bank.imobile",           // ICICI iMobile
            "com.sbi.lotusintouch",                  // SBI Yono
            "money.jupiter",                         // Jupiter Neo-Bank
            "co.epifi.gro",                          // Fi Money
            "org.slice",                             // Slice
            "com.indusind.indie",                    // IndusInd Indie
            "com.bankofbaroda.mconnect",             // Bank of Baroda (bob World)
            "com.canarabank.mobility",               // Canara Bank
            "com.pnb.pnbone",                        // PNB ONE
            "com.infrasofttech.uboi",                // Union Bank
            "com.idfcfirstbank.optimus",             // IDFC FIRST Bank
            "com.myairtelapp",                       // Airtel Payments Bank
            "com.tatadigital.tcp",                   // Tata Neu
            "com.postpe.app",                        // Postpe
            "com.navi.app",                          // Navi
            "com.fampay.in",                         // FamPay
            "com.finvu.app"                          // Finvu Account Aggregator
        )

        // Comprehensive transactional keywords covering all Indian bank debit, credit & UPI patterns
        private val STRICT_TRANSACTION_KEYWORDS = listOf(
            // Debit & Expenses
            "debited", "debited from", "debited by", "debited for", "debit of",
            "paid to", "paid successfully", "payment successful", "payment of", "you paid",
            "spent on", "spent at", "spent", "charged", "card charged",
            "deducted", "autopay deducted", "autopay executed",
            "withdrawn", "cash withdrawal", "atm withdrawal", "withdrawal of",
            "transferred to", "transfer successful", "sent to",
            "bill payment", "recharge of", "purchase of", "dr by", "dr of", "dr.",

            // Credit & Income
            "credited", "credited to", "credited with", "amount credited", "credit of",
            "received from", "money received", "payment received", "received payment", "you received",
            "transferred from", "transferred to your account",
            "salary", "salary credit", "salary of",
            "cashback", "cashback received", "cashback of", "cashback credited",
            "refund", "refund received", "refund of", "refund credited",
            "inward transfer", "neft inward", "neft credit", "imps inward", "imps credit", "rtgs",
            "deposit", "deposit successful", "cr by", "cr of", "cr.",

            // Identifiers
            "upi ref", "utr:", "txn id", "transaction ref"
        )

        // Promotional blocklist: Reject marketing, ads, and sales
        private val PROMOTIONAL_BLOCKLIST = listOf(
            "starting at", "starts at", "starting from", "start at",
            "upto", "up to", "flat off", "discount", "% off", "coupon",
            "use code", "promo", "deal of", "sale is live", "toys",
            "shop now", "order now", "buy now", "save extra", "extra fun",
            "playtime", "cashback upto", "win upto", "spin & win", "trending",
            "recommend", "exclusive offer", "cart", "wishlist"
        )

        // Chat & social apps to strictly ignore
        private val IGNORED_PACKAGES = setOf(
            "com.whatsapp", "com.whatsapp.w4b",
            "org.telegram.messenger", "org.thunderdog.challegram",
            "com.instagram.android",
            "com.snapchat.android",
            "com.facebook.katana", "com.facebook.orca",
            "com.twitter.android", "com.google.android.talk"
        )

        var onNotificationCaptured: ((Map<String, Any>) -> Unit)? = null

        fun getAndClearPendingNotifications(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_PENDING_NOTIFICATIONS, "[]") ?: "[]"
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
                prefs.edit().putString(KEY_PENDING_NOTIFICATIONS, "[]").apply()
            } catch (_: Exception) {}
            return result
        }

        private fun savePendingNotification(context: Context, payload: Map<String, Any>) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val jsonStr = prefs.getString(KEY_PENDING_NOTIFICATIONS, "[]") ?: "[]"
                val array = JSONArray(jsonStr)
                if (array.length() >= MAX_BUFFER_SIZE) {
                    array.remove(0)
                }
                array.put(JSONObject(payload))
                prefs.edit().putString(KEY_PENDING_NOTIFICATIONS, array.toString()).apply()
            } catch (_: Exception) {}
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkgName = sbn.packageName ?: ""

        // 1. NEVER listen to our own notifications! (Prevents feedback loops)
        if (pkgName == packageName || pkgName.contains("lifesync")) return

        // 2. NEVER listen to chat or social apps
        if (IGNORED_PACKAGES.contains(pkgName)) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

        val combinedContent = "$title $text $bigText $subText".lowercase()

        // 3. Reject any notification that looks like an ad or promotional pitch
        val isPromotional = PROMOTIONAL_BLOCKLIST.any { combinedContent.contains(it) }
        if (isPromotional) return

        // 4. Must contain transaction confirmation keyword (debited, credited, spent, paid, received, etc.)
        val hasStrictTransactionKeyword = STRICT_TRANSACTION_KEYWORDS.any { combinedContent.contains(it) }
        if (!hasStrictTransactionKeyword) return

        // 5. Must contain currency (₹, rs, inr, dr, cr)
        val hasCurrency = combinedContent.contains("₹") ||
                combinedContent.contains("rs.") ||
                combinedContent.contains("rs ") ||
                combinedContent.contains("inr") ||
                combinedContent.contains("dr") ||
                combinedContent.contains("cr")

        if (!hasCurrency) return

        val fullText = if (bigText.isNotEmpty()) "$title\n$bigText" else "$title\n$text"
        val payload: Map<String, Any> = mapOf(
            "packageName" to pkgName,
            "title" to title,
            "body" to fullText,
            "subText" to subText,
            "timestamp" to sbn.postTime,
            "source" to "notification"
        )

        onNotificationCaptured?.invoke(payload)
        savePendingNotification(applicationContext, payload)
    }
}
