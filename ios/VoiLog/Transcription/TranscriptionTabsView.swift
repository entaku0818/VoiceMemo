import SwiftUI
import ComposableArchitecture

/// Apple / AI の2タブを持つ共通文字起こしコンテンツ。
/// VoiceMemoDetailView と CombinedTranscriptionView の両方で使用。
struct TranscriptionTabsView: View {
    let memo: PlaybackFeature.VoiceMemo
    var onAISaved: ((String) -> Void)?

    @State private var selectedTab = 0
    @State private var transcriptionStore: StoreOf<TranscriptionFeature>

    init(memo: PlaybackFeature.VoiceMemo, onAISaved: ((String) -> Void)? = nil) {
        self.memo = memo
        self.onAISaved = onAISaved
        self._transcriptionStore = State(wrappedValue: Store(
            initialState: TranscriptionFeature.State(
                audioURL: memo.url,
                savedText: memo.aiTranscriptionText.isEmpty ? nil : memo.aiTranscriptionText
            )
        ) { TranscriptionFeature() })
    }

    private var appleTranscription: TimestampedTranscription? {
        guard let json = memo.timestampedText else { return nil }
        return TimestampedTranscription.fromJSON(json)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Label(String(localized: "Apple", table: "Transcription"), systemImage: "text.bubble.fill").tag(0)
                Label(String(localized: "AI", table: "Transcription"), systemImage: "waveform.and.mic").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            TabView(selection: $selectedTab) {
                appleTab.tag(0)
                AITranscriptionTab(store: transcriptionStore, onSaved: { text in
                    onAISaved?(text)
                })
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
    }

    // MARK: - Apple tab

    private var appleTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let transcription = appleTranscription {
                    if transcription.segments.isEmpty {
                        selectableBody(transcription.fullText)
                    } else {
                        ForEach(Array(transcription.segments.enumerated()), id: \.offset) { index, seg in
                            timestampRow(time: formattedTime(seg.timestamp), text: seg.text, color: .blue)
                            if index < transcription.segments.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                } else if !memo.text.isEmpty {
                    selectableBody(memo.text)
                } else {
                    emptyState(
                        icon: "text.bubble",
                        message: String(localized: "Apple 文字起こしデータがありません", table: "Transcription")
                    )
                }
            }
        }
    }

    // MARK: - Shared sub-views

    func selectableBody(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }

    func timestampRow(time: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(time)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 2)
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - AI tab (inline, no modal)

struct AITranscriptionTab: View {
    @Perception.Bindable var store: StoreOf<TranscriptionFeature>
    var onSaved: ((String) -> Void)?

    var body: some View {
        WithPerceptionTracking {
            switch store.status {
            case .idle:
                idleView
            case .uploading:
                progressView(label: String(localized: "音声をアップロード中...", table: "Transcription"), hint: nil)
            case .transcribing:
                progressView(
                    label: String(localized: "AIが文字起こし中...", table: "Transcription"),
                    hint: String(localized: "通常2〜5分かかります。このまましばらくお待ちください。", table: "Transcription")
                )
            case let .failed(msg):
                failedView(message: msg)
            case .done:
                if let result = store.result {
                    resultView(result)
                }
            }
        }
    }

    // MARK: Idle

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                if let savedText = store.savedText, !savedText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(String(localized: "前回の結果", table: "Transcription"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                store.send(.startTapped)
                            } label: {
                                Label(String(localized: "再実行", table: "Transcription"), systemImage: "arrow.clockwise")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        Text(savedText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                } else {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                    Text(String(localized: "AI文字起こしがまだ実行されていません", table: "Transcription"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                languagePicker

                Button(String(localized: "文字起こしを開始", table: "Transcription")) {
                    store.send(.startTapped)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }

    private var languagePicker: some View {
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
    }

    // MARK: Progress

    private func progressView(label: String, hint: String?) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            VStack(spacing: 6) {
                Text(label).font(.subheadline.bold())
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text(String(localized: "文字起こしに失敗しました", table: "Transcription"))
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            Button(String(localized: "再試行", table: "Transcription")) { store.send(.startTapped) }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
            Spacer()
        }
        .padding()
    }

    // MARK: Result

    private func resultView(_ result: TranscriptionFeature.State.Result) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !result.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").foregroundStyle(.purple)
                            Text(String(localized: "要約", table: "Transcription"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.purple)
                        }
                        Text(result.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.06))
                    Divider()
                }

                if result.segments.isEmpty {
                    Text(result.transcription)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                } else {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, seg in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(seg.time)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.purple)
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

                Button(String(localized: "保存")) {
                    store.send(.delegate(.transcriptionSaved(text: result.transcription)))
                    onSaved?(result.transcription)
                    store.send(.reset)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

}
