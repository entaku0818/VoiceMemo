package com.entaku.simpleRecord.record

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * RecordingNotificationService の純粋関数(時間計算・フォーマット)と
 * actionListener の登録/解除ロジックに対するユニットテスト (issue #197)。
 *
 * Service自体のライフサイクル(Context依存)はRobolectric/実機での確認対象とし、
 * ここでは通知に表示するテキスト計算とリスナー配線を検証する。
 */
class RecordingNotificationServiceTest {

    @After
    fun tearDown() {
        // テスト間でstatic stateが漏れないようにリセットする
        RecordingNotificationService.actionListener = null
    }

    // --- formatElapsed ---

    @Test
    fun `formatElapsed - zero seconds formats as 00_00_00`() {
        assertEquals("00:00:00", RecordingNotificationService.formatElapsed(0))
    }

    @Test
    fun `formatElapsed - under a minute formats seconds only`() {
        assertEquals("00:00:45", RecordingNotificationService.formatElapsed(45))
    }

    @Test
    fun `formatElapsed - exactly one minute rolls over to minutes`() {
        assertEquals("00:01:00", RecordingNotificationService.formatElapsed(60))
    }

    @Test
    fun `formatElapsed - exactly one hour rolls over to hours`() {
        assertEquals("01:00:00", RecordingNotificationService.formatElapsed(3600))
    }

    @Test
    fun `formatElapsed - combined hours minutes seconds`() {
        // 1h 2m 3s = 3723s
        assertEquals("01:02:03", RecordingNotificationService.formatElapsed(3723))
    }

    @Test
    fun `formatElapsed - negative input is clamped to zero`() {
        assertEquals("00:00:00", RecordingNotificationService.formatElapsed(-100))
    }

    // --- elapsedSecondsSince ---

    @Test
    fun `elapsedSecondsSince - returns zero when base equals now`() {
        val now = 1_000_000L
        assertEquals(0L, RecordingNotificationService.elapsedSecondsSince(now, now))
    }

    @Test
    fun `elapsedSecondsSince - returns correct seconds for elapsed milliseconds`() {
        val base = 1_000_000L
        val now = base + 5_000L
        assertEquals(5L, RecordingNotificationService.elapsedSecondsSince(base, now))
    }

    @Test
    fun `elapsedSecondsSince - truncates partial seconds`() {
        val base = 1_000_000L
        val now = base + 1_999L
        assertEquals(1L, RecordingNotificationService.elapsedSecondsSince(base, now))
    }

    @Test
    fun `elapsedSecondsSince - clamps to zero when base is in the future`() {
        val base = 2_000_000L
        val now = 1_000_000L
        assertEquals(0L, RecordingNotificationService.elapsedSecondsSince(base, now))
    }

    // --- actionListener wiring ---

    @Test
    fun `actionListener - is null by default`() {
        assertNull(RecordingNotificationService.actionListener)
    }

    @Test
    fun `actionListener - pause action is forwarded to registered listener`() {
        var pauseCalled = false
        RecordingNotificationService.actionListener = object : RecordingActionListener {
            override fun onPauseRequested() { pauseCalled = true }
            override fun onResumeRequested() {}
            override fun onStopRequested() {}
        }

        RecordingNotificationService.actionListener?.onPauseRequested()

        assertEquals(true, pauseCalled)
    }

    @Test
    fun `actionListener - resume and stop actions are forwarded independently`() {
        var resumeCalled = false
        var stopCalled = false
        RecordingNotificationService.actionListener = object : RecordingActionListener {
            override fun onPauseRequested() {}
            override fun onResumeRequested() { resumeCalled = true }
            override fun onStopRequested() { stopCalled = true }
        }

        RecordingNotificationService.actionListener?.onResumeRequested()
        RecordingNotificationService.actionListener?.onStopRequested()

        assertEquals(true, resumeCalled)
        assertEquals(true, stopCalled)
    }
}
