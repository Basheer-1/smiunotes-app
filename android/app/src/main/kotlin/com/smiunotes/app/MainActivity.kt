package com.smiunotes.app

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Minimal FCM delivery bridge. Supabase remains the only identity/data service.
 * FCM is NOT enrolled on startup; the Flutter account flow must obtain explicit
 * user consent and OS permission before asking for a token.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "smiunotes/push"
    private val notificationPermissionRequest = 5127
    private var pendingTokenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smiunotes/external_links")
            .setMethodCallHandler { call, result ->
                if (call.method != "openUrl") {
                    result.notImplemented()
                } else {
                    val raw = call.argument<String>("url")
                    val url = raw?.let { Uri.parse(it) }
                    if (url == null || url.scheme != "https" || url.host.isNullOrEmpty() ||
                        !url.userInfo.isNullOrEmpty()) {
                        result.error("INVALID_URL", "HTTPS URL required.", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, url).apply {
                                addCategory(Intent.CATEGORY_BROWSABLE)
                            })
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("NO_BROWSER", "No app available for link.", null)
                        }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestToken" -> {
                        if (call.argument<Boolean>("consent") != true) {
                            result.error("CONSENT_REQUIRED", "User opt-in required.", null)
                        } else if (pendingTokenResult != null) {
                            result.error("BUSY", "Permission request already in progress.", null)
                        } else if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingTokenResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                notificationPermissionRequest
                            )
                        } else {
                            obtainToken(result)
                        }
                    }
                    "disablePush" -> {
                        getSharedPreferences(SmiuNotesMessagingService.PREFS, MODE_PRIVATE)
                            .edit().putBoolean(SmiuNotesMessagingService.OPTED_IN, false).apply()
                        FirebaseMessaging.getInstance().isAutoInitEnabled = false
                        FirebaseMessaging.getInstance().deleteToken()
                            .addOnCompleteListener { task ->
                                if (task.isSuccessful) result.success(null)
                                else result.error("TOKEN_REMOVE_FAILED", "Unable to remove device token.", null)
                            }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun obtainToken(result: MethodChannel.Result) {
        SmiuNotesMessagingService.createChannel(this)
        FirebaseMessaging.getInstance().isAutoInitEnabled = true
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful || task.result.isNullOrBlank()) {
                result.error("FCM_UNAVAILABLE", "Push token unavailable.", null)
            } else {
                getSharedPreferences(SmiuNotesMessagingService.PREFS, MODE_PRIVATE)
                    .edit().putBoolean(SmiuNotesMessagingService.OPTED_IN, true).apply()
                result.success(task.result)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequest) return
        val result = pendingTokenResult ?: return
        pendingTokenResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            obtainToken(result)
        } else {
            result.error("PERMISSION_DENIED", "Notifications are disabled.", null)
        }
    }
}
