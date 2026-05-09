package com.entaku.simpleRecord.screenshot

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

// Pixel 8 相当: 1080x2400px (xxhdpi=3x → 360x800dp)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w360dp-h800dp-xxhdpi", sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenshotRenderTests {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val outputDir = File("/tmp/voilog_screenshots").also { it.mkdirs() }

    // MARK: - 録音一覧

    @Test
    fun recordingsList() {
        for (language in ScreenshotLanguage.values()) {
            composeTestRule.setContent {
                ScreenshotPage(language, ScreenshotScreen.RECORDINGS_LIST) {
                    MockRecordingsScreen(language)
                }
            }
            composeTestRule.onRoot().captureRoboImage(
                filePath = "${outputDir.path}/${language.code}_00_recordings.png"
            )
        }
    }

    // MARK: - 録音中

    @Test
    fun recording() {
        for (language in ScreenshotLanguage.values()) {
            composeTestRule.setContent {
                ScreenshotPage(language, ScreenshotScreen.RECORDING) {
                    MockRecordingScreen(language)
                }
            }
            composeTestRule.onRoot().captureRoboImage(
                filePath = "${outputDir.path}/${language.code}_01_recording.png"
            )
        }
    }

    // MARK: - 再生

    @Test
    fun playback() {
        for (language in ScreenshotLanguage.values()) {
            composeTestRule.setContent {
                ScreenshotPage(language, ScreenshotScreen.PLAYBACK) {
                    MockPlaybackScreen(language)
                }
            }
            composeTestRule.onRoot().captureRoboImage(
                filePath = "${outputDir.path}/${language.code}_02_playback.png"
            )
        }
    }

    // MARK: - プレイリスト

    @Test
    fun playlist() {
        for (language in ScreenshotLanguage.values()) {
            composeTestRule.setContent {
                ScreenshotPage(language, ScreenshotScreen.PLAYLIST) {
                    MockPlaylistScreen(language)
                }
            }
            composeTestRule.onRoot().captureRoboImage(
                filePath = "${outputDir.path}/${language.code}_03_playlist.png"
            )
        }
    }
}
