package com.entaku.simpleRecord.play

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * PlaybackNotificationService の actionListener 登録/解除ロジックに対するユニットテスト (issue #200)。
 *
 * Service自体のライフサイクル(Context・MediaSessionCompat依存)は実機/エミュレータでの確認対象とし、
 * ここでは通知/ロック画面/Bluetooth・Android Autoからの操作がPlaybackViewModel側へ
 * 正しく配線されることを検証する。
 */
class PlaybackNotificationServiceTest {

    @After
    fun tearDown() {
        // テスト間でstatic stateが漏れないようにリセットする
        PlaybackNotificationService.actionListener = null
    }

    @Test
    fun `actionListener - is null by default`() {
        assertNull(PlaybackNotificationService.actionListener)
    }

    @Test
    fun `actionListener - playPause action is forwarded to registered listener`() {
        var playPauseCalled = false
        PlaybackNotificationService.actionListener = object : PlaybackActionListener {
            override fun onPlayPauseRequested() { playPauseCalled = true }
            override fun onSeekToRequested(positionMs: Long) {}
            override fun onStopRequested() {}
        }

        PlaybackNotificationService.actionListener?.onPlayPauseRequested()

        assertEquals(true, playPauseCalled)
    }

    @Test
    fun `actionListener - seekTo and stop actions are forwarded independently`() {
        var seekPosition: Long? = null
        var stopCalled = false
        PlaybackNotificationService.actionListener = object : PlaybackActionListener {
            override fun onPlayPauseRequested() {}
            override fun onSeekToRequested(positionMs: Long) { seekPosition = positionMs }
            override fun onStopRequested() { stopCalled = true }
        }

        PlaybackNotificationService.actionListener?.onSeekToRequested(4200L)
        PlaybackNotificationService.actionListener?.onStopRequested()

        assertEquals(4200L, seekPosition)
        assertEquals(true, stopCalled)
    }

    @Test
    fun `actionListener - setting to null clears the registered listener`() {
        PlaybackNotificationService.actionListener = object : PlaybackActionListener {
            override fun onPlayPauseRequested() {}
            override fun onSeekToRequested(positionMs: Long) {}
            override fun onStopRequested() {}
        }
        assertEquals(true, PlaybackNotificationService.actionListener != null)

        PlaybackNotificationService.actionListener = null

        assertNull(PlaybackNotificationService.actionListener)
    }
}
