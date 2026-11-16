package com.lifesync.tracker.lifesync_tracker

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.lifesync.tracker/auto_payment"
    private var methodChannel: MethodChannel? = null
    private val SMS_PERMISSION_REQUEST_CODE = 1002

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val readGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    val receiveGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(readGranted && receiveGranted)
                }
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                        SMS_PERMISSION_REQUEST_CODE
                    )
                    result.success(true)
                }
                "readRecentSms" -> {
                    val sinceMs = (call.argument<Number>("sinceTimestamp") ?: 0).toLong()
                    val limit = (call.argument<Int>("limit") ?: 30)
                    val messages = fetchSmsMessages(sinceMs, limit)
                    result.success(messages)
                }
                "isNotificationListenerEnabled" -> {
                    val enabled = isNotificationListenerServiceEnabled()
                    result.success(enabled)
                }
                "openNotificationListenerSettings" -> {
                    openNotificationAccessSettings()
                    result.success(true)
                }
                "getPendingNotifications" -> {
                    val pending = PaymentNotificationListener.getAndClearPendingNotifications(applicationContext)
                    result.success(pending)
                }
                "getPendingSms" -> {
                    val pending = SmsBroadcastReceiver.getAndClearPendingSms(applicationContext)
                    result.success(pending)
                }
                "getRecentScreenshots" -> {
                    val sinceMs = (call.argument<Number>("sinceTimestamp") ?: 0).toLong()
                    val limit = (call.argument<Int>("limit") ?: 20)
                    val screenshots = fetchRecentScreenshots(sinceMs, limit)
                    result.success(screenshots)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Connect real-time listeners to Flutter channel
        PaymentNotificationListener.onNotificationCaptured = { payload ->
            runOnUiThread {
                methodChannel?.invokeMethod("onNotificationReceived", payload)
            }
        }

        SmsBroadcastReceiver.onSmsReceived = { payload ->
            runOnUiThread {
                methodChannel?.invokeMethod("onSmsReceived", payload)
            }
        }
    }

    override fun onDestroy() {
        PaymentNotificationListener.onNotificationCaptured = null
        SmsBroadcastReceiver.onSmsReceived = null
        super.onDestroy()
    }

    private fun isNotificationListenerServiceEnabled(): Boolean {
        val packageName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (flat != null && flat.isNotEmpty()) {
            val names = flat.split(":").toTypedArray()
            for (name in names) {
                if (name.contains(packageName)) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun fetchSmsMessages(sinceMs: Long, limit: Int): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("_id", "address", "body", "date")
        val selection = if (sinceMs > 0) "date >= ?" else null
        val selectionArgs = if (sinceMs > 0) arrayOf(sinceMs.toString()) else null
        val sortOrder = "date DESC LIMIT $limit"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val addressIdx = cursor.getColumnIndex("address")
                val bodyIdx = cursor.getColumnIndex("body")
                val dateIdx = cursor.getColumnIndex("date")

                do {
                    val address = if (addressIdx != -1) cursor.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx != -1) cursor.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx != -1) cursor.getLong(dateIdx) else System.currentTimeMillis()

                    val map = mapOf(
                        "sender" to address,
                        "body" to body,
                        "timestamp" to date,
                        "source" to "sms"
                    )
                    result.add(map)
                } while (cursor.moveToNext())
            }
        } catch (_: Exception) {
        } finally {
            cursor?.close()
        }
        return result
    }

    private fun fetchRecentScreenshots(sinceMs: Long, limit: Int): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_MODIFIED
        )

        // Find images in Screenshot folders or containing Screenshot in file/bucket name
        val selection = if (sinceMs > 0) {
            "(${MediaStore.Images.Media.DATA} LIKE '%Screenshot%' OR ${MediaStore.Images.Media.BUCKET_DISPLAY_NAME} LIKE '%Screenshot%') AND ${MediaStore.Images.Media.DATE_MODIFIED} >= ?"
        } else {
            "${MediaStore.Images.Media.DATA} LIKE '%Screenshot%' OR ${MediaStore.Images.Media.BUCKET_DISPLAY_NAME} LIKE '%Screenshot%'"
        }

        val sinceSeconds = sinceMs / 1000
        val selectionArgs = if (sinceMs > 0) arrayOf(sinceSeconds.toString()) else null
        val sortOrder = "${MediaStore.Images.Media.DATE_MODIFIED} DESC LIMIT $limit"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val dataIdx = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                val nameIdx = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
                val dateIdx = cursor.getColumnIndex(MediaStore.Images.Media.DATE_MODIFIED)

                do {
                    val path = if (dataIdx != -1) cursor.getString(dataIdx) ?: "" else ""
                    val name = if (nameIdx != -1) cursor.getString(nameIdx) ?: "" else ""
                    val dateSec = if (dateIdx != -1) cursor.getLong(dateIdx) else 0L

                    if (path.isNotEmpty()) {
                        val map = mapOf(
                            "path" to path,
                            "displayName" to name,
                            "timestamp" to (dateSec * 1000),
                            "source" to "screenshot"
                        )
                        result.add(map)
                    }
                } while (cursor.moveToNext())
            }
        } catch (_: Exception) {
        } finally {
            cursor?.close()
        }
        return result
    }
}
