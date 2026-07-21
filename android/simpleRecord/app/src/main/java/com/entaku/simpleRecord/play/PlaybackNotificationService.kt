package com.entaku.simpleRecord.play

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
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.media.session.MediaButtonReceiver
import com.entaku.simpleRecord.MainActivity
import com.entaku.simpleRecord.R
import java.lang.ref.WeakReference

/**
 * ロック画面/通知シェード・Bluetooth機器・Android Autoから再生/一時停止/シークを要求された際に
 * 呼び出されるコールバック。再生画面のComposableが再生開始時に実装を登録し、
 * 画面を離れる際に解除する。
 */
interface PlaybackActionListener {
    fun onPlayPauseRequested()
    fun onSeekToRequested(positionMs: Long)
    fun onStopRequested()
}

/**
 * 再生中にロック画面/通知シェードから再生状態を確認し、再生/一時停止・シークを操作できるよう
 * MediaSessionCompat + MediaStyle通知を提供するForeground Service。
 *
 * iOS の NowPlayingClient/NowPlayingCommandCenter (ios/VoiLog/Playback/NowPlayingClient.swift,
 * NowPlayingCommandCenter.swift) 相当の体験をAndroidで提供する (issue #200)。
 *
 * MediaPlayer自体の管理は [PlaybackViewModel] が引き続き担う。このServiceは
 * MediaSessionCompatの保持とMediaStyle通知の表示、通知/ロック画面/Bluetooth・Android Auto
 * からの操作を [PlaybackActionListener] 経由でViewModel側に転送する役割のみを持つ。
 */
class PlaybackNotificationService : Service() {

    private lateinit var mediaSession: MediaSessionCompat

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel(this)
        mediaSession = MediaSessionCompat(this, "PlaybackNotificationService").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    actionListener?.onPlayPauseRequested()
                }

                override fun onPause() {
                    actionListener?.onPlayPauseRequested()
                }

                override fun onSeekTo(pos: Long) {
                    actionListener?.onSeekToRequested(pos)
                }

                override fun onStop() {
                    actionListener?.onStopRequested()
                }
            })
            // このServiceはPlayback画面表示中のみ起動し(=プロセスは生存中)、MediaSessionCompatが
            // isActive かつオーディオフォーカスを保持していればBluetooth/Android Autoの再生ボタンは
            // システムから直接 Callback (onPlay/onPause/onSeekTo/onStop) へルーティングされるため、
            // プロセス再起動用の setMediaButtonReceiver は不要。
            setSessionActivity(contentPendingIntent())
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == Intent.ACTION_MEDIA_BUTTON) {
            MediaButtonReceiver.handleIntent(mediaSession, intent)
        }
        when (intent?.action) {
            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
                val isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                val position = intent.getLongExtra(EXTRA_POSITION, 0L)
                val duration = intent.getLongExtra(EXTRA_DURATION, 0L)
                updateSessionAndNotification(title, isPlaying, position, duration)
            }
            ACTION_STOP_SERVICE -> {
                mediaSession.isActive = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        actionListener = null
        mediaSession.release()
        super.onDestroy()
    }

    private fun updateSessionAndNotification(title: String, isPlaying: Boolean, positionMs: Long, durationMs: Long) {
        mediaSession.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
                .build()
        )
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SEEK_TO or
                        PlaybackStateCompat.ACTION_STOP
                )
                .setState(state, positionMs, 1.0f)
                .build()
        )

        val notification = buildNotification(title, isPlaying)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun contentPendingIntent(): PendingIntent {
        return PendingIntent.getActivity(
            this,
            REQUEST_CODE_CONTENT,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun playPausePendingIntent(): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON, null, this, PlaybackNotificationService::class.java).apply {
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        }
        return PendingIntent.getService(
            this,
            REQUEST_CODE_PLAY_PAUSE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildNotification(title: String, isPlaying: Boolean): Notification {
        val playPauseAction = NotificationCompat.Action(
            R.drawable.ic_notification_mic,
            getString(if (isPlaying) R.string.pause else R.string.play),
            playPausePendingIntent()
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_mic)
            .setContentTitle(title.ifEmpty { getString(R.string.untitled_recording) })
            .setContentText(getString(if (isPlaying) R.string.play else R.string.pause))
            .setOnlyAlertOnce(true)
            .setOngoing(isPlaying)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentPendingIntent())
            .addAction(playPauseAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0)
            )
            .build()
    }

    companion object {
        const val CHANNEL_ID = "playback_status_channel"
        private const val NOTIFICATION_ID = 3001

        private const val ACTION_UPDATE = "com.entaku.simpleRecord.play.ACTION_UPDATE"
        private const val ACTION_STOP_SERVICE = "com.entaku.simpleRecord.play.ACTION_STOP_SERVICE"

        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_IS_PLAYING = "extra_is_playing"
        private const val EXTRA_POSITION = "extra_position"
        private const val EXTRA_DURATION = "extra_duration"

        private const val REQUEST_CODE_CONTENT = 3101
        private const val REQUEST_CODE_PLAY_PAUSE = 3102

        // 実際の強参照はComposable側のリスナー実装が保持する。ここではWeakReferenceのみ
        // 保持することで、companion(static)フィールドがContextを間接的に保持し続ける
        // (lint: StaticFieldLeak) ことを避ける。
        @Volatile
        private var actionListenerRef: WeakReference<PlaybackActionListener>? = null

        /**
         * 通知/ロック画面/Bluetooth・Android Autoからの操作が押された際に呼び出されるリスナー。
         * 再生画面のComposableが再生開始時に自身を登録し、画面を離れる際に null に戻す。
         */
        var actionListener: PlaybackActionListener?
            get() = actionListenerRef?.get()
            set(value) {
                actionListenerRef = value?.let { WeakReference(it) }
            }

        fun createNotificationChannel(context: Context) {
            // minSdk(29) は常に O(26) 以上のため、バージョン分岐は不要 (NotificationChannel は API 26+)。
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.playback_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.playback_notification_channel_description)
                setShowBadge(false)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        /** 再生状態(タイトル・再生中か・再生位置・長さ)を通知/ロック画面に反映する。 */
        fun updateState(context: Context, title: String, isPlaying: Boolean, positionMs: Long, durationMs: Long) {
            val intent = Intent(context, PlaybackNotificationService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
                putExtra(EXTRA_POSITION, positionMs)
                putExtra(EXTRA_DURATION, durationMs)
            }
            context.startForegroundService(intent)
        }

        /** 再生画面を離れる・再生停止した際に呼び出し、通知とMediaSessionを停止する。 */
        fun stop(context: Context) {
            actionListener = null
            val intent = Intent(context, PlaybackNotificationService::class.java).apply {
                action = ACTION_STOP_SERVICE
            }
            context.startService(intent)
        }
    }
}
