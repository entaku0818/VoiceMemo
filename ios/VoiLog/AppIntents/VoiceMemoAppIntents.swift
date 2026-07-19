//
//  VoiceMemoAppIntents.swift
//  VoiLog
//
//  Shortcuts/Siri から「録音開始」「録音停止」「最新の録音を文字起こし」を
//  実行できるようにする App Intents（issue #187）。
//

import AppIntents
import ComposableArchitecture
import Foundation

// MARK: - Start Recording

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "録音を開始"
    static var description = IntentDescription("新しい録音を開始します。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await Self.run(store: AppEnvironment.store)
    }

    /// テストから差し替え可能にするため `perform()` から切り出した実処理。
    @MainActor
    static func run(store: StoreOf<VoiceAppFeature>) async throws -> some IntentResult & ProvidesDialog {
        guard store.recordingFeature.recordingState == .idle else {
            return .result(dialog: "\(String(localized: "すでに録音中です。"))")
        }

        store.send(.recordingFeature(.view(.recordButtonTapped)))

        let deadline = Date().addingTimeInterval(5)
        while store.recordingFeature.recordingState == .idle {
            if store.recordingFeature.audioPermission == .denied {
                return .result(dialog: "\(String(localized: "マイクの使用が許可されていません。設定アプリで許可してください。"))")
            }
            if Date() > deadline {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        return .result(dialog: "\(String(localized: "録音を開始しました。"))")
    }
}

// MARK: - Stop Recording

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "録音を停止"
    static var description = IntentDescription("実行中の録音を停止して保存します。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await Self.run(store: AppEnvironment.store)
    }

    /// テストから差し替え可能にするため `perform()` から切り出した実処理。
    @MainActor
    static func run(store: StoreOf<VoiceAppFeature>) async throws -> some IntentResult & ProvidesDialog {
        let isRecording = store.recordingFeature.recordingState == .recording
            || store.recordingFeature.recordingState == .paused
        guard isRecording else {
            return .result(dialog: "\(String(localized: "録音していません。"))")
        }

        store.send(.recordingFeature(.view(.stopButtonTapped)))
        try await Task.sleep(nanoseconds: 300_000_000)
        store.send(.recordingFeature(.view(.skipTitle)))

        let deadline = Date().addingTimeInterval(5)
        while store.recordingFeature.recordingState != .idle {
            if Date() > deadline {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        return .result(dialog: "\(String(localized: "録音を保存しました。"))")
    }
}

// MARK: - Transcribe Latest Recording

struct TranscribeLatestRecordingIntent: AppIntent, ProgressReportingIntent {
    static var title: LocalizedStringResource = "最新の録音を文字起こし"
    static var description = IntentDescription("最新の録音をAIで文字起こしします。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let runner = LatestRecordingTranscriptionRunner()

        guard let latest = runner.latestRecording() else {
            return .result(dialog: "\(String(localized: "録音がまだありません。"))")
        }

        progress.totalUnitCount = 3
        progress.completedUnitCount = 0

        do {
            try await runner.transcribe(latest) { completedUnitCount in
                progress.completedUnitCount = completedUnitCount
            }
            let doneMessage = String(
                format: String(localized: "「%@」の文字起こしが完了しました。"),
                latest.title
            )
            return .result(dialog: "\(doneMessage)")
        } catch {
            let failureMessage = String(
                format: String(localized: "文字起こしに失敗しました: %@"),
                error.localizedDescription
            )
            return .result(dialog: "\(failureMessage)")
        }
    }
}

/// `TranscribeLatestRecordingIntent` の実処理を担うヘルパー。
///
/// `@Dependency` プロパティラッパーは `AppIntent` に準拠する型の
/// 保存プロパティとして宣言するとApp Intentsのメタデータ抽出（コンパイル時の
/// 定数評価）がクラッシュするため、AppIntentに準拠しない別型に切り出している。
struct LatestRecordingTranscriptionRunner {
    @Dependency(\.voiceMemoRepository) var repository
    @Dependency(\.transcriptionClient) var transcriptionClient
    @Dependency(\.firebaseAuthClient) var firebaseAuth

    @MainActor
    func latestRecording() -> VoiceMemoRepositoryClient.VoiceMemoVoice? {
        repository.selectAllData().first
    }

    func transcribe(
        _ recording: VoiceMemoRepositoryClient.VoiceMemoVoice,
        onProgress: (Int64) -> Void
    ) async throws -> String {
        let audioURL = recording.url
        let ext = audioURL.pathExtension.isEmpty ? "m4a" : audioURL.pathExtension
        let mimeType = ext == "m4a" ? "audio/mp4" : "audio/\(ext)"
        let language = TranscriptionFeature.State.detectLanguage()

        let idToken = try await firebaseAuth.currentUserIDToken(false)

        let (uploadResponse, tokenAfterUpload) = try await withAuthRetry(
            firebaseAuth: firebaseAuth,
            currentToken: idToken
        ) { token in
            try await transcriptionClient.uploadURL(token, ext)
        }
        onProgress(1)

        try await transcriptionClient.uploadAudio(audioURL, uploadResponse.uploadUrl, mimeType)
        onProgress(2)

        let (transcriptionResponse, _) = try await withAuthRetry(
            firebaseAuth: firebaseAuth,
            currentToken: tokenAfterUpload
        ) { token in
            try await transcriptionClient.transcribe(token, uploadResponse.blobName, language)
        }
        onProgress(3)

        let updated = Self.applying(transcriptionResponse, to: recording)
        await MainActor.run {
            repository.update(updated)
        }

        return transcriptionResponse.transcription
    }

    private static func applying(
        _ response: TranscriptionClient.TranscriptionResponse,
        to recording: VoiceMemoRepositoryClient.VoiceMemoVoice
    ) -> VoiceMemoRepositoryClient.VoiceMemoVoice {
        var updated = recording
        updated.aiTranscriptionText = response.transcription
        if let summary = response.summary, !summary.isEmpty {
            updated.aiMeetingMinutesText = summary
        }
        return updated
    }
}

// MARK: - Shortcuts

struct VoiceMemoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "\(.applicationName)で録音を開始",
                "\(.applicationName)で録音開始"
            ],
            shortTitle: "録音開始",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "\(.applicationName)で録音を停止",
                "\(.applicationName)で録音停止"
            ],
            shortTitle: "録音停止",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: TranscribeLatestRecordingIntent(),
            phrases: [
                "\(.applicationName)で最新の録音を文字起こし",
                "\(.applicationName)で文字起こし"
            ],
            shortTitle: "文字起こし",
            systemImageName: "text.bubble.fill"
        )
    }
}
