package com.entaku.simpleRecord

import android.content.res.Configuration
import android.graphics.Bitmap
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.test.platform.app.InstrumentationRegistry
import com.entaku.simpleRecord.transcription.*
import com.entaku.simpleRecord.cloudsync.*
import com.entaku.simpleRecord.play.*
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.time.LocalDateTime
import java.util.Locale
import java.util.UUID
import kotlin.math.sin

/** Production UI with local sample data; no AI calls, sign-in or uploads. */
@org.junit.runner.RunWith(org.junit.runners.Parameterized::class)
class PlayLocalizedScreenshotTest(private val locale: String, private val screen: String) {
    @get:Rule val compose = createComposeRule()
    @Suppress("UNCHECKED_CAST")
    private fun setState(model: Any, value: Any) {
        val field = model.javaClass.getDeclaredField("_uiState").apply { isAccessible = true }
        (field.get(model) as MutableStateFlow<Any>).value = value
    }
    private fun render(language: String, screen: String) {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        val config = Configuration(target.resources.configuration).apply {
            val fixture = org.json.JSONObject(InstrumentationRegistry.getInstrumentation().context.assets.open("play-locales.json").bufferedReader().readText()).getJSONObject(language)
            setLocale(Locale.forLanguageTag(fixture.getString("ui_language"))); fontScale = 1f
        }
        val context = target.createConfigurationContext(config)
        val fixture = org.json.JSONObject(InstrumentationRegistry.getInstrumentation().context.assets.open("play-locales.json").bufferedReader().readText()).getJSONObject(language)
        fun strings(key: String): List<String> = fixture.getJSONArray(key).let { a -> List(a.length()) { a.getString(it) } }
        val title = fixture.getString("title")
        val summary = fixture.getString("summary")
        val texts = strings("segments")
        val todos = strings("todos")
        val titles = strings("titles")
        val premium = com.entaku.simpleRecord.store.PremiumRepository.getInstance(context)
        val previousPremium = premium.isPremium.value
        premium.setPremium(true)
        val owner = object : ViewModelStoreOwner { override val viewModelStore = ViewModelStore() }
        val transcript = TranscriptionViewModel("/sample.m4a")
        setState(transcript, TranscriptionUiState.Done(TranscriptionResult(texts.joinToString("\n"), texts.mapIndexed { i, text -> TranscriptionSegment(listOf("0:00", "0:18", "0:36")[i], null, text) }, summary)))
        owner.viewModelStore.put("androidx.lifecycle.ViewModelProvider.DefaultKey:${TranscriptionViewModel::class.java.canonicalName}", transcript)
        val cloud = CloudSyncViewModel(context)
        setState(cloud, CloudSyncState(isSignedIn = true, userEmail = "alex@example.com", backupInfo = BackupInfo(24, LocalDateTime.of(2026, 10, 23, 9, 41))))
        compose.setContent {
            val registry = checkNotNull(LocalActivityResultRegistryOwner.current)
            CompositionLocalProvider(LocalContext provides context, LocalConfiguration provides config,
                LocalResources provides context.resources, LocalActivityResultRegistryOwner provides registry,
                LocalViewModelStoreOwner provides owner) {
                AudioRecorderTheme(darkTheme = false) {
                    Box(Modifier.fillMaxSize().background(Color.White)) {
                        when (screen) {
                            "00_recording" -> com.entaku.simpleRecord.record.RecordScreen(MutableStateFlow(com.entaku.simpleRecord.record.RecordingUiState(recordingState = com.entaku.simpleRecord.record.RecordingState.RECORDING, currentVolume = 48, elapsedTime = java.time.Duration.ofSeconds(24), amplitudeHistory = List(100) { (0.18 + 0.5 * kotlin.math.abs(sin(it * 0.71))).toFloat() })), {}, {}, {}, {}, {})
                            "03_list" -> RecordingsScreen(RecordingsUiState(recordings = titles.mapIndexed { i, t -> RecordingData(uuid = UUID.nameUUIDFromBytes(t.toByteArray()), title = t, creationDate = LocalDateTime.of(2026, 10, 23, 9, 41).minusHours(i.toLong()), fileExtension = "m4a", khz = "48", bitRate = 192000, channels = 1, duration = listOf(186L, 2702L, 48L, 5320L, 1935L)[i], filePath = "/sample-$i.m4a") }, isLoading = false), onRefresh = {}, onNavigateToPlaybackScreen = {}, onDeleteClick = {}, onEditRecordingName = { _, _ -> }, colorScheme = androidx.compose.material3.MaterialTheme.colorScheme)
                            "01_transcript" -> TranscriptionScreen("/sample.m4a", UUID.randomUUID(), onNavigateBack = {}, onNavigateToMeetingMinutes = { _, _ -> })
                            "02_minutes" -> MeetingMinutesContent(MeetingMinutesUiState.Done(MinutesResult(summary, todos)), true, {}, {}, {}, {})
                            "04_playback" -> PlaybackScreen(RecordingData(title = title, creationDate = LocalDateTime.of(2026, 10, 23, 9, 41), fileExtension = "m4a", khz = "48", bitRate = 192000, channels = 1, duration = 186, filePath = "/sample.m4a"), PlaybackState(currentPosition = 64000, duration = 186000, playbackSpeed = 1.5f, abLoopStart = 42000, abLoopEnd = 96000, waveformData = List(100) { (0.15 + 0.65 * kotlin.math.abs(sin(it * 0.71))).toFloat() }), {}, {}, {}, {})
                            "05_cloud" -> CloudSyncScreen(cloud, {})
                        }
                    }
                }
            }
        }
        compose.waitForIdle()
        File(target.getExternalFilesDir(null), "play-$language-$screen.png").outputStream().use {
            compose.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        owner.viewModelStore.clear()
        premium.setPremium(previousPremium)
    }
    @Test fun capture() = render(locale, screen)
    companion object {
        @JvmStatic @org.junit.runners.Parameterized.Parameters(name = "{0}-{1}")
        fun cases(): List<Array<String>> {
            val data = org.json.JSONObject(InstrumentationRegistry.getInstrumentation().context.assets.open("play-locales.json").bufferedReader().readText())
            return data.keys().asSequence().sorted().flatMap { locale ->
                (InstrumentationRegistry.getArguments().getString("screens")?.split(",") ?: listOf("00_recording", "01_transcript", "02_minutes", "03_list", "04_playback", "05_cloud")).map { arrayOf(locale, it) }
            }.toList()
        }
    }
}
