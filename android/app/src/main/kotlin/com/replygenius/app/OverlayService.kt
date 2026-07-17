package com.replygenius.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

/**
 * Foreground service that draws a draggable floating bubble over the user's
 * chat (WhatsApp/SMS) showing AI-generated reply variants.
 *
 * Lifecycle:
 *   - Started via Intent action ACTION_SHOW with extras (sender, message, anger, variants JSON)
 *   - Draws a small floating handle (chip) at the top-right of the screen
 *   - Tapping the handle expands a card with the variants
 *   - Each variant has a Copy button that copies the text to clipboard
 *   - ACTION_CLOSE removes the overlay (and stops the service)
 *
 * Foreground notification keeps the service alive while bubble is shown.
 */
class OverlayService : Service() {

    companion object {
        const val ACTION_SHOW = "com.replygenius.app.SHOW_OVERLAY"
        const val ACTION_CLOSE = "com.replygenius.app.CLOSE_OVERLAY"
        private const val CHANNEL_ID = "replygenius_overlay"
        private const val NOTIF_ID = 9090
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var cardView: View? = null
    private var cardVisible = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                startForegroundCompat()
                val sender = intent.getStringExtra("sender") ?: "Customer"
                val message = intent.getStringExtra("message") ?: ""
                val anger = intent.getIntExtra("angerScore", 3)
                val variantsJson = intent.getStringExtra("variants") ?: "[]"
                showBubble(sender, message, anger, variantsJson)
            }
            ACTION_CLOSE -> {
                hideAll()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ReplyGenius overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the reply bubble alive while you chat"
                setShowBadge(false)
            }
            mgr.createNotificationChannel(channel)
        }
        val notif = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("ReplyGenius is watching")
            .setContentText("Tap a customer message to see reply suggestions")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, notif, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    // ------------------------------------------------------------
    // Bubble = small chip floating at top-right; tap to expand card.
    // ------------------------------------------------------------
    private fun showBubble(sender: String, message: String, anger: Int, variantsJson: String) {
        hideAll()

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 24
            y = 200
        }

        val chip = TextView(this).apply {
            text = "✨ Reply"
            setTextColor(Color.WHITE)
            setPadding(dp(16), dp(8), dp(16), dp(8))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#4F46E5"))
            }
            elevation = dp(6).toFloat()
        }
        chip.setOnClickListener {
            cardVisible = !cardVisible
            cardView?.visibility = if (cardVisible) View.VISIBLE else View.GONE
        }
        chip.setOnTouchListener(DragHandler(params) { p -> windowManager?.updateViewLayout(chip, p) })

        bubbleView = chip
        windowManager?.addView(chip, params)

        // Build the expansion card
        val cardParams = WindowManager.LayoutParams(
            dp(320),
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 16
            y = 260
        }
        val card = buildCard(sender, message, anger, variantsJson)
        card.visibility = View.GONE
        cardView = card
        windowManager?.addView(card, cardParams)
        cardVisible = false
        // Auto-expand on arrival so the user immediately sees the variants
        card.post {
            card.visibility = View.VISIBLE
            cardVisible = true
        }
    }

    private fun buildCard(sender: String, message: String, anger: Int, variantsJson: String): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.parseColor("#E2E8F0"))
            }
            elevation = dp(10).toFloat()
        }

        // Header
        val header = TextView(this).apply {
            text = "ReplyGenius • ${sender.take(20)}"
            setTextColor(Color.parseColor("#4F46E5"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(0, 0, 0, dp(6))
        }
        container.addView(header)

        // Anger badge
        val badgeColor = when (anger) {
            1, 2 -> Color.parseColor("#10B981")
            3 -> Color.parseColor("#F59E0B")
            else -> Color.parseColor("#EF4444")
        }
        val badge = TextView(this).apply {
            text = "Anger $anger/5"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setPadding(dp(8), dp(3), dp(8), dp(3))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(badgeColor)
            }
        }
        container.addView(badge)

        // Customer message preview
        val msgPreview = TextView(this).apply {
            text = "\"${message.take(140)}\""
            setTextColor(Color.parseColor("#991B1B"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(0, dp(8), 0, dp(8))
        }
        container.addView(msgPreview)

        // Variants
        try {
            val arr = JSONArray(variantsJson)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i)
                val text = obj?.optString("text") ?: continue
                val style = obj?.optString("style") ?: "calm"
                container.addView(buildVariantRow(style, text))
            }
        } catch (e: Exception) {
            val err = TextView(this).apply {
                text = "Failed to parse variants: ${e.message}"
                setTextColor(Color.RED)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            }
            container.addView(err)
        }

        // Close button
        val closeBtn = TextView(this).apply {
            text = "Dismiss"
            setTextColor(Color.parseColor("#64748B"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(0, dp(8), 0, 0)
            gravity = Gravity.END
            setOnClickListener {
                hideAll()
                stopSelf()
            }
        }
        container.addView(closeBtn)

        return container
    }

    private fun buildVariantRow(style: String, replyText: String): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(10), dp(10), dp(10))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(8) }
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor("#F0FDF4"))
                setStroke(dp(1), Color.parseColor("#BBF7D0"))
            }
        }

        val styleLabel = TextView(this).apply {
            this.text = style.uppercase()
            setTextColor(Color.parseColor("#166534"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            setPadding(0, 0, 0, dp(4))
        }
        row.addView(styleLabel)

        val body = TextView(this).apply {
            this.text = replyText
            setTextColor(Color.parseColor("#0F172A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setLineSpacing(dp(2).toFloat(), 1f)
        }
        row.addView(body)

        val copyBtn = TextView(this).apply {
            text = "Tap to copy"
            setTextColor(Color.parseColor("#4F46E5"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(0, dp(6), 0, 0)
            gravity = Gravity.END
            setOnClickListener {
                val clip = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clip.setPrimaryClip(ClipData.newPlainText("ReplyGenius", replyText))
                Toast.makeText(this@OverlayService, "Reply copied — paste in chat", Toast.LENGTH_SHORT).show()
                hideAll()
                stopSelf()
            }
        }
        row.addView(copyBtn)

        return row
    }

    private fun hideAll() {
        bubbleView?.let { v ->
            try { windowManager?.removeView(v) } catch (_: Exception) {}
        }
        cardView?.let { v ->
            try { windowManager?.removeView(v) } catch (_: Exception) {}
        }
        bubbleView = null
        cardView = null
        cardVisible = false
    }

    override fun onDestroy() {
        hideAll()
        super.onDestroy()
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics
    ).toInt()

    /**
     * Lets the user drag the floating chip anywhere on the screen.
     */
    private inner class DragHandler(
        private val params: WindowManager.LayoutParams,
        private val onUpdate: (WindowManager.LayoutParams) -> Unit
    ) : View.OnTouchListener {
        private var initialX = 0
        private var initialY = 0
        private var initialTouchX = 0f
        private var initialTouchY = 0f

        override fun onTouch(v: View?, event: MotionEvent?): Boolean {
            if (event == null) return false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt() * -1 // END gravity
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    onUpdate(params)
                    return true
                }
            }
            return false
        }
    }
}
