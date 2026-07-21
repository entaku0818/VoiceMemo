package com.entaku.simpleRecord.record

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.entaku.simpleRecord.MainActivity
import com.entaku.simpleRecord.R
import java.lang.ref.WeakReference

/**
 * 通知(Notification)上のアクションボタンから録音の一時停止・再開・停止を要求された際に
 * 呼び出されるコールバック。RecordViewModel が録音開始時に実装を登録し、録音終了時に解除する。
 */
interface RecordingActionListener {
    fun onPauseRequested()
    fun onResumeRequested()
    fun onStopRequested()
}

/**
 * 録音中にロック画面/通知シェードから経過時間・音量を確認し、一時停止/再開・停止を操作できるよう
 * 常時通知(ongoing notification)を表示するための Foreground Service。
 *
 * iOS の Live Activity (ios/VoiLog/Recording/LiveActivityClient.swift) 相当の体験を
 * Android で提供する (issue #197)。
 *
 * MediaRecorder 自体の管理は [RecordViewModel] が引き続き担う。このServiceは
 * ongoing notification の表示と、通知上のアクションを [RecordingActionListener] 経由で
 * ViewModel に転送する役割のみを持つ。
 */
class RecordingNotificationService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE -> actionListener?.onPauseRequested()
            ACTION_RESUME -> actionListener?.onResumeRequested()
            ACTION_STOP -> actionListener?.onStopRequested()
            ACTION_UPDATE -> {
                val baseTime = intent.getLongExtra(EXTRA_BASE_TIME, System.currentTimeMillis())
                val isPaused = intent.getBooleanExtra(EXTRA_PAUSED, false)
                val volume = intent.getIntExtra(EXTRA_VOLUME, 0)
                showForegroundNotification(baseTime, isPaused, volume)
            }
            else -> {
                val baseTime = intent?.getLongExtra(EXTRA_BASE_TIME, System.currentTimeMillis())
                    ?: System.currentTimeMillis()
                showForegroundNotification(baseTime, isPaused = false, volume = 0)
            }
        }
        return START_NOT_STICKY
    }

    private fun showForegroundNotification(baseTimeMillis: Long, isPaused: Boolean, volume: Int) {
        val notification = buildNotification(baseTimeMillis, isPaused, volume)
        // FOREGROUND_SERVICE_TYPE_MICROPHONE はAPI 30から。minSdk(29)ではこの分岐が必要。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun actionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, RecordingNotificationService::class.java).apply { this.action = action }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildNotification(baseTimeMillis: Long, isPaused: Boolean, volume: Int): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            REQUEST_CODE_CONTENT,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val pauseResumeAction = if (isPaused) {
            NotificationCompat.Action(
                R.drawable.ic_notification_mic,
                getString(R.string.resume),
                actionPendingIntent(ACTION_RESUME, REQUEST_CODE_RESUME)
            )
        } else {
            NotificationCompat.Action(
                R.drawable.ic_notification_mic,
                getString(R.string.pause),
                actionPendingIntent(ACTION_PAUSE, REQUEST_CODE_PAUSE)
            )
        }

        val stopAction = NotificationCompat.Action(
            R.drawable.ic_notification_mic,
            getString(R.string.stop),
            actionPendingIntent(ACTION_STOP, REQUEST_CODE_STOP)
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_mic)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentIntent)
            .addAction(pauseResumeAction)
            .addAction(stopAction)

        if (isPaused) {
            val elapsedText = formatElapsed(elapsedSecondsSince(baseTimeMillis))
            builder
                .setContentTitle(getString(R.string.recording_notification_title_paused))
                .setUsesChronometer(false)
                .setContentText("$elapsedText ・ ${getString(R.string.volume_label, volume)}")
        } else {
            builder
                .setContentTitle(getString(R.string.recording_notification_title))
                .setUsesChronometer(true)
                .setWhen(baseTimeMillis)
                .setContentText(getString(R.string.volume_label, volume))
        }

        return builder.build()
    }

    companion object {
        const val CHANNEL_ID = "recording_status_channel"
        private const val NOTIFICATION_ID = 2001

        const val ACTION_PAUSE = "com.entaku.simpleRecord.record.ACTION_PAUSE"
        const val ACTION_RESUME = "com.entaku.simpleRecord.record.ACTION_RESUME"
        const val ACTION_STOP = "com.entaku.simpleRecord.record.ACTION_STOP"
        private const val ACTION_UPDATE = "com.entaku.simpleRecord.record.ACTION_UPDATE"

        private const val EXTRA_BASE_TIME = "extra_base_time"
        private const val EXTRA_PAUSED = "extra_paused"
        private const val EXTRA_VOLUME = "extra_volume"

        private const val REQUEST_CODE_CONTENT = 2101
        private const val REQUEST_CODE_PAUSE = 2102
        private const val REQUEST_CODE_RESUME = 2103
        private const val REQUEST_CODE_STOP = 2104

        // 実際の強参照は RecordViewModel 側のフィールドが保持する。ここではWeakReferenceのみ
        // 保持することで、companion(static)フィールドがContextを間接的に保持し続ける
        // (lint: StaticFieldLeak) ことを避ける。
        @Volatile
        private var actionListenerRef: WeakReference<RecordingActionListener>? = null

        /**
         * 通知のアクションボタンが押された際に呼び出されるリスナー。
         * RecordViewModel が録音開始時に自身を登録し、録音終了時に null に戻す。
         */
        var actionListener: RecordingActionListener?
            get() = actionListenerRef?.get()
            set(value) {
                actionListenerRef = value?.let { WeakReference(it) }
            }

        fun createNotificationChannel(context: Context) {
            // minSdk(29) は常に O(26) 以上のため、バージョン分岐は不要 (NotificationChannel は API 26+)。
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.recording_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.recording_notification_channel_description)
                setShowBadge(false)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        /** 録音開始時に呼び出し、ongoing notification の表示を開始する。 */
        fun start(context: Context, baseTimeMillis: Long) {
            val intent = Intent(context, RecordingNotificationService::class.java).apply {
                putExtra(EXTRA_BASE_TIME, baseTimeMillis)
            }
            context.startForegroundService(intent)
        }

        /** 経過時間の基準時刻・一時停止状態・音量を更新して通知を再表示する。 */
        fun updateProgress(context: Context, baseTimeMillis: Long, isPaused: Boolean, volume: Int) {
            val intent = Intent(context, RecordingNotificationService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_BASE_TIME, baseTimeMillis)
                putExtra(EXTRA_PAUSED, isPaused)
                putExtra(EXTRA_VOLUME, volume)
            }
            context.startForegroundService(intent)
        }

        /** 録音終了時に呼び出し、通知とServiceを停止する。 */
        fun stop(context: Context) {
            actionListener = null
            context.stopService(Intent(context, RecordingNotificationService::class.java))
        }

        /** 経過秒数を HH:MM:SS 形式にフォーマットする(純粋関数・テスト用)。 */
        fun formatElapsed(totalSeconds: Long): String {
            val safeSeconds = totalSeconds.coerceAtLeast(0)
            val hours = safeSeconds / 3600
            val minutes = (safeSeconds % 3600) / 60
            val seconds = safeSeconds % 60
            return String.format(java.util.Locale.US, "%02d:%02d:%02d", hours, minutes, seconds)
        }

        /** baseTimeMillis からの経過秒数を計算する(純粋関数・テスト用)。 */
        fun elapsedSecondsSince(baseTimeMillis: Long, nowMillis: Long = System.currentTimeMillis()): Long {
            return ((nowMillis - baseTimeMillis) / 1000).coerceAtLeast(0)
        }
    }
}
