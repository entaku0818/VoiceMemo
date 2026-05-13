package com.entaku.simpleRecord.notification

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.entaku.simpleRecord.R
import java.util.concurrent.TimeUnit

object ReminderScheduler {

    private const val PREFS_NAME = "reminder_prefs"
    private const val KEY_INSTALL_DATE = "install_date"
    private const val KEY_D1_SCHEDULED = "d1_scheduled"
    private const val KEY_D3_SCHEDULED = "d3_scheduled"

    const val ACTION_D1 = "com.entaku.simpleRecord.REMINDER_D1"
    const val ACTION_D3 = "com.entaku.simpleRecord.REMINDER_D3"
    const val CHANNEL_ID = "reminder_channel"

    private const val REQUEST_CODE_D1 = 1001
    private const val REQUEST_CODE_D3 = 1003

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = context.getString(R.string.notification_channel_description)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    fun scheduleIfNeeded(context: Context, now: Long = System.currentTimeMillis()) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        if (!prefs.contains(KEY_INSTALL_DATE)) {
            prefs.edit().putLong(KEY_INSTALL_DATE, now).apply()
        }

        val installDate = prefs.getLong(KEY_INSTALL_DATE, now)

        if (!prefs.getBoolean(KEY_D1_SCHEDULED, false)) {
            val triggerAt = calculateD1TriggerTime(installDate)
            if (triggerAt > now) {
                scheduleAlarm(context, triggerAt, ACTION_D1, REQUEST_CODE_D1)
            }
            prefs.edit().putBoolean(KEY_D1_SCHEDULED, true).apply()
        }

        if (!prefs.getBoolean(KEY_D3_SCHEDULED, false)) {
            val triggerAt = calculateD3TriggerTime(installDate)
            if (triggerAt > now) {
                scheduleAlarm(context, triggerAt, ACTION_D3, REQUEST_CODE_D3)
            }
            prefs.edit().putBoolean(KEY_D3_SCHEDULED, true).apply()
        }
    }

    private fun scheduleAlarm(context: Context, triggerAt: Long, action: String, requestCode: Int) {
        val intent = Intent(context, ReminderReceiver::class.java).apply { this.action = action }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
    }

    fun calculateD1TriggerTime(installDate: Long): Long = installDate + TimeUnit.DAYS.toMillis(1)
    fun calculateD3TriggerTime(installDate: Long): Long = installDate + TimeUnit.DAYS.toMillis(3)

    fun isD1Scheduled(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_D1_SCHEDULED, false)

    fun isD3Scheduled(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_D3_SCHEDULED, false)

    fun getInstallDate(context: Context): Long? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return if (prefs.contains(KEY_INSTALL_DATE)) prefs.getLong(KEY_INSTALL_DATE, 0) else null
    }

    // テスト用: SharedPreferences をリセット
    fun resetForTest(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
