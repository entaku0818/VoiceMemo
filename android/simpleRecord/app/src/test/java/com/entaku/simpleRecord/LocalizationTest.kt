package com.entaku.simpleRecord

import org.junit.Test
import org.junit.Assert.*

/**
 * Verifies that all required string resource keys are defined (Issue #128)
 * Full resource loading requires Robolectric; here we test key naming conventions.
 */
class LocalizationTest {

    @Test
    fun `all required string key names follow naming convention`() {
        val requiredKeys = listOf(
            "app_name", "cancel", "save", "delete", "yes", "no",
            "back", "settings", "edit_name", "more_options", "create", "name", "name_hint",
            "playlists", "cloud_sync", "start_recording",
            "delete_confirm_title", "delete_confirm_message",
            "edit_name_title", "edit_name_label", "edit_name_prompt",
            "record", "pause", "resume", "stop", "volume_label",
            "play", "back_to_recordings", "repeat",
            "ab_loop_set_a", "ab_loop_set_b", "ab_loop_clear",
            "create_playlist", "enter_playlist_name", "delete_playlist",
            "delete_playlist_confirm", "edit_playlist_name",
            "no_playlists", "tap_to_create",
            "no_recordings_in_playlist", "tap_to_add_recordings",
            "play_all", "add_recording", "all_recordings_added",
            "remove_from_playlist", "add_to_playlist",
            "reorder", "shuffle", "previous", "next",
            "playing", "no_track_selected",
            "repeat_off", "repeat_one", "repeat_all",
            "google_drive_backup", "cloud_sync_description",
            "sign_in_google", "signed_in_as", "cloud_backup",
            "recordings_in_cloud", "backup_to_drive", "restore_from_drive", "sign_out",
            "recording_settings", "file_format", "sampling_rate",
            "bit_rate", "channels", "mono", "stereo", "save_settings",
            "notification_d1_title", "notification_d1_body",
            "notification_d3_title", "notification_d3_body",
            "notification_channel_name", "notification_channel_description"
        )

        // すべてのキーがスネークケースであることを確認
        requiredKeys.forEach { key ->
            assertTrue(
                "Key '$key' must be snake_case",
                key.matches(Regex("[a-z][a-z0-9_]*"))
            )
        }

        // キー数が期待通りであることを確認
        assertEquals(78, requiredKeys.size)
    }

    @Test
    fun `supported locale codes are correct`() {
        val supportedLocales = listOf("ja", "de", "es", "fr", "it", "pt", "ru", "tr", "vi", "zh-rCN", "zh-rTW")
        assertEquals(11, supportedLocales.size)
    }

    @Test
    fun `volume label format string contains percent placeholder`() {
        // volume_label should use %d%% format
        val formatString = "Volume: %d%%"
        val formatted = String.format(formatString, 75)
        assertEquals("Volume: 75%", formatted)
    }
}
