import SwiftUI
import ComposableArchitecture

struct CombinedTranscriptionView: View {
    let memo: PlaybackFeature.VoiceMemo
    let onDismiss: () -> Void
    var onAISaved: ((String) -> Void)?

    @State private var showAITranscriptionSheet = false
    @State private var currentAIText: String

    init(
        memo: PlaybackFeature.VoiceMemo,
        onDismiss: @escaping () -> Void,
        onAISaved: ((String) -> Void)? = nil
    ) {
        self.memo = memo
        self.onDismiss = onDismiss
        self.onAISaved = onAISaved
        self._currentAIText = State(initialValue: memo.aiTranscriptionText)
    }

    private var appleTranscription: TimestampedTranscription? {
        guard let json = memo.timestampedText else { return nil }
        return TimestampedTranscription.fromJSON(json)
    }

    private var hasAppleTranscription: Bool {
        appleTranscription != nil || !memo.text.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appleSection
                    Divider()
                    aiSection
                }
                .padding(.vertical, 8)
            }
            .navigationTitle(String(localized: "文字起こし"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !exportText().isEmpty {
                        Button {
                            // share full combined text
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAITranscriptionSheet) {
                TranscriptionView(
                    store: Store(
                        initialState: TranscriptionFeature.State(
                            audioURL: memo.url,
                            status: currentAIText.isEmpty ? .idle : .idle
                        )
                    ) {
                        TranscriptionFeature()
                    },
                    onSaved: { text in
                        currentAIText = text
                        onAISaved?(text)
                    },
                    onDismiss: { showAITranscriptionSheet = false }
                )
            }
        }
    }

    // MARK: - Apple section

    private var appleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                String(localized: "Apple 文字起こし"),
                icon: "text.bubble.fill",
                color: .blue
            )
            if let transcription = appleTranscription {
                if transcription.segments.isEmpty {
                    selectableText(transcription.fullText)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(transcription.segments.enumerated()), id: \.offset) { index, seg in
                            HStack(alignment: .top, spacing: 12) {
                                Text(formattedTime(seg.timestamp))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.blue)
                                    .frame(width: 44, alignment: .leading)
                                    .padding(.top, 2)
                                Text(seg.text)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                            if index < transcription.segments.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }
            } else if !memo.text.isEmpty {
                selectableText(memo.text)
            } else {
                emptyPlaceholder(String(localized: "Apple 文字起こしデータがありません"))
            }
        }
    }

    // MARK: - AI section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader(
                    String(localized: "AI 文字起こし"),
                    icon: "waveform.and.mic",
                    color: .purple
                )
                Spacer()
                Button {
                    showAITranscriptionSheet = true
                } label: {
                    Label(
                        currentAIText.isEmpty
                            ? String(localized: "開始")
                            : String(localized: "再実行"),
                        systemImage: currentAIText.isEmpty ? "play.fill" : "arrow.clockwise"
                    )
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            if currentAIText.isEmpty {
                emptyPlaceholder(String(localized: "AI文字起こしがまだ実行されていません"))
            } else {
                selectableText(currentAIText)
            }
        }
    }

    // MARK: - Helper views

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal)
    }

    private func selectableText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 4)
    }

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
            .padding(.horizontal)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func exportText() -> String {
        var parts: [String] = []
        if !memo.text.isEmpty { parts.append(memo.text) }
        if !currentAIText.isEmpty { parts.append(currentAIText) }
        return parts.joined(separator: "\n\n---\n\n")
    }
}

#Preview {
    CombinedTranscriptionView(
        memo: PlaybackFeature.VoiceMemo(
            title: "Meeting Notes",
            date: Date(),
            duration: 180,
            url: URL(fileURLWithPath: "/tmp/test.m4a"),
            text: "Apple transcription text here.",
            aiTranscriptionText: "AI transcription result with more detail and accuracy."
        ),
        onDismiss: {}
    )
}
