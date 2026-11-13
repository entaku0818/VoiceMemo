package com.entaku.simpleRecord

import android.content.res.Configuration
import android.graphics.Bitmap
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.platform.app.InstrumentationRegistry
import com.entaku.simpleRecord.record.RecordScreen
import com.entaku.simpleRecord.record.RecordingState
import com.entaku.simpleRecord.record.RecordingUiState
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.time.Duration
import java.util.Locale
import kotlin.math.sin

/** Renders production recording UI with sample levels, without microphone access. */
class PlayRecordingScreenshotTest {
    @get:Rule val compose = createComposeRule()
    private fun render(language: String) {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        val config = Configuration(target.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(language))
            fontScale = 1f
        }
        val context = target.createConfigurationContext(config)
        val state = MutableStateFlow(RecordingUiState(
            recordingState = RecordingState.RECORDING,
            currentVolume = 48,
            elapsedTime = Duration.ofSeconds(24),
            amplitudeHistory = List(100) { index -> (0.18 + 0.5 * kotlin.math.abs(sin(index * 0.71))).toFloat() }
        ))
        compose.setContent {
            val registryOwner = checkNotNull(LocalActivityResultRegistryOwner.current)
            CompositionLocalProvider(LocalContext provides context, LocalConfiguration provides config,
                LocalResources provides context.resources, LocalActivityResultRegistryOwner provides registryOwner) {
                AudioRecorderTheme(darkTheme = false) { RecordScreen(state, {}, {}, {}, {}, {}) }
            }
        }
        compose.waitForIdle()
        File(target.getExternalFilesDir(null), "play-${language}-recording.png").outputStream().use {
            compose.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }
    @Test fun japaneseRecording() = render("ja")
    @Test fun englishRecording() = render("en")
}
