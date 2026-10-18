package com.entaku.simpleRecord.record

import android.app.Application
import android.speech.SpeechRecognizer
import androidx.test.core.app.ApplicationProvider
import io.mockk.*
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class OnDeviceSpeechTest {
    @Test fun `unsupported device never creates network recognizer`() {
        mockkStatic(SpeechRecognizer::class)
        try {
            every { SpeechRecognizer.isOnDeviceRecognitionAvailable(any()) } returns false
            val controller = AndroidSpeechTranscriptionController()
            assertFalse(controller.start(ApplicationProvider.getApplicationContext(), "") { error("No results expected") })
            verify(exactly = 0) { SpeechRecognizer.createSpeechRecognizer(any()) }
            verify(exactly = 0) { SpeechRecognizer.createOnDeviceSpeechRecognizer(any()) }
        } finally { unmockkStatic(SpeechRecognizer::class) }
    }

    @Test @Config(sdk = [30])
    fun `Android 11 records without automatic cloud speech recognition`() {
        assertFalse(AndroidSpeechTranscriptionController().start(
            ApplicationProvider.getApplicationContext(), "") { error("No results expected") })
    }
}
