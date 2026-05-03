import SwiftUI
import ComposableArchitecture
import Foundation
import FirebaseAuth

// MARK: - Firebase Auth Dependency

struct FirebaseAuthClient {
    var currentUserIDToken: @Sendable () async throws -> String
}

extension FirebaseAuthClient: DependencyKey {
    static let liveValue = FirebaseAuthClient(
        currentUserIDToken: {
            if Auth.auth().currentUser == nil {
                try await Auth.auth().signInAnonymously()
            }
            guard let user = Auth.auth().currentUser else {
                throw TranscriptionError.notAuthenticated
            }
            return try await withCheckedThrowingContinuation { cont in
                user.getIDToken { token, error in
                    if let error { cont.resume(throwing: error); return }
                    guard let token else {
                        cont.resume(throwing: TranscriptionError.notAuthenticated)
                        return
                    }
                    cont.resume(returning: token)
                }
            }
        }
    )
}

extension DependencyValues {
    var firebaseAuthClient: FirebaseAuthClient {
        get { self[FirebaseAuthClient.self] }
        set { self[FirebaseAuthClient.self] = newValue }
    }
}

// MARK: - API Client

struct TranscriptionClient {
    var uploadURL: @Sendable (_ idToken: String, _ ext: String) async throws -> UploadURLResponse
    var transcribe: @Sendable (_ idToken: String, _ blobName: String, _ language: String) async throws -> TranscriptionResponse
    var uploadAudio: @Sendable (_ fileURL: URL, _ signedURL: String, _ mimeType: String) async throws -> Void

    struct UploadURLResponse: Decodable {
        let uploadUrl: String
        let fileId: String
        let blobName: String
    }

    struct TranscriptionResponse: Decodable {
        let transcription: String
        let segments: [Segment]?
        let summary: String?

        struct Segment: Decodable, Equatable {
            let time: String
            let speaker: String?
            let text: String
        }
    }
}

enum TranscriptionError: LocalizedError {
    case notAuthenticated
    case uploadFailed(Int)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "ログインが必要です"
        case let .uploadFailed(code): return "アップロード失敗 (HTTP \(code))"
        case let .serverError(code, body): return "HTTP \(code): \(body)"
        }
    }
}

extension TranscriptionClient: DependencyKey {
    static let serverBaseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "TRANSCRIPTION_SERVER_URL") as? String
            ?? "https://transcription-XXXX-an.a.run.app"
    }()

    static let liveValue = TranscriptionClient(
        uploadURL: { idToken, ext in
            let url = URL(string: "\(serverBaseURL)/upload-url")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(["extension": ext])
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                throw TranscriptionError.serverError(status, body)
            }
            return try JSONDecoder().decode(UploadURLResponse.self, from: data)
        },
        transcribe: { idToken, blobName, language in
            let url = URL(string: "\(serverBaseURL)/transcribe")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(["blobName": blobName, "language": language])
            req.timeoutInterval = 120
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                throw TranscriptionError.serverError(status, body)
            }
            do {
                return try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                throw TranscriptionError.serverError(0, "decode failed: \(body)")
            }
        },
        uploadAudio: { fileURL, signedURL, mimeType in
            let data = try Data(contentsOf: fileURL)
            var req = URLRequest(url: URL(string: signedURL)!)
            req.httpMethod = "PUT"
            req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            req.httpBody = data
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw TranscriptionError.uploadFailed(code)
            }
        }
    )
}

extension DependencyValues {
    var transcriptionClient: TranscriptionClient {
        get { self[TranscriptionClient.self] }
        set { self[TranscriptionClient.self] = newValue }
    }
}

// MARK: - Feature

@Reducer
struct TranscriptionFeature {
    @ObservableState
    struct State: Equatable {
        var audioURL: URL
        var status: Status = .idle
        var result: Result?

        enum Status: Equatable {
            case idle
            case uploading
            case transcribing
            case done
            case failed(String)
        }

        struct Result: Equatable {
            let transcription: String
            let segments: [TranscriptionClient.TranscriptionResponse.Segment]
            let summary: String
        }
    }

    enum Action {
        case startTapped
        case _uploadCompleted(blobName: String, uploadURL: String)
        case _transcriptionCompleted(State.Result)
        case _failed(String)
        case delegate(Delegate)

        enum Delegate {
            case transcriptionSaved(text: String)
        }
    }

    @Dependency(\.transcriptionClient) var client
    @Dependency(\.firebaseAuthClient) var firebaseAuth

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startTapped:
                state.status = .uploading
                let audioURL = state.audioURL
                let ext = audioURL.pathExtension.isEmpty ? "m4a" : audioURL.pathExtension
                let mimeType = ext == "m4a" ? "audio/mp4" : "audio/\(ext)"
                return .run { send in
                    do {
                        let idToken = try await firebaseAuth.currentUserIDToken()
                        let uploadResp = try await client.uploadURL(idToken, ext)
                        await send(._uploadCompleted(blobName: uploadResp.blobName, uploadURL: uploadResp.uploadUrl))
                        try await client.uploadAudio(audioURL, uploadResp.uploadUrl, mimeType)
                        let lang = detectLanguage()
                        let resp = try await client.transcribe(idToken, uploadResp.blobName, lang)
                        await send(._transcriptionCompleted(.init(
                            transcription: resp.transcription,
                            segments: resp.segments ?? [],
                            summary: resp.summary ?? ""
                        )))
                    } catch {
                        await send(._failed(error.localizedDescription))
                    }
                }

            case ._uploadCompleted:
                state.status = .transcribing
                return .none

            case let ._transcriptionCompleted(result):
                state.result = result
                state.status = .done
                return .none

            case let ._failed(message):
                state.status = .failed(message)
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func detectLanguage() -> String {
        let code = Locale.preferredLanguages.first ?? "ja"
        if code.hasPrefix("ja") { return "ja" }
        if code.hasPrefix("zh") { return "zh" }
        if code.hasPrefix("ko") { return "ko" }
        return "en"
    }
}

// MARK: - View

struct TranscriptionView: View {
    @Perception.Bindable var store: StoreOf<TranscriptionFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection
                    if let result = store.result {
                        resultSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("文字起こし")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.status == .idle {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("開始") { store.send(.startTapped) }
                    }
                }
                if case .done = store.status, let result = store.result {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") {
                            store.send(.delegate(.transcriptionSaved(text: result.transcription)))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch store.status {
        case .idle:
            VStack(spacing: 8) {
                Image(systemName: "waveform.and.mic")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("音声をGemini AIで文字起こしします")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

        case .uploading:
            progressRow("音声をアップロード中...")

        case .transcribing:
            progressRow("文字起こし中...")

        case .done:
            Label("完了", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

        case let .failed(msg):
            VStack(alignment: .leading, spacing: 8) {
                Label("エラー", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    Button("再試行") { store.send(.startTapped) }
                        .buttonStyle(.borderedProminent)
                    Button {
                        UIPasteboard.general.string = msg
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func progressRow(_ label: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(label).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func resultSection(_ result: TranscriptionFeature.State.Result) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !result.summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("要約").font(.headline)
                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("全文").font(.headline)
                if result.segments.isEmpty {
                    Text(result.transcription)
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { _, seg in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                if let speaker = seg.speaker, !speaker.isEmpty {
                                    Text(speaker)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(speakerColor(speaker).opacity(0.15))
                                        .foregroundStyle(speakerColor(speaker))
                                        .clipShape(Capsule())
                                }
                                Text(seg.time)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 52, alignment: .leading)
                            Text(seg.text)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func speakerColor(_ speaker: String) -> Color {
        let palette: [Color] = [.blue, .orange, .green, .purple, .red, .teal, .indigo, .pink]
        let index = Int(speaker.unicodeScalars.first?.value ?? 65) % palette.count
        return palette[index]
    }
}

#Preview {
    TranscriptionView(
        store: Store(initialState: TranscriptionFeature.State(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            status: .done,
            result: .init(
                transcription: "本日の会議を始めます。まず先週のアクションアイテムを確認しましょう。",
                segments: [
                    .init(time: "0:00", speaker: "A", text: "本日の会議を始めます。"),
                    .init(time: "0:05", speaker: "B", text: "まず先週のアクションアイテムを確認しましょう。")
                ],
                summary: "週次ミーティングの開会宣言とアクションアイテム確認の呼びかけ。"
            )
        )) {
            TranscriptionFeature()
        }
    )
}
