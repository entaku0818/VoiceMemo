import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class MeetingMinutesFeatureTests: XCTestCase {

    private let sampleTranscription = "田中: 次回のリリースは来月末を目標にしましょう。\n鈴木: 了解です。テストはいつ完了しますか？\n田中: 来週中には完了させます。"

    private func makeStore(
        transcriptionText: String? = nil,
        savedMinutes: MeetingMinutesResult? = nil,
        generate: @escaping @Sendable (String) async throws -> MeetingMinutesResult = { _ in
            MeetingMinutesResult(summary: "テスト要約", todos: ["TODO 1", "TODO 2"])
        }
    ) -> TestStore<MeetingMinutesFeature.State, MeetingMinutesFeature.Action> {
        TestStore(
            initialState: MeetingMinutesFeature.State(
                transcriptionText: transcriptionText ?? sampleTranscription,
                savedMinutes: savedMinutes
            )
        ) {
            MeetingMinutesFeature()
        } withDependencies: {
            $0.meetingMinutesClient = MeetingMinutesClient(generate: generate)
        }
    }

    // MARK: - generateTapped: idle → generating

    func testGenerateTapped_setsStatusToGenerating() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.view(.generateTapped)) {
            $0.status = .generating
        }
        await store.skipReceivedActions()
    }

    // MARK: - 正常フロー: generating → done

    func testGenerateTapped_successFlow_reachesDone() async {
        let expectedResult = MeetingMinutesResult(
            summary: "来月末リリースを目標にする。テストは来週完了。",
            todos: ["テストを来週中に完了させる", "来月末リリースの確認"]
        )
        let store = makeStore(generate: { _ in expectedResult })

        await store.send(.view(.generateTapped)) {
            $0.status = .generating
        }
        await store.receive(\._generationCompleted) {
            $0.status = .done(expectedResult)
        }
    }

    // MARK: - エラーフロー: failed

    func testGenerateTapped_failureFlow_reachesFailed() async {
        let store = makeStore(generate: { _ in
            throw MeetingMinutesError.modelUnavailable
        })

        await store.send(.view(.generateTapped)) {
            $0.status = .generating
        }
        await store.receive(\._generationFailed) {
            $0.status = .failed(MeetingMinutesError.modelUnavailable.errorDescription ?? "")
        }
    }

    // MARK: - 空テキストエラー

    func testGenerateTapped_emptyText_reachesFailed() async {
        let store = makeStore(
            transcriptionText: "",
            generate: { _ in throw MeetingMinutesError.noTranscriptionText }
        )

        await store.send(.view(.generateTapped)) {
            $0.status = .generating
        }
        await store.receive(\._generationFailed) {
            $0.status = .failed(MeetingMinutesError.noTranscriptionText.errorDescription ?? "")
        }
    }

    // MARK: - saveTapped: result → delegate.saved + savedMinutes 更新

    func testSaveTapped_sendsDelegateSaved() async {
        let result = MeetingMinutesResult(
            summary: "要約テスト",
            todos: ["TODO A"]
        )
        let store = makeStore()
        store.exhaustivity = .off

        // done 状態にセット
        await store.send(._generationCompleted(result)) {
            $0.status = .done(result)
        }

        await store.send(.view(.saveTapped)) {
            $0.savedMinutes = result
        }
        await store.receive(\.delegate.saved) { _ in }
    }

    // MARK: - saveTapped: done でない場合は何もしない

    func testSaveTapped_whenNotDone_doesNothing() async {
        let store = makeStore()
        // status は .idle のまま → saveTapped は無視される
        await store.send(.view(.saveTapped))
    }

    // MARK: - 再生成で status が上書きされる

    func testGenerateTapped_calledTwice_secondCallOverwrites() async {
        let first = MeetingMinutesResult(summary: "1回目", todos: [])
        let second = MeetingMinutesResult(summary: "2回目", todos: ["TODO"])
        var callCount = 0
        let store = makeStore(generate: { _ in
            callCount += 1
            return callCount == 1 ? first : second
        })

        // 1回目
        await store.send(.view(.generateTapped)) { $0.status = .generating }
        await store.receive(\._generationCompleted) { $0.status = .done(first) }

        // 2回目（再生成）
        await store.send(.view(.generateTapped)) { $0.status = .generating }
        await store.receive(\._generationCompleted) { $0.status = .done(second) }
    }
}
