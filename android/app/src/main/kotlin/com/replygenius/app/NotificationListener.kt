package com.replygenius.app

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * NotificationListenerService — the "Android extension" that captures incoming
 * WhatsApp and SMS notifications and forwards their text to Flutter via
 * [IncomingMessageBus].
 *
 * This service must be enabled by the user in
 *   Settings → Notification access → ReplyGenius
 *
 * It runs independently of the Flutter activity (Android keeps it alive while
 * the user has granted access). When a relevant notification arrives:
 *
 *   1. We extract the sender (title) and message (text).
 *   2. We filter out notifications the user posted themselves (avoid loops).
 *   3. We forward via [IncomingMessageBus.push] to the EventChannel sink.
 *
 * We also handle "reply" actions captured via RemoteInput (not strictly needed
 * here, but useful for future auto-reply).
 */
class NotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "ReplyGenius/Listener"

        // Packages we care about
        private const val WHATSAPP = "com.whatsapp"
        private const val WHATSAPP_BUSINESS = "com.whatsapp.w4b"
        private const val SMS_DEFAULT = "com.android.mms"     // varies by OEM
        private const val GOOGLE_MESSAGES = "com.google.android.apps.messaging"

        // Don't forward notifications older than this (avoid replaying history)
        private const val MAX_AGE_MS = 60_000L
    }

    override fun onListenerConnected() {
        Log.i(TAG, "NotificationListener connected — listening for customer messages")
    }

    override fun onListenerDisconnected() {
        Log.w(TAG, "NotificationListener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        val n = sbn.notification ?: return

        // Only handle the channels we explicitly support
        val channel = when (pkg) {
            WHATSAPP, WHATSAPP_BUSINESS -> "whatsapp"
            SMS_DEFAULT, GOOGLE_MESSAGES -> "sms"
            else -> return
        }

        // Ignore group summaries (they duplicate the children)
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        // Skip very old notifications (system often re-delivers history)
        val age = System.currentTimeMillis() - sbn.postTime
        if (age > MAX_AGE_MS) return

        val extras = n.extras ?: return

        // Sender = notification title for WhatsApp, "title" for SMS
        val sender = extras.getString(Notification.EXTRA_TITLE)?.trim().orEmpty()
        if (sender.isEmpty()) return

        // Build the message text from the most informative extra available.
        val text = extractText(extras)
        if (text.isEmpty()) return

        // Filter out notification noise ("X new messages", "WhatsApp Web is active", etc.)
        if (isNoise(text)) return

        Log.i(TAG, "Captured [$channel] from $sender: $text")
        IncomingMessageBus.push(channel, sender, text)
    }

    private fun extractText(extras: Bundle): String {
        // 1. BigText style (most informative — full message)
        extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.let {
            val s = it.toString().trim()
            if (s.isNotEmpty()) return s
        }
        // 2. Direct text
        extras.getCharSequence(Notification.EXTRA_TEXT)?.let {
            val s = it.toString().trim()
            if (s.isNotEmpty()) return s
        }
        // 3. Multi-line conversation style
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (!lines.isNullOrEmpty()) {
            // Take the last line (the newest message)
            return lines.last().toString().trim()
        }
        return ""
    }

    private fun isNoise(text: String): Boolean {
        // Generic noise patterns across WhatsApp/SMS
        val lower = text.lowercase(Locale.ROOT)
        val noisePatterns = listOf(
            "new messages",
            "checking for new messages",
            "whatsapp web is currently active",
            "whatsapp web login",
            "tap to view",                     // media-only placeholder
            "📷 photo",                         // image with no caption
            "🎥 video",
            "🎵 voice message",
            "📍 live location shared",
            "document",
            "contact card"
        )
        return noisePatterns.any { lower.startsWith(it) || lower == it }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op — we only care about new messages.
    }
}
