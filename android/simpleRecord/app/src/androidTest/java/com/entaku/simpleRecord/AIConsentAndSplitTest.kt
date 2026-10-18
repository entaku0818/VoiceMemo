package com.entaku.simpleRecord

import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import android.content.res.Configuration
import android.media.MediaExtractor
import android.media.MediaFormat
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import com.entaku.simpleRecord.edit.AudioTrimmerImpl
import com.entaku.simpleRecord.transcription.AIConsentDialog
import com.entaku.simpleRecord.transcription.AIPurpose
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.rules.RuleChain
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import android.provider.Settings
import android.os.ParcelFileDescriptor
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.util.Locale

class AIConsentAndSplitTest {
    private val compose = createComposeRule()
    private val systemFont = object : TestWatcher() {
        private var previous = 1f
        private fun setScale(scale: Float) {
            val instrumentation = InstrumentationRegistry.getInstrumentation()
            val fd = instrumentation.uiAutomation.executeShellCommand("settings put system font_scale $scale")
            ParcelFileDescriptor.AutoCloseInputStream(fd).use { it.readBytes() }
            instrumentation.waitForIdleSync()
        }
        override fun starting(description: Description) {
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            previous = Settings.System.getFloat(context.contentResolver, Settings.System.FONT_SCALE, 1f)
            setScale(if (description.methodName == "japaneseLargeTextConsent") 1.5f else 1f)
        }
        override fun finished(description: Description) { setScale(previous) }
    }
    @get:Rule val rules: RuleChain = RuleChain.outerRule(systemFont).around(compose)

    private fun consent(language: String, purpose: AIPurpose, fontSize: Float = 1f) {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        val config = Configuration(target.resources.configuration).apply { setLocale(Locale.forLanguageTag(language)); fontScale = fontSize }
        val context = target.createConfigurationContext(config)
        var allowed = 0
        var declined = 0
        compose.setContent {
            CompositionLocalProvider(LocalContext provides context, LocalConfiguration provides config, LocalResources provides context.resources,
                LocalDensity provides Density(context.resources.displayMetrics.density, fontSize)) {
                MaterialTheme { AIConsentDialog(purpose, { allowed++ }, { declined++ }) }
            }
        }
        compose.onNodeWithText("Gemini", substring = true).assertExists()
        compose.onNode(isDialog()).captureToImage().asAndroidBitmap().let { bitmap ->
            File(target.getExternalFilesDir(null), "consent-${language}-${purpose}-${fontSize}.png").outputStream().use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
        }
        compose.onNodeWithText(context.getString(R.string.ai_consent_decline)).assertIsDisplayed().performClick()
        compose.runOnIdle { assertEquals(0, allowed); assertEquals(1, declined) }
        compose.onNodeWithText(context.getString(R.string.ai_consent_allow)).assertIsDisplayed().performClick()
        compose.runOnIdle { assertEquals(1, allowed) }
    }

    @Test fun japaneseAudioConsent() = consent("ja", AIPurpose.AUDIO)
    @Test fun japaneseMinutesConsent() = consent("ja", AIPurpose.MINUTES)
    @Test fun englishAudioConsent() = consent("en", AIPurpose.AUDIO)
    @Test fun japaneseLargeTextConsent() = consent("ja", AIPurpose.AUDIO, 1.5f)
    @Test fun englishMinutesConsent() = consent("en", AIPurpose.MINUTES)

    @Test fun splitRealAacPreservesSourceAndProducesTwoPlayableTracks() = runBlocking {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val dir = File(instrumentation.targetContext.cacheDir, "split-test").apply { mkdirs() }
        val source = File(dir, "source.m4a")
        instrumentation.context.assets.open("split-tone.m4a").use { input -> source.outputStream().use { input.copyTo(it) } }
        val original = source.readBytes()
        val first = File(dir, "first.m4a")
        val second = File(dir, "second.m4a")
        try {
            val trimmer = AudioTrimmerImpl()
            trimmer.trim(source.path, 0, 1500, first.path)
            trimmer.trim(source.path, 1500, 3000, second.path)
            assertArrayEquals(original, source.readBytes())
            listOf(first, second).forEach { output ->
                val extractor = MediaExtractor()
                try {
                    extractor.setDataSource(output.path)
                    assertEquals(1, extractor.trackCount)
                    val format = extractor.getTrackFormat(0)
                    assertEquals("audio/mp4a-latm", format.getString(MediaFormat.KEY_MIME))
                    assertTrue(format.getLong(MediaFormat.KEY_DURATION) in 1_400_000L..1_600_000L)
                    extractor.selectTrack(0)
                    assertTrue(extractor.sampleTime >= 0)
                } finally { extractor.release() }
            }
        } finally { listOf(source, first, second).forEach { it.delete() }; dir.delete() }
    }
}
