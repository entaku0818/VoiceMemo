import ComposableArchitecture
import Foundation
import FoundationModels

// MARK: - Result

struct MeetingMinutesResult: Equatable, Sendable {
    var summary: String
    var todos: [String]
}

// MARK: - Client

struct MeetingMinutesClient: Sendable {
    var generate: @Sendable (String) async throws -> MeetingMinutesResult
}

enum MeetingMinutesError: Error, LocalizedError {
    case unavailable
    case noTranscriptionText
    case modelUnavailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "iOS 26 以上が必要です", table: "MeetingMinutes")
        case .noTranscriptionText:
            return String(localized: "文字起こしデータがありません", table: "MeetingMinutes")
        case .modelUnavailable:
            return String(localized: "Apple Intelligence が利用できません。設定を確認してください。", table: "MeetingMinutes")
        case .generationFailed(let msg):
            return msg
        }
    }
}

extension MeetingMinutesClient: DependencyKey {
    static let liveValue = MeetingMinutesClient(generate: { text in
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeetingMinutesError.noTranscriptionText
        }
        guard #available(iOS 26, *) else {
            throw MeetingMinutesError.unavailable
        }
        return try await generateWithFoundationModels(text)
    })

    static let testValue = MeetingMinutesClient(generate: { _ in
        MeetingMinutesResult(
            summary: "テスト要約です。",
            todos: ["TODO 1", "TODO 2"]
        )
    })
}

extension DependencyValues {
    var meetingMinutesClient: MeetingMinutesClient {
        get { self[MeetingMinutesClient.self] }
        set { self[MeetingMinutesClient.self] = newValue }
    }
}

@available(iOS 26, *)
@Generable
private struct _GeneratedMinutes {
    @Guide(description: "会議の要約（日本語、3〜5文で簡潔に）")
    var summary: String
    @Guide(description: "会議で決まったアクションアイテムやTODOのリスト（日本語）")
    var todos: [String]
}

@available(iOS 26, *)
private func generateWithFoundationModels(_ text: String) async throws -> MeetingMinutesResult {
    let model = SystemLanguageModel.default
    guard model.isAvailable else {
        throw MeetingMinutesError.modelUnavailable
    }
    let session = LanguageModelSession(model: model)
    let prompt = """
    以下の会議の文字起こしから議事録を日本語で作成してください。

    文字起こし:
    \(text)
    """
    do {
        let response = try await session.respond(to: prompt, generating: _GeneratedMinutes.self)
        let minutes = response.content
        return MeetingMinutesResult(summary: minutes.summary, todos: minutes.todos)
    } catch {
        throw MeetingMinutesError.generationFailed(error.localizedDescription)
    }
}

// MARK: - Reducer

@Reducer
struct MeetingMinutesFeature {
    @ObservableState
    struct State: Equatable {
        var transcriptionText: String
        var savedMinutes: MeetingMinutesResult?
        var status: Status = .idle

        enum Status: Equatable {
            case idle
            case generating
            case done(MeetingMinutesResult)
            case failed(String)
        }
    }

    @CasePathable
    enum Action: ViewAction {
        case view(View)
        case delegate(Delegate)
        case _generationCompleted(MeetingMinutesResult)
        case _generationFailed(String)

        @CasePathable
        enum View {
            case generateTapped
            case saveTapped
        }

        @CasePathable
        enum Delegate {
            case saved(String)
        }
    }

    @Dependency(\.meetingMinutesClient) var meetingMinutesClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.generateTapped):
                state.status = .generating
                let text = state.transcriptionText
                return .run { send in
                    do {
                        let result = try await meetingMinutesClient.generate(text)
                        await send(._generationCompleted(result))
                    } catch {
                        let message = (error as? MeetingMinutesError)?.errorDescription
                            ?? error.localizedDescription
                        await send(._generationFailed(message))
                    }
                }

            case .view(.saveTapped):
                guard case let .done(result) = state.status else { return .none }
                state.savedMinutes = result
                let combined = formatForStorage(result)
                return .send(.delegate(.saved(combined)))

            case let ._generationCompleted(result):
                state.status = .done(result)
                return .none

            case let ._generationFailed(message):
                state.status = .failed(message)
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func formatForStorage(_ result: MeetingMinutesResult) -> String {
        var lines = ["# 要約", result.summary]
        if !result.todos.isEmpty {
            lines += ["", "# TODO"]
            lines += result.todos.map { "- \($0)" }
        }
        return lines.joined(separator: "\n")
    }
}
