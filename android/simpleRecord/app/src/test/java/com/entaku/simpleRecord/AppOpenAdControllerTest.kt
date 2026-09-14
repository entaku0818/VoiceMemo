package com.entaku.simpleRecord

import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Issue #218: AppOpenAdController のゲート判定・ロード待ち・起動回数保存を
 * Android フレームワークから切り離してユニットテストする。
 */
class AppOpenAdControllerTest {

    // ---- 1. 表示可否の純粋関数 shouldAttemptShow ----

    @Test
    fun `shouldAttemptShow - 初回起動(0)では出さない`() {
        assertFalse(AppOpenAdController.shouldAttemptShow(launchCount = 0, isPremium = false))
    }

    @Test
    fun `shouldAttemptShow - 5の倍数では出す`() {
        assertTrue(AppOpenAdController.shouldAttemptShow(launchCount = 5, isPremium = false))
        assertTrue(AppOpenAdController.shouldAttemptShow(launchCount = 10, isPremium = false))
    }

    @Test
    fun `shouldAttemptShow - 5の倍数以外では出さない`() {
        assertFalse(AppOpenAdController.shouldAttemptShow(launchCount = 1, isPremium = false))
        assertFalse(AppOpenAdController.shouldAttemptShow(launchCount = 4, isPremium = false))
        assertFalse(AppOpenAdController.shouldAttemptShow(launchCount = 6, isPremium = false))
    }

    @Test
    fun `shouldAttemptShow - プレミアムなら起動回数に関わらず常に出さない`() {
        for (count in listOf(0, 1, 4, 5, 6, 10)) {
            assertFalse(
                "launchCount=$count premium should never show",
                AppOpenAdController.shouldAttemptShow(launchCount = count, isPremium = true)
            )
        }
    }

    @Test
    fun `shouldAttemptShow - displayInterval を差し替えられる`() {
        assertTrue(AppOpenAdController.shouldAttemptShow(launchCount = 3, isPremium = false, displayInterval = 3))
        assertFalse(AppOpenAdController.shouldAttemptShow(launchCount = 5, isPremium = false, displayInterval = 3))
    }

    // ---- 2. ロード待ち awaitAdThenSettle ----

    private class FakeScheduler : DelayedScheduler {
        var scheduled: Runnable? = null
        var scheduledDelay: Long = -1
        var removedCalls = 0

        override fun postDelayed(runnable: Runnable, delayMillis: Long) {
            scheduled = runnable
            scheduledDelay = delayMillis
        }

        override fun removeCallbacks(runnable: Runnable) {
            if (runnable === scheduled) removedCalls++
        }

        fun fireTimeout() {
            scheduled?.run()
        }
    }

    @Test
    fun `awaitAdThenSettle - ロード成功かつ広告ありなら present を1回だけ`() {
        val scheduler = FakeScheduler()
        var present = 0
        var dismiss = 0

        AppOpenAdController.awaitAdThenSettle(
            scheduler = scheduler,
            timeoutMs = 3000L,
            startLoad = { onLoaded -> onLoaded(true) },
            isAdReady = { true },
            onPresent = { present++ },
            onDismiss = { dismiss++ }
        )

        assertEquals(1, present)
        assertEquals(0, dismiss)
        assertEquals(1, scheduler.removedCalls) // タイムアウトは解除される
    }

    @Test
    fun `awaitAdThenSettle - ロード失敗なら dismiss で本編へ進む`() {
        val scheduler = FakeScheduler()
        var present = 0
        var dismiss = 0

        AppOpenAdController.awaitAdThenSettle(
            scheduler = scheduler,
            timeoutMs = 3000L,
            startLoad = { onLoaded -> onLoaded(false) },
            isAdReady = { false },
            onPresent = { present++ },
            onDismiss = { dismiss++ }
        )

        assertEquals(0, present)
        assertEquals(1, dismiss)
    }

    @Test
    fun `awaitAdThenSettle - ロード成功でも広告未準備なら dismiss`() {
        val scheduler = FakeScheduler()
        var present = 0
        var dismiss = 0

        AppOpenAdController.awaitAdThenSettle(
            scheduler = scheduler,
            timeoutMs = 3000L,
            startLoad = { onLoaded -> onLoaded(true) },
            isAdReady = { false },
            onPresent = { present++ },
            onDismiss = { dismiss++ }
        )

        assertEquals(0, present)
        assertEquals(1, dismiss)
    }

    @Test
    fun `awaitAdThenSettle - タイムアウト超過なら dismiss で本編へ進む`() {
        val scheduler = FakeScheduler()
        var present = 0
        var dismiss = 0

        // ロードは決着しない（コールバックを呼ばない）
        AppOpenAdController.awaitAdThenSettle(
            scheduler = scheduler,
            timeoutMs = 3000L,
            startLoad = { /* pending forever */ },
            isAdReady = { true },
            onPresent = { present++ },
            onDismiss = { dismiss++ }
        )

        assertEquals(3000L, scheduler.scheduledDelay)
        scheduler.fireTimeout()

        assertEquals(0, present)
        assertEquals(1, dismiss)
    }

    @Test
    fun `awaitAdThenSettle - タイムアウト後に遅れてロード成功しても dismiss は1回だけ`() {
        val scheduler = FakeScheduler()
        var present = 0
        var dismiss = 0
        var lateCallback: ((Boolean) -> Unit)? = null

        AppOpenAdController.awaitAdThenSettle(
            scheduler = scheduler,
            timeoutMs = 3000L,
            startLoad = { onLoaded -> lateCallback = onLoaded },
            isAdReady = { true },
            onPresent = { present++ },
            onDismiss = { dismiss++ }
        )

        scheduler.fireTimeout()      // タイムアウトで決着
        lateCallback?.invoke(true)   // その後ロードが完了しても無視される

        assertEquals(0, present)
        assertEquals(1, dismiss)
    }

    @Test
    fun `awaitAdThenSettle - ロード成功後に giveUp が実行されても present は1回 dismiss は0`() {
        val scheduler = FakeScheduler()
        var present = 0
        var dismiss = 0

        AppOpenAdController.awaitAdThenSettle(
            scheduler = scheduler,
            timeoutMs = 3000L,
            startLoad = { onLoaded -> onLoaded(true) },
            isAdReady = { true },
            onPresent = { present++ },
            onDismiss = { dismiss++ }
        )

        // 解除漏れで giveUp が後から走っても isSettled で無効化される
        scheduler.fireTimeout()

        assertEquals(1, present)
        assertEquals(0, dismiss)
    }

    // ---- 3. 起動回数ストアの注入 ----

    private class InMemoryLaunchCountStore(initial: Int = 0) : LaunchCountStore {
        private var count = initial
        override fun getLaunchCount(): Int = count
        override fun incrementLaunchCount() {
            count++
        }
    }

    @Test
    fun `getLaunchCount と incrementLaunchCount は注入したストアに委譲される`() {
        val store = InMemoryLaunchCountStore(initial = 4)
        val controller = AppOpenAdController(mockk(relaxed = true), store)

        assertEquals(4, controller.getLaunchCount())

        controller.incrementLaunchCount()
        assertEquals(5, controller.getLaunchCount())
    }

    @Test
    fun `インメモリストアは初期値0から始まる`() {
        val store = InMemoryLaunchCountStore()
        assertEquals(0, store.getLaunchCount())
        store.incrementLaunchCount()
        assertEquals(1, store.getLaunchCount())
    }

    @Test
    fun `注入したストアは共有される（同一インスタンスを参照）`() {
        val store = InMemoryLaunchCountStore()
        val controller = AppOpenAdController(mockk(relaxed = true), store)

        controller.incrementLaunchCount()
        controller.incrementLaunchCount()

        assertEquals(2, store.getLaunchCount())
    }
}
