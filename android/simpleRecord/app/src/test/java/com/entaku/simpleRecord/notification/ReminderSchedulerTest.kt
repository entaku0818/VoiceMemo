package com.entaku.simpleRecord.notification

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.TimeUnit

/**
 * Unit tests for ReminderScheduler (Issue #129)
 *
 * Context依存の AlarmManager / SharedPreferences は統合テストで検証。
 * ここでは純粋な計算ロジックをテスト。
 * Tests cover:
 * - D1/D3 トリガー時刻の計算
 * - インストール後の経過時間によるスケジュール可否判定
 */
class ReminderSchedulerTest {

    // --- D1 trigger time ---

    @Test
    fun `calculateD1TriggerTime - returns installDate plus 1 day`() {
        val installDate = 1_000_000_000L

        val result = ReminderScheduler.calculateD1TriggerTime(installDate)

        assertEquals(installDate + TimeUnit.DAYS.toMillis(1), result)
    }

    @Test
    fun `calculateD1TriggerTime - 1 day is exactly 86400000 ms`() {
        val installDate = 0L

        val result = ReminderScheduler.calculateD1TriggerTime(installDate)

        assertEquals(86_400_000L, result)
    }

    // --- D3 trigger time ---

    @Test
    fun `calculateD3TriggerTime - returns installDate plus 3 days`() {
        val installDate = 1_000_000_000L

        val result = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertEquals(installDate + TimeUnit.DAYS.toMillis(3), result)
    }

    @Test
    fun `calculateD3TriggerTime - 3 days is exactly 259200000 ms`() {
        val installDate = 0L

        val result = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertEquals(259_200_000L, result)
    }

    // --- D1 vs D3 の順序 ---

    @Test
    fun `D1 trigger is always before D3 trigger`() {
        val installDate = System.currentTimeMillis()

        val d1 = ReminderScheduler.calculateD1TriggerTime(installDate)
        val d3 = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertTrue(d1 < d3)
    }

    @Test
    fun `D3 trigger is exactly 2 days after D1 trigger`() {
        val installDate = 0L

        val d1 = ReminderScheduler.calculateD1TriggerTime(installDate)
        val d3 = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertEquals(TimeUnit.DAYS.toMillis(2), d3 - d1)
    }

    // --- トリガー時刻が未来かどうか ---

    @Test
    fun `D1 trigger is in future when called immediately after install`() {
        val installDate = System.currentTimeMillis()
        val now = installDate

        val d1 = ReminderScheduler.calculateD1TriggerTime(installDate)

        assertTrue("D1 should be in the future", d1 > now)
    }

    @Test
    fun `D1 trigger is in past when called 2 days after install`() {
        val installDate = System.currentTimeMillis() - TimeUnit.DAYS.toMillis(2)
        val now = System.currentTimeMillis()

        val d1 = ReminderScheduler.calculateD1TriggerTime(installDate)

        assertTrue("D1 should be in the past after 2 days", d1 < now)
    }

    @Test
    fun `D3 trigger is in past when called 4 days after install`() {
        val installDate = System.currentTimeMillis() - TimeUnit.DAYS.toMillis(4)
        val now = System.currentTimeMillis()

        val d3 = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertTrue("D3 should be in the past after 4 days", d3 < now)
    }

    @Test
    fun `D3 trigger is in future when called 1 day after install`() {
        val installDate = System.currentTimeMillis() - TimeUnit.DAYS.toMillis(1)
        val now = System.currentTimeMillis()

        val d3 = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertTrue("D3 should be in the future after 1 day", d3 > now)
    }

    // --- ミリ秒精度 ---

    @Test
    fun `trigger times preserve millisecond precision of install date`() {
        val installDate = 1_234_567_890_123L

        val d1 = ReminderScheduler.calculateD1TriggerTime(installDate)
        val d3 = ReminderScheduler.calculateD3TriggerTime(installDate)

        assertEquals(123L, d1 % 1000)
        assertEquals(123L, d3 % 1000)
    }
}
