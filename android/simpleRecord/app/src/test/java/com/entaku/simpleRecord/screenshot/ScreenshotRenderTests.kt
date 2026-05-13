package com.entaku.simpleRecord.screenshot

import com.github.takahirom.roborazzi.captureRoboImage
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

    private val outputDir = File("/tmp/voilog_screenshots").also { it.mkdirs() }

    @Test
    fun recordingsList() {
        for (language in ScreenshotLanguage.values()) {
            captureRoboImage("${outputDir.path}/${language.code}_00_recordings.png") {
                ScreenshotPage(language, ScreenshotScreen.RECORDINGS_LIST) {
                    MockRecordingsScreen(language)
                }
            }
        }
    }

    @Test
    fun recording() {
        for (language in ScreenshotLanguage.values()) {
            captureRoboImage("${outputDir.path}/${language.code}_01_recording.png") {
                ScreenshotPage(language, ScreenshotScreen.RECORDING) {
                    MockRecordingScreen(language)
                }
            }
        }
    }

    @Test
    fun playback() {
        for (language in ScreenshotLanguage.values()) {
            captureRoboImage("${outputDir.path}/${language.code}_02_playback.png") {
                ScreenshotPage(language, ScreenshotScreen.PLAYBACK) {
                    MockPlaybackScreen(language)
                }
            }
        }
    }

    @Test
    fun playlist() {
        for (language in ScreenshotLanguage.values()) {
            captureRoboImage("${outputDir.path}/${language.code}_03_playlist.png") {
                ScreenshotPage(language, ScreenshotScreen.PLAYLIST) {
                    MockPlaylistScreen(language)
                }
            }
        }
    }
}
