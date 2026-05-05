import SwiftUI
import ComposableArchitecture

struct CombinedTranscriptionView: View {
    let memo: PlaybackFeature.VoiceMemo
    let onDismiss: () -> Void
    var onAISaved: ((String) -> Void)?

    @State private var selectedTab = 0
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    Label(String(localized: "Apple"), systemImage: "text.bubble.fill")
                        .tag(0)
                    Label(String(localized: "AI"), systemImage: "waveform.and.mic")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Paged content
                TabView(selection: $selectedTab) {
                    appleTab.tag(0)
                    aiTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
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
                if selectedTab == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAITranscriptionSheet = true
                        } label: {
                            Label(
                                currentAIText.isEmpty
                                    ? String(localized: "開始")
                                    : String(localized: "再実行"),
                                systemImage: currentAIText.isEmpty ? "play.fill" : "arrow.clockwise"
                            )
                            .font(.subheadline.bold())
                        }
                    }
                }
            }
            .sheet(isPresented: $showAITranscriptionSheet) {
                TranscriptionView(
                    store: Store(
                        initialState: TranscriptionFeature.State(audioURL: memo.url)
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

    // MARK: - Apple tab

    private var appleTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let transcription = appleTranscription {
                    if transcription.segments.isEmpty {
                        Text(transcription.fullText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
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
                            .padding(.vertical, 12)

                            if index < transcription.segments.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                } else if !memo.text.isEmpty {
                    Text(memo.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    emptyPlaceholder(String(localized: "Apple 文字起こしデータがありません"))
                }
            }
        }
    }

    // MARK: - AI tab

    private var aiTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if currentAIText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 48))
                            .foregroundStyle(.purple)
                        Text(String(localized: "AI文字起こしがまだ実行されていません"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Button(String(localized: "文字起こしを開始")) {
                            showAITranscriptionSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    Text(currentAIText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(40)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
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
