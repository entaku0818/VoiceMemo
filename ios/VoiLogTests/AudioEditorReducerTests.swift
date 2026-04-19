import XCTest
import ComposableArchitecture
@testable import VoiLog

// MARK: - Mock

private struct MockAudioProcessingService: AudioProcessingServiceProtocol {
    var splitResult: Result<[URL], Error>

    func generateWaveformData(for url: URL) async throws -> [Float] { [] }
    func trimAudio(at url: URL, range: ClosedRange<Double>) async throws -> URL { url }
    func splitAudio(at url: URL, atTime: Double) async throws -> [URL] {
        switch splitResult {
        case .success(let urls): return urls
        case .failure(let error): throw error
        }
    }
    func mergeAudio(urls: [URL]) async throws -> URL { urls[0] }
    func adjustVolume(at url: URL, level: Float, range: ClosedRange<Double>?) async throws -> URL { url }
}

@MainActor
final class AudioEditorReducerTests: XCTestCase {

    private let testURL = URL(fileURLWithPath: "/tmp/test.m4a")
    private let testID = UUID()

    // MARK: - Reducer ガード: 選択範囲なし

    /// 選択範囲が nil の場合は .split が即時エラー（effect 発行なし）
    func testSplit_noSelectionRange_showsError() async {
        let store = TestStore(
            initialState: AudioEditorReducer.State(
                memoID: testID,
                audioURL: testURL,
                originalTitle: "テスト録音",
                duration: 10.0,
                selectedRange: nil
            )
        ) {
            AudioEditorReducer()
        } withDependencies: {
            $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([]))
        }

        // String(localized:) でロケール非依存に reducer と同じ文字列を参照
        await store.send(.split) {
            $0.errorMessage = String(localized: "分割するポイントを選択してください。")
        }
    }

    /// 選択範囲が点でない（範囲選択）場合は .split が即時エラー
    func testSplit_rangeSelection_showsError() async {
        let store = TestStore(
            initialState: AudioEditorReducer.State(
                memoID: testID,
                audioURL: testURL,
                originalTitle: "テスト録音",
                duration: 10.0,
                selectedRange: 2.0...5.0
            )
        ) {
            AudioEditorReducer()
        } withDependencies: {
            $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([]))
        }

        await store.send(.split) {
            $0.errorMessage = String(localized: "分割するポイントを選択してください。")
        }
    }

    // MARK: - Crash #2: splitAudio エラー時に errorMessage が設定される

    /// atTime=0 等で splitAudio が throw した場合、errorMessage が設定されクラッシュしない
    func testSplit_serviceThrows_setsErrorMessage() async {
        let splitError = NSError(
            domain: "AudioProcessing",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "分割ポイントが無効です（0秒または音声の終端以降）"]
        )
        let store = TestStore(
            initialState: AudioEditorReducer.State(
                memoID: testID,
                audioURL: testURL,
                originalTitle: "テスト録音",
                duration: 10.0,
                selectedRange: 0.0...0.0
            )
        ) {
            AudioEditorReducer()
        } withDependencies: {
            $0.audioProcessingService = MockAudioProcessingService(splitResult: .failure(splitError))
        }

        await store.send(.split) {
            $0.processingOperation = .split(atTime: 0.0)
        }
        await store.receive(\.splitCompleted) {
            $0.processingOperation = nil
            $0.errorMessage = String(format: String(localized: "分割に失敗しました: %@"), splitError.localizedDescription)
        }
    }

    // MARK: - adjustVolume

    /// adjustVolume 成功時に editHistory に記録される（nil順序バグの回帰テスト）
    func testAdjustVolume_success_updatesEditHistory() async {
        let store = TestStore(
            initialState: AudioEditorReducer.State(
                memoID: testID,
                audioURL: testURL,
                originalTitle: "テスト録音",
                duration: 10.0,
                selectedRange: 2.0...8.0
            )
        ) {
            AudioEditorReducer()
        } withDependencies: {
            $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([]))
        }

        await store.send(.adjustVolume(0.5)) {
            $0.processingOperation = .adjustVolume(level: 0.5, range: 2.0...8.0)
        }
        await store.receive(\.adjustVolumeCompleted) {
            $0.processingOperation = nil
            $0.isEdited = true
            $0.isLoadingWaveform = true
            $0.editHistory = [.adjustVolume(level: 0.5, range: 2.0...8.0)]
        }
        await store.receive(\.audioLoaded, timeout: .seconds(10)) {
            $0.isLoadingWaveform = false
        }
    }

    /// 正常な中間点で分割成功した場合、audioURL が更新され isEdited = true になる
    func testSplit_validMidpoint_updatesURL() async {
        let firstURL = URL(fileURLWithPath: "/tmp/first.m4a")
        let secondURL = URL(fileURLWithPath: "/tmp/second.m4a")
        let store = TestStore(
            initialState: AudioEditorReducer.State(
                memoID: testID,
                audioURL: testURL,
                originalTitle: "テスト録音",
                duration: 10.0,
                selectedRange: 5.0...5.0
            )
        ) {
            AudioEditorReducer()
        } withDependencies: {
            $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([firstURL, secondURL]))
        }
        await store.send(.split) {
            $0.processingOperation = .split(atTime: 5.0)
        }
        await store.receive(\.splitCompleted) {
            $0.processingOperation = nil
            $0.audioURL = firstURL
            $0.isEdited = true
            $0.isLoadingWaveform = true
            $0.editHistory = [.split(atTime: 5.0)]
            $0.errorMessage = String(
                format: String(localized: "分割が完了しました。\n分割ポイントまでの「%@」\nとして保存されました。"),
                "テスト録音 (前半)"
            )
        }
        // audioLoaded は waveform 生成後に非同期で届く。simulator のスケジューラ遅延に余裕を持たせる
        await store.receive(\.audioLoaded, timeout: .seconds(10)) {
            $0.isLoadingWaveform = false
        }
    }
}

// MARK: - AudioProcessingService 直接テスト（Crash #2 guard 検証）

final class AudioProcessingServiceGuardTests: XCTestCase {

    private let service = AudioProcessingService()

    /// ファイルが存在しない場合でも splitAudio は throw するだけでクラッシュしない
    func testSplitAudio_missingFile_throwsErrorNotCrash() async {
        let url = URL(fileURLWithPath: "/nonexistent/audio.m4a")
        do {
            _ = try await service.splitAudio(at: url, atTime: 0.0)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    /// guard の境界値: atTime <= 0 は guard に引っかかるはずだが、
    /// findAudioFile が先に失敗するため最低でもクラッシュしないことを確認
    func testSplitAudio_atTimeNegative_throwsErrorNotCrash() async {
        let url = URL(fileURLWithPath: "/nonexistent/audio.m4a")
        do {
            _ = try await service.splitAudio(at: url, atTime: -1.0)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
