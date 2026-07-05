import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class TranscriptionFeatureTests: XCTestCase {

    private let testURL = URL(fileURLWithPath: "/tmp/test.m4a")

    private func makeStore(
        status: TranscriptionFeature.State.Status = .idle,
        uploadURL: @escaping @Sendable (String, String) async throws -> TranscriptionClient.UploadURLResponse = { _, _ in
            .init(uploadUrl: "https://signed.example.com/audio", fileId: "file-1", blobName: "blob-1")
        },
        transcribe: @escaping @Sendable (String, String, String) async throws -> TranscriptionClient.TranscriptionResponse = { _, _, _ in
            .init(transcription: "テスト文章", segments: nil, summary: nil)
        },
        uploadAudio: @escaping @Sendable (URL, String, String) async throws -> Void = { _, _, _ in },
        currentUserIDToken: @escaping @Sendable (Bool) async throws -> String = { _ in "test-token" }
    ) -> TestStore<TranscriptionFeature.State, TranscriptionFeature.Action> {
        TestStore(
            initialState: TranscriptionFeature.State(audioURL: testURL, status: status)
        ) {
            TranscriptionFeature()
        } withDependencies: {
            $0.transcriptionClient = TranscriptionClient(
                uploadURL: uploadURL,
                transcribe: transcribe,
                uploadAudio: uploadAudio
            )
            $0.firebaseAuthClient = FirebaseAuthClient(currentUserIDToken: currentUserIDToken)
        }
    }

    /// `.failed` に遷移したことだけを確認する。失敗メッセージの文言はロケール依存のため検証しない。
    private func assertStatusIsFailed(
        _ status: TranscriptionFeature.State.Status,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failed = status else {
            XCTFail("Expected .failed but got \(status)", file: file, line: line)
            return
        }
    }

    // MARK: - startTapped: sets status to .uploading immediately

    func testStartTapped_setsStatusToUploading() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.startTapped) {
            $0.status = .uploading
        }
        await store.skipReceivedActions()
    }

    // MARK: - 正常フロー: idle → uploading → transcribing → done

    func testStartTapped_successFlow_reachesDone() async {
        let store = makeStore(
            uploadURL: { _, _ in .init(uploadUrl: "https://signed.url/audio", fileId: "f1", blobName: "b1") },
            transcribe: { _, _, _ in
                .init(
                    transcription: "文字起こし結果",
                    segments: [.init(time: "0:00", speaker: "A", text: "文字起こし結果")],
                    summary: "要約テスト"
                )
            },
            uploadAudio: { _, _, _ in }
        )

        await store.send(.startTapped) {
            $0.status = .uploading
        }
        await store.receive(\._uploadCompleted) {
            $0.status = .transcribing
        }
        await store.receive(\._transcriptionCompleted) {
            $0.status = .done
            $0.savedText = "文字起こし結果"
            $0.result = .init(
                transcription: "文字起こし結果",
                segments: [.init(time: "0:00", speaker: "A", text: "文字起こし結果")],
                summary: "要約テスト"
            )
        }
    }

    // MARK: - 正常フロー: segments/summary が nil の場合、空配列・空文字で補完される

    func testStartTapped_nilSegmentsAndSummary_defaultsToEmpty() async {
        let store = makeStore(
            transcribe: { _, _, _ in .init(transcription: "本文のみ", segments: nil, summary: nil) }
        )

        await store.send(.startTapped) { $0.status = .uploading }
        await store.receive(\._uploadCompleted) { $0.status = .transcribing }
        await store.receive(\._transcriptionCompleted) {
            $0.status = .done
            $0.savedText = "本文のみ"
            $0.result = .init(transcription: "本文のみ", segments: [], summary: "")
        }
    }

    // MARK: - Firebase認証失敗 → .failed

    func testStartTapped_authFailure_setsStatusFailed() async {
        struct AuthError: LocalizedError {
            var errorDescription: String? { "認証エラー" }
        }
        let store = makeStore(currentUserIDToken: { _ in throw AuthError() })

        await store.send(.startTapped) { $0.status = .uploading }
        await store.receive(\._failed) {
            $0.status = .failed("認証エラー")
        }
    }

    // MARK: - アップロードURL取得失敗 → .failed

    func testStartTapped_uploadURLFailure_setsStatusFailed() async {
        let store = makeStore(
            uploadURL: { _, _ in throw TranscriptionError.serverError(500, "Internal Server Error") }
        )
        // エラー時に .failed へ遷移することだけを確認する。
        // 失敗メッセージの文言はロケール依存なので検証しない。
        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(\._failed)
        assertStatusIsFailed(store.state.status)
    }

    // MARK: - アップロードURL取得が401 → トークンを強制リフレッシュして1回だけ再試行し成功する

    func testStartTapped_uploadURL401_retriesWithForcedRefreshToken() async {
        let tokenCalls = LockIsolated<[Bool]>([])
        let store = makeStore(
            uploadURL: { token, _ in
                if token == "stale-token" {
                    throw TranscriptionError.serverError(401, "Unauthorized")
                }
                return .init(uploadUrl: "https://signed.url/audio", fileId: "f1", blobName: "b1")
            },
            transcribe: { _, _, _ in .init(transcription: "再試行成功", segments: nil, summary: nil) },
            currentUserIDToken: { forcingRefresh in
                tokenCalls.withValue { $0.append(forcingRefresh) }
                return forcingRefresh ? "fresh-token" : "stale-token"
            }
        )
        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(\._uploadCompleted) { $0.status = .transcribing }
        await store.receive(\._transcriptionCompleted) {
            $0.status = .done
            $0.savedText = "再試行成功"
        }
        XCTAssertTrue(tokenCalls.value.contains(true), "401後にforcingRefresh=trueで再取得しているはず")
    }

    // MARK: - アップロードURL取得が401を繰り返す → 1回のリトライ後は.failedになる

    func testStartTapped_uploadURLRepeated401_failsAfterSingleRetry() async {
        let callCount = LockIsolated(0)
        let store = makeStore(
            uploadURL: { _, _ in
                callCount.withValue { $0 += 1 }
                throw TranscriptionError.serverError(401, "Unauthorized")
            }
        )
        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(\._failed)
        assertStatusIsFailed(store.state.status)
        XCTAssertEqual(callCount.value, 2, "初回 + 強制リフレッシュ後の1回のみ再試行するはず")
    }

    // MARK: - 文字起こしAPIが401 → トークンを強制リフレッシュして1回だけ再試行し成功する

    func testStartTapped_transcribe401_retriesWithForcedRefreshToken() async {
        let store = makeStore(
            transcribe: { token, _, _ in
                if token == "stale-token" {
                    throw TranscriptionError.serverError(401, "Unauthorized")
                }
                return .init(transcription: "再試行成功", segments: nil, summary: nil)
            },
            currentUserIDToken: { forcingRefresh in forcingRefresh ? "fresh-token" : "stale-token" }
        )
        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(\._uploadCompleted) { $0.status = .transcribing }
        await store.receive(\._transcriptionCompleted) {
            $0.status = .done
            $0.savedText = "再試行成功"
        }
    }

    // MARK: - 音声アップロード失敗 → .failed

    func testStartTapped_audioUploadFailure_setsStatusFailed() async {
        let store = makeStore(
            uploadAudio: { _, _, _ in throw TranscriptionError.uploadFailed(403) }
        )
        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(\._uploadCompleted) { $0.status = .transcribing }
        await store.receive(\._failed)
        assertStatusIsFailed(store.state.status)
    }

    // MARK: - 文字起こしAPI失敗 → .failed

    func testStartTapped_transcribeFailure_setsStatusFailed() async {
        let store = makeStore(
            transcribe: { _, _, _ in throw TranscriptionError.serverError(502, "Bad Gateway") }
        )
        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(\._uploadCompleted) { $0.status = .transcribing }
        await store.receive(\._failed)
        assertStatusIsFailed(store.state.status)
    }

    // MARK: - エラー後に再試行できる

    func testRetry_afterFailure_canRestartFlow() async {
        let store = makeStore(
            transcribe: { _, _, _ in .init(transcription: "再試行成功", segments: nil, summary: nil) }
        )
        store.exhaustivity = .off

        // 1回目: 失敗を直接注入
        await store.send(._failed("最初のエラー")) { $0.status = .failed("最初のエラー") }

        // 2回目: 再試行 → 成功
        await store.send(.startTapped) { $0.status = .uploading }
        await store.skipReceivedActions()
        XCTAssertEqual(store.state.status, .done)
    }

    // MARK: - _uploadCompleted は blobName/uploadURL をロギングのみ（状態変化なし＋transcribing遷移）

    func testUploadCompleted_setsTranscribing() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(._uploadCompleted(blobName: "b1", uploadURL: "https://example.com")) {
            $0.status = .transcribing
        }
    }

    // MARK: - delegate action は reducer で処理されない（pass-through）

    func testDelegateAction_isPassthrough() async {
        let store = makeStore()

        await store.send(.delegate(.transcriptionSaved(text: "saved")))
        // delegate action が reducer に副作用を起こさないことを確認
        XCTAssertEqual(store.state.status, .idle)
        XCTAssertNil(store.state.result)
    }
}
