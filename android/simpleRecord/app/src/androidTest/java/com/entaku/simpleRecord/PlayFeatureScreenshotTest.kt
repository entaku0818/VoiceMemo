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
class PlayFeatureScreenshotTest {
    @get:Rule val compose = createComposeRule()
    @Suppress("UNCHECKED_CAST")
    private fun setState(model: Any, value: Any) {
        val field = model.javaClass.getDeclaredField("_uiState").apply { isAccessible = true }
        (field.get(model) as MutableStateFlow<Any>).value = value
    }
    private fun render(language: String, screen: String) {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        val config = Configuration(target.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(language)); fontScale = 1f
        }
        val context = target.createConfigurationContext(config)
        val ja = language == "ja"
        val title = if (ja) "新しいアプリの企画ミーティング" else "Planning our next app"
        val summary = if (ja) "会議や講義の録音をすぐに見つけられるアプリを企画しました。まずは録音と検索に集中し、来週のテストで使い心地を確かめます。" else "We planned an app that makes meeting and lecture recordings easier to find. The first version will focus on recording and search, with a usability test next week."
        val texts = if (ja) listOf("今日は、毎日の録音をもっと便利にするアプリについて話しましょう。会議や講義を録っても、あとで探すのに時間がかかりますよね。", "録音にタイトルを付けて、キーワードで検索できると便利ですね。まずはワンタップで録音を始められることを大切にしたいです。", "では、金曜日までに画面の案を作りましょう。来週は実際に使ってもらい、録音から聴き返すまでの流れを確認します。") else listOf("Let's plan an app that makes everyday recording easier. Finding the right moment in a meeting or lecture recording can take a lot of time.", "Titles and keyword search would help. Let's make starting a recording with one tap our main priority.", "Let's prepare the screen designs by Friday. Next week, we'll ask people to try recording and listening back, and use their feedback to improve the flow.")
        val todos = if (ja) listOf("金曜日までに録音・検索画面の案を作成する", "来週のユーザーテストの日程を決める", "テストの意見をまとめ、改善点を共有する") else listOf("Prepare screen designs by Friday", "Schedule next week's usability test", "Summarize feedback and share improvements")
        val owner = object : ViewModelStoreOwner { override val viewModelStore = ViewModelStore() }
        val transcript = TranscriptionViewModel("/sample.m4a")
        setState(transcript, TranscriptionUiState.Done(TranscriptionResult(texts.joinToString("\n"), texts.mapIndexed { i, text -> TranscriptionSegment(listOf("0:00", "0:18", "0:36")[i], if (ja) "話者${i % 2 + 1}" else "Speaker ${i % 2 + 1}", text) }, summary)))
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
    }
    @Test fun jaTranscript() = render("ja", "01_transcript")
    @Test fun enTranscript() = render("en", "01_transcript")
    @Test fun jaMinutes() = render("ja", "02_minutes")
    @Test fun enMinutes() = render("en", "02_minutes")
    @Test fun jaPlayback() = render("ja", "04_playback")
    @Test fun enPlayback() = render("en", "04_playback")
    @Test fun jaCloud() = render("ja", "05_cloud")
    @Test fun enCloud() = render("en", "05_cloud")
}
