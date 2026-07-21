package com.entaku.simpleRecord.shortcut

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * ホーム画面ショートカット(shortcuts.xml)から渡されるIntentの解析ロジックのテスト (issue #204)。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class ShortcutIntentHandlerTest {

    @Test
    fun `isStartRecordingRequested is true when shortcut extra matches start_recording`() {
        val intent = Intent().apply {
            putExtra(ShortcutIntentHandler.EXTRA_SHORTCUT_ACTION, ShortcutIntentHandler.ACTION_START_RECORDING)
        }

        assertTrue(ShortcutIntentHandler.isStartRecordingRequested(intent))
    }

    @Test
    fun `isStartRecordingRequested is false when extra is missing`() {
        val intent = Intent()

        assertFalse(ShortcutIntentHandler.isStartRecordingRequested(intent))
    }

    @Test
    fun `isStartRecordingRequested is false when extra has an unrelated value`() {
        val intent = Intent().apply {
            putExtra(ShortcutIntentHandler.EXTRA_SHORTCUT_ACTION, "unrelated_action")
        }

        assertFalse(ShortcutIntentHandler.isStartRecordingRequested(intent))
    }

    @Test
    fun `isStartRecordingRequested is false when intent is null`() {
        assertFalse(ShortcutIntentHandler.isStartRecordingRequested(null))
    }

    @Test
    fun `extractShortcutAction returns the raw extra value`() {
        val intent = Intent().apply {
            putExtra(ShortcutIntentHandler.EXTRA_SHORTCUT_ACTION, "some_value")
        }

        assertEquals("some_value", ShortcutIntentHandler.extractShortcutAction(intent))
    }

    @Test
    fun `extractShortcutAction returns null when intent is null`() {
        assertEquals(null, ShortcutIntentHandler.extractShortcutAction(null))
    }
}
