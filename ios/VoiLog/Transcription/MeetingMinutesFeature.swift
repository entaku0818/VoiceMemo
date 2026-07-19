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

enum MeetingMinutesError: Error, LocalizedError, Equatable {
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
        try await MeetingMinutesGenerator.generate(
            text: text,
            isOnDeviceAvailable: {
                guard #available(iOS 26, *) else { return false }
                return SystemLanguageModel.default.isAvailable
            },
            onDevice: { text in
                guard #available(iOS 26, *) else { throw MeetingMinutesError.unavailable }
                return try await generateWithFoundationModels(text)
            },
            cloudFallback: { text in
                try await MeetingMinutesCloudFallback().generate(text: text)
            }
        )
    })

    static let testValue = MeetingMinutesClient(generate: { _ in
        MeetingMinutesResult(
            summary: "テスト要約です。",
            todos: ["TODO 1", "TODO 2"]
        )
    })
}

/// オンデバイス（Foundation Models）が使えるかどうかで処理を振り分ける純粋なロジック。
///
/// 実際の `SystemLanguageModel`/ネットワーク呼び出しは呼び出し元からクロージャとして注入するため、
/// このロジック自体はモックだけで（実機のApple Intelligence状態に依存せず）テストできる。
enum MeetingMinutesGenerator {
    static func generate(
        text: String,
        isOnDeviceAvailable: () -> Bool,
        onDevice: (String) async throws -> MeetingMinutesResult,
        cloudFallback: (String) async throws -> MeetingMinutesResult
    ) async throws -> MeetingMinutesResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeetingMinutesError.noTranscriptionText
        }
        guard isOnDeviceAvailable() else {
            return try await cloudFallback(text)
        }
        return try await onDevice(text)
    }
}

/// オンデバイス（Foundation Models）が非対応の環境向けに、既存のクラウドAPI（Gemini `/minutes`）で
/// 議事録要約を生成するフォールバック。
struct MeetingMinutesCloudFallback {
    @Dependency(\.transcriptionClient) var transcriptionClient
    @Dependency(\.firebaseAuthClient) var firebaseAuth

    func generate(text: String) async throws -> MeetingMinutesResult {
        let language = TranscriptionFeature.State.detectLanguage()
        do {
            let idToken = try await firebaseAuth.currentUserIDToken(false)
            let (response, _) = try await withAuthRetry(
                firebaseAuth: firebaseAuth,
                currentToken: idToken
            ) { token in
                try await transcriptionClient.generateMinutes(token, text, language)
            }
            return MeetingMinutesResult(summary: response.summary, todos: response.todos)
        } catch {
            throw MeetingMinutesError.generationFailed(error.localizedDescription)
        }
    }
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
