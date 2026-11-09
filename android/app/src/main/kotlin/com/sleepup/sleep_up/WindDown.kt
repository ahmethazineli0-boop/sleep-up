package com.sleepup.sleep_up

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Rahatlama hatırlatmasını AlarmManager ile kurar. */
object WindDown {
    private const val CHANNEL = "wind_down"
    private const val NOTIF_ID = 2301

    fun schedule(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(ctx)
        am.cancel(pi)
        val store = LockStore(ctx)
        val s = store.schedule() ?: return
        if (!s.windDownEnabled) return
        val now = System.currentTimeMillis()
        // Bir sonraki gecenin hatırlatma anı; geçtiyse ondan sonrakini bul.
        var from = now
        repeat(8) {
            val start = store.nextStart(from)
            if (start == 0L) return
            val at = start - s.windDownMinutes * 60_000L
            if (at > now) {
                // Kesin alarm izni gerektirmeyen, Doze'da da çalışan yaklaşık alarm.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, at, pi)
                }
                return
            }
            from = start + 1
        }
    }

    private fun pending(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
        ctx, 0, Intent(ctx, WindDownReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    fun notify(ctx: Context) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Rahatlama hatırlatması", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val s = LockStore(ctx).schedule()
        val mins = s?.windDownMinutes ?: 30
        val open = PendingIntent.getActivity(
            ctx, 1, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            android.app.Notification.Builder(ctx, CHANNEL) else android.app.Notification.Builder(ctx)
        val n = b.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Rahatlama zamanı")
            .setContentText("$mins dakika sonra uygulamaların kilitlenecek. Ekranı bırakmaya başla.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        nm.notify(NOTIF_ID, n)
    }
}

class WindDownReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        WindDown.notify(ctx)
        WindDown.schedule(ctx) // bir sonraki gece için yeniden kur
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        WindDown.schedule(ctx)
    }
}
