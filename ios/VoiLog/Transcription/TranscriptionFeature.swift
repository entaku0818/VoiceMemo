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
        case .notAuthenticated:
            return String(localized: "接続に失敗しました。ネットワークを確認してください。", table: "Transcription")
        case .uploadFailed:
            return String(localized: "音声ファイルのアップロードに失敗しました。ネットワークを確認してください。", table: "Transcription")
        case let .serverError(code, _):
            if code == 504 || code == 503 {
                return String(localized: "サーバーが混雑しています。しばらく待ってから再試行してください。", table: "Transcription")
            } else if code == 429 {
                return String(localized: "リクエストが多すぎます。しばらく待ってから再試行してください。", table: "Transcription")
            } else if code >= 500 {
                return String(localized: "サーバーエラーが発生しました。再試行してください。", table: "Transcription")
            }
            return String(localized: "エラーが発生しました (コード: \(code))。再試行してください。", table: "Transcription")
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
            req.timeoutInterval = 600
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
        var selectedLanguage: String
        var savedText: String?

        init(audioURL: URL, status: Status = .idle, result: Result? = nil, savedText: String? = nil) {
            self.audioURL = audioURL
            self.status = status
            self.result = result
            self.savedText = savedText
            self.selectedLanguage = Self.detectLanguage()
        }

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

        static func detectLanguage() -> String {
            let code = Locale.preferredLanguages.first ?? "en"
            if code.hasPrefix("ja") { return "ja" }
            if code.hasPrefix("zh") { return "zh" }
            if code.hasPrefix("ko") { return "ko" }
            return "en"
        }
    }

    enum Action {
        case startTapped
        case languageChanged(String)
        case reset
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
                let lang = state.selectedLanguage
                return .run { send in
                    do {
                        let idToken = try await firebaseAuth.currentUserIDToken()
                        let uploadResp = try await client.uploadURL(idToken, ext)
                        await send(._uploadCompleted(blobName: uploadResp.blobName, uploadURL: uploadResp.uploadUrl))
                        try await client.uploadAudio(audioURL, uploadResp.uploadUrl, mimeType)
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

            case let .languageChanged(lang):
                state.selectedLanguage = lang
                return .none

            case .reset:
                state.status = .idle
                state.result = nil
                return .none

            case ._uploadCompleted:
                state.status = .transcribing
                return .none

            case let ._transcriptionCompleted(result):
                state.result = result
                state.status = .done
                state.savedText = result.transcription
                return .none

            case let ._failed(message):
                state.status = .failed(message)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View

struct TranscriptionView: View {
    @Perception.Bindable var store: StoreOf<TranscriptionFeature>
    var onSaved: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var showShareSheet = false
    @State private var shareText = ""

    var body: some View {
        NavigationStack {
            Group {
                if case .done = store.status, let result = store.result {
                    resultView(result)
                } else {
                    statusView
                }
            }
            .navigationTitle(String(localized: "文字起こし"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.status == .idle {
                        Button(String(localized: "開始", table: "Transcription")) { store.send(.startTapped) }
                            .fontWeight(.semibold)
                    } else if case .done = store.status, let result = store.result {
                        HStack(spacing: 16) {
                            Button {
                                shareText = result.transcription
                                showShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Button(String(localized: "保存")) {
                                store.send(.delegate(.transcriptionSaved(text: result.transcription)))
                                onSaved?(result.transcription)
                                onDismiss?()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }

    private var statusView: some View {
        VStack(spacing: 0) {
            Spacer()
            switch store.status {
            case .idle:
                VStack(spacing: 20) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                    Text(String(localized: "AIで文字起こし", table: "Transcription"))
                        .font(.title3.bold())
                    Text(String(localized: "音声ファイルをアップロードして\nAIが自動で書き起こします", table: "Transcription"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Language picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "言語", table: "Transcription"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker(String(localized: "言語", table: "Transcription"), selection: Binding(
                            get: { store.selectedLanguage },
                            set: { store.send(.languageChanged($0)) }
                        )) {
                            Text(String(localized: "日本語", table: "Transcription")).tag("ja")
                            Text("English").tag("en")
                            Text(String(localized: "中文", table: "Transcription")).tag("zh")
                            Text("한국어").tag("ko")
                            Text("Deutsch").tag("de")
                            Text("Français").tag("fr")
                            Text("Español").tag("es")
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 40)

                    Button(String(localized: "文字起こしを開始", table: "Transcription")) { store.send(.startTapped) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .padding()
            case .uploading:
                progressView(
                    label: String(localized: "音声をアップロード中...", table: "Transcription"),
                    hint: nil
                )
            case .transcribing:
                progressView(
                    label: String(localized: "AIが文字起こし中...", table: "Transcription"),
                    hint: String(localized: "通常2〜5分かかります。このまましばらくお待ちください。", table: "Transcription")
                )
            case let .failed(msg):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    VStack(spacing: 8) {
                        Text(String(localized: "文字起こしに失敗しました", table: "Transcription"))
                            .font(.headline)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                    }
                    Button(String(localized: "再試行", table: "Transcription")) { store.send(.startTapped) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .padding()
                .frame(maxWidth: .infinity)
            case .done:
                EmptyView()
            }
            Spacer()
        }
    }

    private func progressView(label: String, hint: String?) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)

            VStack(spacing: 6) {
                Text(label)
                    .font(.subheadline.bold())
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private func resultView(_ result: TranscriptionFeature.State.Result) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !result.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                            Text(String(localized: "要約", table: "Transcription"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                        }
                        Text(result.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.06))

                    Divider()
                }

                if result.segments.isEmpty {
                    Text(result.transcription)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, seg in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(seg.time)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.blue)
                                    .frame(width: 44, alignment: .leading)
                                if let speaker = seg.speaker, !speaker.isEmpty {
                                    Text(speaker)
                                        .font(.caption2.bold())
                                        .foregroundStyle(speakerColor(speaker))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(speakerColor(speaker).opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.top, 2)
                            Text(seg.text)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                        if index < result.segments.count - 1 {
                            Divider().padding(.leading, 68)
                        }
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
