package com.entaku.simpleRecord.notification

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.entaku.simpleRecord.MainActivity
import com.entaku.simpleRecord.R

class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ReminderScheduler.ACTION_D1 -> showNotification(
                context = context,
                notificationId = 1001,
                title = "今日も録音してみませんか？",
                body = "シンプル録音でいつでも簡単に録音できます。",
            )
            ReminderScheduler.ACTION_D3 -> showNotification(
                context = context,
                notificationId = 1003,
                title = "録音を振り返りませんか？",
                body = "録音した音声をいつでも聴き返せます。",
            )
            Intent.ACTION_BOOT_COMPLETED -> {
                // 再起動後にアラームが消えるため再スケジュール
                ReminderScheduler.scheduleIfNeeded(context)
            }
        }
    }

    private fun showNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
    ) {
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, ReminderScheduler.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
    }
}
