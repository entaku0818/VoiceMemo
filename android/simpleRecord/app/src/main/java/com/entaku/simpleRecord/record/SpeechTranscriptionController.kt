package com.entaku.simpleRecord.record

import android.content.Context

/**
 * 録音中のリアルタイム音声文字起こしを抽象化するインターフェース。
 *
 * iOS の SFSpeechRecognizer によるリアルタイム認識 (ios/VoiLog/AudioRecorder.swift) に相当する
 * 機能を Android の android.speech.SpeechRecognizer で提供する (issue #198)。
 * 既存の録音後サーバー文字起こし機能 (com.entaku.simpleRecord.transcription) とは独立している。
 *
 * 実装が Android フレームワーク(android.speech.SpeechRecognizer)に依存するため、
 * ユニットテストではフェイク実装に差し替えて [RecordViewModel] 側のロジックのみを検証する。
 */
interface SpeechTranscriptionController {
    /**
     * リアルタイム文字起こしを開始する。
     *
     * @param context 音声認識エンジンの生成に使う Context。
     * @param initialText 一時停止からの再開時など、既存の認識済みテキストに続けたい場合に渡す。
     * @param onResult 認識結果(部分結果を含む、確定するたびに更新される全文)を通知するコールバック。
     * @return 端末が音声認識に対応していないなどの理由で開始できなかった場合は false。
     */
    fun start(context: Context, initialText: String, onResult: (String) -> Unit): Boolean

    /** 文字起こしを停止する。録音の一時停止・終了時に呼ぶ。 */
    fun stop()

    /** 内部リソースを解放する。ViewModel破棄時に呼ぶ。 */
    fun destroy()
}
