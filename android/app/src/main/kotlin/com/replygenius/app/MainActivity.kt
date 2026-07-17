package com.replygenius.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.app.FlutterApplication
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference

/**
 * Main Flutter activity. Wires up two channels:
 *
 *   1. MethodChannel "replygenius/bridge"  — command/response calls from Flutter
 *   2. EventChannel  "replygenius/events"  — stream of incoming customer messages
 *                                            (pushed here by NotificationListener)
 *
 * Communication with NotificationListenerService uses LocalBroadcastManager
 * (the simplest, most reliable IPC for app-internal services).
 */
class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "replygenius/bridge"
    private val EVENT_CHANNEL = "replygenius/events"

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---- Method channel ----
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationListenerSettings" -> {
                        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    }
                    "isNotificationAccessGranted" -> {
                        result.success(isNotificationAccessGranted)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.canDrawOverlays(this)) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    android.net.Uri.parse("package:$packageName")
                                )
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                                result.success(false)
                            } else {
                                result.success(true)
                            }
                        } else {
                            result.success(true) // Below M: always allowed
                        }
                    }
                    "isOverlayPermissionGranted" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                                Settings.canDrawOverlays(this)
                            else true
                        )
                    }
                    "showOverlay" -> {
                        val sender = call.argument<String>("sender") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val anger = call.argument<Int>("angerScore") ?: 3
                        val variantsJson = call.argument<String>("variants") ?: "[]"
                        val intent = Intent(this, OverlayService::class.java).apply {
                            putExtra("sender", sender)
                            putExtra("message", message)
                            putExtra("angerScore", anger)
                            putExtra("variants", variantsJson)
                            action = OverlayService.ACTION_SHOW
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "closeOverlay" -> {
                        val intent = Intent(this, OverlayService::class.java)
                            .setAction(OverlayService.ACTION_CLOSE)
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ---- Event channel: incoming customer messages ----
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    // Register the global sink so NotificationListener can push events
                    IncomingMessageBus.sink = sink
                }
                override fun onCancel(arguments: Any?) {
                    IncomingMessageBus.sink = null
                    eventSink = null
                }
            })
    }

    private val isNotificationAccessGranted: Boolean
        get() {
            val enabledListeners = Settings.Secure.getString(
                contentResolver, "enabled_notification_listeners"
            ) ?: return false
            return enabledListeners.contains(packageName)
        }
}

/**
 * Static bus used by [NotificationListener] to push incoming customer messages
 * to the Flutter side via the EventChannel sink.
 *
 * We use a thin static reference instead of a full LocalBroadcastManager setup
 * to keep the message hot-path latency-free.
 */
object IncomingMessageBus {
    @Volatile
    var sink: EventChannel.EventSink? = null

    fun push(channel: String, sender: String, text: String) {
        val sink = this.sink ?: return
        val map = HashMap<String, Any>()
        map["id"] = "${System.currentTimeMillis()}_${sender.hashCode()}"
        map["channel"] = channel
        map["sender"] = sender
        map["text"] = text
        map["receivedAt"] = System.currentTimeMillis().toString()
        // EventChannel events must be posted on the main thread.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            sink.success(map)
        }
    }
}

/**
 * Simple Application subclass to keep the process name friendly for the
 * notification listener (Android unbinds listeners whose process is killed
 * via the recent-apps swipe — this is just informational).
 */
class App : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
    }
}
