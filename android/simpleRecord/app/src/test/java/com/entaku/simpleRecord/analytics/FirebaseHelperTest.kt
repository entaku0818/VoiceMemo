package com.entaku.simpleRecord.analytics

import org.junit.Test
import org.junit.Assert.*

class FirebaseHelperTest {

    @Test
    fun `initialize does not throw when Firebase is not configured`() {
        // FirebaseHelper.initialize() catches exceptions internally;
        // calling it in a unit-test environment (no google-services.json) must not crash.
        FirebaseHelper.initialize()
        // Reaches here without exception — pass
    }

    @Test
    fun `logEvent does not throw when analytics is disabled`() {
        FirebaseHelper.logEvent("test_event", mapOf("key" to "value"))
    }

    @Test
    fun `logEvent with empty params does not throw`() {
        FirebaseHelper.logEvent("test_event")
    }

    @Test
    fun `recordException does not throw when crashlytics is disabled`() {
        FirebaseHelper.recordException(RuntimeException("test"))
    }

    @Test
    fun `setUserId does not throw when analytics is disabled`() {
        FirebaseHelper.setUserId("user_123")
    }

    @Test
    fun `logRecordingStarted does not throw`() {
        FirebaseHelper.logRecordingStarted()
    }

    @Test
    fun `logRecordingSaved does not throw`() {
        FirebaseHelper.logRecordingSaved(120)
    }

    @Test
    fun `logPlaybackStarted does not throw`() {
        FirebaseHelper.logPlaybackStarted()
    }

    @Test
    fun `logSettingsChanged does not throw`() {
        FirebaseHelper.logSettingsChanged("file_format", "mp4")
    }

    @Test
    fun `logScreenView does not throw`() {
        FirebaseHelper.logScreenView("RecordingSettings")
    }
}
