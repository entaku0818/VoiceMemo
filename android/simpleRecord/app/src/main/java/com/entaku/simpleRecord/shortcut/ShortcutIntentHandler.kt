package com.entaku.simpleRecord.shortcut

import android.content.Intent

/**
 * ホーム画面の静的ショートカット(res/xml/shortcuts.xml)から起動された Intent を解析する。
 *
 * iOS版のApp Intents/Siriショートカット(録音開始等、ios/VoiLog/AppIntents/VoiceMemoAppIntents.swift)
 * に相当する機能をAndroidでも提供するために追加 (issue #204)。
 */
object ShortcutIntentHandler {

    /** ショートカットの種別を識別するためのIntent extraキー。 */
    const val EXTRA_SHORTCUT_ACTION = "shortcut_action"

    /** 「録音開始」ショートカットを表すaction値。shortcuts.xml内のintent extraと対応する。 */
    const val ACTION_START_RECORDING = "start_recording"

    /** ShortcutManagerCompat.reportShortcutUsed に渡すショートカットID。shortcuts.xml内のshortcutIdと対応する。 */
    const val SHORTCUT_ID_START_RECORDING = "start_recording"

    /**
     * 渡されたIntentが「録音開始」ショートカット経由での起動を要求しているかどうかを判定する。
     */
    fun isStartRecordingRequested(intent: Intent?): Boolean {
        return extractShortcutAction(intent) == ACTION_START_RECORDING
    }

    /**
     * Intentからショートカットのaction extraを取り出す。テスト容易性のためIntent依存部分を切り出す。
     */
    fun extractShortcutAction(intent: Intent?): String? {
        return intent?.getStringExtra(EXTRA_SHORTCUT_ACTION)
    }
}
