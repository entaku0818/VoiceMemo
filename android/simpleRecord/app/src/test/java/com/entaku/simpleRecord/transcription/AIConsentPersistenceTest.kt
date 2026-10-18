package com.entaku.simpleRecord.transcription

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class AIConsentPersistenceTest {
    @Test fun `legacy approval is ignored and purposes persist independently until reset`() {
        val context = ApplicationProvider.getApplicationContext<Application>()
        context.getSharedPreferences("ai_sharing", 0).edit().clear()
            .putBoolean("ai_data_sharing_consent_v1", true).commit()
        AISharingConsent.initialize(context)
        assertFalse(AISharingConsent.allowed(AIPurpose.AUDIO))
        assertFalse(AISharingConsent.allowed(AIPurpose.MINUTES))
        AISharingConsent.allow(AIPurpose.AUDIO)
        AISharingConsent.initialize(context)
        assertTrue(AISharingConsent.allowed(AIPurpose.AUDIO))
        assertFalse(AISharingConsent.allowed(AIPurpose.MINUTES))
        AISharingConsent.allow(AIPurpose.MINUTES)
        AISharingConsent.reset()
        assertFalse(AISharingConsent.allowed(AIPurpose.AUDIO))
        assertFalse(AISharingConsent.allowed(AIPurpose.MINUTES))
    }
}
