package com.usmanhotel.active_orders

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.IBinder
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class OrderPollingService : Service() {
    private val defaultHost = "https://usman-hotel-pos-server-production.up.railway.app"
    private val syncChannelId = "active_orders_background_sync"
    private val alertChannelId = "active_orders_background_new_orders_v3"
    private val notificationManager by lazy { getSystemService(NotificationManager::class.java) }
    @Volatile private var running = false
    private var worker: Thread? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannels()
        startForeground(2001, buildSyncNotification())
        startWorker()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startWorker() {
        if (running) return
        running = true
        worker = Thread {
            while (running) {
                try {
                    pollOnce()
                    Thread.sleep(1000)
                } catch (_: InterruptedException) {
                    running = false
                } catch (_: Exception) {
                    try {
                        Thread.sleep(3000)
                    } catch (_: InterruptedException) {
                        running = false
                    }
                }
            }
        }.apply {
            name = "ActiveOrdersPolling"
            isDaemon = true
            start()
        }
    }

    private fun pollOnce() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.activeOrdersToken", "").orEmpty()
        if (token.isBlank()) return

        val host = normalizeHost(prefs.getString("flutter.serverUrl", defaultHost).orEmpty())
        val url = URL("$host/api/pos/orders")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 20000
            readTimeout = 20000
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "application/json")
        }
        try {
            if (conn.responseCode >= 400) return
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val orders = JSONArray(body)
            val activeIds = LinkedHashSet<String>()
            val freshLabels = ArrayList<String>()
            val savedSeen = prefs.getStringSet("backgroundSeenOrderIds", null)?.toHashSet()

            for (i in 0 until orders.length()) {
                val order = orders.optJSONObject(i) ?: continue
                if (!isActiveDineIn(order.optString("orderType"), order.optString("status"))) continue
                val id = order.optString("id")
                if (id.isBlank()) continue
                activeIds.add(id)
                if (savedSeen != null && !savedSeen.contains(id)) {
                    val number = order.optString("orderNumber").ifBlank { id }
                    val table = order.optString("tableNumber").ifBlank { "-" }
                    freshLabels.add("Table $table (#$number)")
                }
            }

            prefs.edit().putStringSet("backgroundSeenOrderIds", activeIds).apply()
            if (savedSeen != null && freshLabels.isNotEmpty() && !prefs.getBoolean("flutter.activeOrdersAppForeground", false)) {
                showNewOrderAlert(freshLabels)
                playNewOrderTone()
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun normalizeHost(raw: String): String {
        val trimmed = raw.trim().trimEnd('/')
        val lower = trimmed.lowercase(Locale.US)
        if (trimmed.isBlank() || lower.contains("localhost") || lower.contains("127.0.0.1")) return defaultHost
        if (Regex("https?://(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.)").containsMatchIn(lower)) return defaultHost
        return if (lower.endsWith("/api")) trimmed.dropLast(4) else trimmed
    }

    private fun isActiveDineIn(type: String, status: String): Boolean {
        if (type != "Dine-In") return false
        val normalized = status.trim().lowercase(Locale.US).replace(Regex("\\s+"), " ")
        return normalized != "completed" && normalized != "payment collected" && normalized != "cancelled"
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager.createNotificationChannel(
            NotificationChannel(syncChannelId, "Active Orders Sync", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Keeps the Railway order sync running in the background"
                setSound(null, null)
            }
        )
        notificationManager.createNotificationChannel(
            NotificationChannel(alertChannelId, "Background New Order Alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Loud alerts for new dine-in orders while the app is in background"
                enableVibration(true)
                vibrationPattern = longArrayOf(700, 200, 700, 200, 700)
            }
        )
    }

    private fun buildSyncNotification(): Notification {
        return builder(syncChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Active Orders sync running")
            .setContentText("Railway orders background sync is active")
            .setOngoing(true)
            .setContentIntent(openAppIntent())
            .build()
    }

    private fun showNewOrderAlert(labels: List<String>) {
        val count = labels.size
        val title = if (count == 1) "New Dine-In Order" else "$count New Dine-In Orders"
        val body = labels.take(3).joinToString(" | ")
        val notification = builder(alertChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(700, 200, 700, 200, 700))
            .setContentIntent(openAppIntent())
            .build()
        notificationManager.notify(3000 + (System.currentTimeMillis() % 1000).toInt(), notification)
    }

    private fun builder(channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }
    }

    private fun openAppIntent(): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), flags)
    }

    private fun playNewOrderTone() {
        Thread {
            try {
                val tone = ToneGenerator(AudioManager.STREAM_ALARM, 100)
                repeat(4) {
                    tone.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 550)
                    Thread.sleep(750)
                }
                tone.release()
            } catch (_: Exception) {}
        }.start()
    }
}
