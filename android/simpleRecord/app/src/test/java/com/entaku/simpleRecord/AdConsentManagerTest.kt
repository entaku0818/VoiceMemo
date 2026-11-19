package com.entaku.simpleRecord

import android.app.Activity
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdConsentManagerTest {
    private fun consentManager(
        consent: AdsConsentClient,
        initializeAds: (() -> Unit) -> Unit,
        clearCachedAds: () -> Unit = {}
    ) = AdConsentManager(consent, initializeAds, clearCachedAds, scheduleTimeout = { _, _ -> {} })

    private class FakeConsentClient : AdsConsentClient {
        override var canRequestAds = false
        override var isPrivacyOptionsRequired = false
        lateinit var updateCompletion: (String?) -> Unit
        lateinit var formCompletion: (String?) -> Unit
        lateinit var formLoadCompletion: (AdsConsentForm?, String?) -> Unit
        lateinit var privacyCompletion: (String?) -> Unit
        var gatheredForms = 0
        var deferFormLoad = false
        override fun update(activity: Activity, completion: (String?) -> Unit) {
            updateCompletion = completion
        }
        override fun loadForm(completion: (AdsConsentForm?, String?) -> Unit) {
            gatheredForms++
            formLoadCompletion = completion
            if (!deferFormLoad) completion(AdsConsentForm { _, dismissed -> formCompletion = dismissed }, null)
        }
        override fun showPrivacyOptions(activity: Activity, completion: (String?) -> Unit) {
            privacyCompletion = completion
        }
    }

    private class FakeDeadline {
        private data class Task(val block: () -> Unit, var cancelled: Boolean = false)
        private val tasks = mutableListOf<Task>()
        fun schedule(delay: Long, block: () -> Unit): () -> Unit {
            assertEquals(3000L, delay)
            val task = Task(block)
            tasks.add(task)
            return { task.cancelled = true }
        }
        fun fire() {
            tasks.toList().filterNot { it.cancelled }.forEach { it.block() }
        }
    }

    @Test
    fun `consent update timeout releases startup and never presents a late form`() {
        val consent = FakeConsentClient()
        val timer = FakeDeadline()
        var completed = 0
        val manager = AdConsentManager(consent, { it() }, scheduleTimeout = timer::schedule)
        manager.gatherConsent(mockk(relaxed = true)) { completed++ }
        timer.fire()
        consent.updateCompletion(null)
        assertEquals(1, completed)
        assertEquals(0, consent.gatheredForms)
        assertFalse(manager.areAdsAllowed)
    }

    @Test
    fun `form load timeout never presents the late loaded form`() {
        val consent = FakeConsentClient().apply { deferFormLoad = true }
        val timer = FakeDeadline()
        var completed = 0
        var shown = false
        val manager = AdConsentManager(consent, { it() }, scheduleTimeout = timer::schedule)
        manager.gatherConsent(mockk(relaxed = true)) { completed++ }
        consent.updateCompletion(null)
        timer.fire()
        consent.formLoadCompletion(AdsConsentForm { _, _ -> shown = true }, null)
        assertEquals(1, completed)
        assertFalse(shown)
        assertFalse(manager.areAdsAllowed)
    }

    @Test
    fun `presented consent form waits for the user's answer instead of timing out`() {
        val consent = FakeConsentClient()
        val timer = FakeDeadline()
        var completed = 0
        val manager = AdConsentManager(consent, { it() }, scheduleTimeout = timer::schedule)
        manager.gatherConsent(mockk(relaxed = true)) { completed++ }
        consent.updateCompletion(null)
        timer.fire()
        assertEquals(0, completed)
        consent.canRequestAds = true
        consent.formCompletion(null)
        assertEquals(1, completed)
        assertTrue(manager.areAdsAllowed)
    }

    @Test
    fun `SDK initialization timeout releases startup and does not enable late ad requests`() {
        val consent = FakeConsentClient().apply { canRequestAds = true }
        val timer = FakeDeadline()
        var sdkCompletion: (() -> Unit)? = null
        var completed = 0
        val manager = AdConsentManager(consent, { sdkCompletion = it }, scheduleTimeout = timer::schedule)
        manager.gatherConsent(mockk(relaxed = true), showFormIfRequired = false) { completed++ }
        consent.updateCompletion(null)
        timer.fire()
        sdkCompletion?.invoke()
        assertEquals(1, completed)
        assertFalse(manager.areAdsAllowed)
    }

    @Test
    fun `an obsolete launch timeout and callback cannot revoke the new launch permission`() {
        val consent = FakeConsentClient()
        val timer = FakeDeadline()
        val manager = AdConsentManager(consent, { it() }, scheduleTimeout = timer::schedule)
        manager.gatherConsent(mockk(relaxed = true), showFormIfRequired = false)
        val obsoleteUpdate = consent.updateCompletion
        manager.gatherConsent(mockk(relaxed = true), showFormIfRequired = false)
        consent.canRequestAds = true
        consent.updateCompletion(null)
        assertTrue(manager.areAdsAllowed)
        timer.fire()
        obsoleteUpdate(null)
        assertTrue(manager.areAdsAllowed)
    }

    @Test
    fun `a recording request or background transition during load prevents form presentation`() {
        val consent = FakeConsentClient().apply { deferFormLoad = true }
        var mayPresent = true
        var shown = false
        var completed = false
        val manager = consentManager(consent, { it() })
        manager.gatherConsent(mockk(relaxed = true), canPresentForm = { mayPresent }) { completed = true }
        consent.updateCompletion(null)
        mayPresent = false
        consent.formLoadCompletion(AdsConsentForm { _, _ -> shown = true }, null)
        assertFalse(shown)
        assertTrue(completed)
    }

    @Test
    fun `ads wait for current consent and SDK initialization`() {
        val consent = FakeConsentClient()
        var initializationCalls = 0
        var initializeCompletion: (() -> Unit)? = null
        var completed = false
        val manager = consentManager(consent, { initializationCalls++; initializeCompletion = it })

        manager.gatherConsent(mockk(relaxed = true)) { completed = true }
        assertEquals(0, initializationCalls)
        consent.updateCompletion(null)
        assertFalse(manager.areAdsAllowed)
        consent.canRequestAds = true
        consent.formCompletion(null)
        assertEquals(1, initializationCalls)
        assertFalse(manager.areAdsAllowed)
        assertFalse(completed)
        initializeCompletion?.invoke()
        assertTrue(manager.areAdsAllowed)
        assertTrue(completed)
    }

    @Test
    fun `no consent does not initialize ads even after a failed form`() {
        val consent = FakeConsentClient()
        var initializationCalls = 0
        val manager = consentManager(consent, { initializationCalls++ })
        manager.gatherConsent(mockk(relaxed = true))
        consent.updateCompletion(null)
        consent.formCompletion("offline")
        assertFalse(manager.areAdsAllowed)
        assertEquals(0, initializationCalls)
    }

    @Test
    fun `consent update error uses SDK previous session permission and initializes once`() {
        val consent = FakeConsentClient().apply { canRequestAds = true }
        var initializationCalls = 0
        val manager = consentManager(consent, { initializationCalls++; it() })
        repeat(2) {
            manager.gatherConsent(mockk(relaxed = true))
            consent.updateCompletion("offline")
        }
        assertTrue(manager.areAdsAllowed)
        assertEquals(1, initializationCalls)
    }

    @Test
    fun `recording launch updates consent without presenting an automatic form`() {
        val consent = FakeConsentClient()
        val manager = consentManager(consent, { it() })
        var completed = false
        manager.gatherConsent(mockk(relaxed = true), showFormIfRequired = false) { completed = true }
        consent.updateCompletion(null)
        assertEquals(0, consent.gatheredForms)
        assertFalse(manager.areAdsAllowed)
        assertTrue(completed)
    }

    @Test
    fun `privacy options clear loaded ads immediately and apply withdrawn permission`() {
        val consent = FakeConsentClient().apply {
            canRequestAds = true
            isPrivacyOptionsRequired = true
        }
        var clearedAds = 0
        val manager = consentManager(consent, { it() }, { clearedAds++ })
        manager.gatherConsent(mockk(relaxed = true), showFormIfRequired = false)
        consent.updateCompletion(null)
        assertTrue(manager.areAdsAllowed)
        assertTrue(manager.privacyOptionsRequired.value)

        val revision = manager.adRevision.value
        manager.showPrivacyOptions(mockk(relaxed = true))
        assertFalse(manager.areAdsAllowed)
        assertEquals(revision + 1, manager.adRevision.value)
        assertEquals(1, clearedAds)
        consent.canRequestAds = false
        consent.privacyCompletion(null)
        assertFalse(manager.canRequestAds.value)
    }

    @Test
    fun `SDK initialization cannot re-enable requests while privacy options are open`() {
        val consent = FakeConsentClient().apply { canRequestAds = true }
        var initializeCompletion: (() -> Unit)? = null
        val manager = consentManager(consent, { initializeCompletion = it })
        manager.gatherConsent(mockk(relaxed = true), showFormIfRequired = false)
        consent.updateCompletion(null)
        manager.showPrivacyOptions(mockk(relaxed = true))
        initializeCompletion?.invoke()
        assertFalse(manager.areAdsAllowed)
        consent.privacyCompletion(null)
        assertTrue(manager.areAdsAllowed)
    }
}
