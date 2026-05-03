import SwiftUI

struct AppleTranscriptionView: View {
    let memo: PlaybackFeature.VoiceMemo
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var shareText = ""

    private var transcription: TimestampedTranscription? {
        guard let json = memo.timestampedText else { return nil }
        return TimestampedTranscription.fromJSON(json)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let transcription {
                        if transcription.segments.isEmpty {
                            Text(transcription.fullText)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(Array(transcription.segments.enumerated()), id: \.offset) { index, seg in
                                Button {
                                    // 将来: タップでその位置から再生
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(formattedTime(seg.timestamp))
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.blue)
                                            .frame(width: 44, alignment: .leading)
                                            .padding(.top, 2)
                                        Text(seg.text)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if index < transcription.segments.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                    } else if !memo.text.isEmpty {
                        Text(memo.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "文字起こしデータがありません"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
            }
            .navigationTitle(String(localized: "文字起こし"))
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
                    Button {
                        shareText = exportText()
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(exportText().isEmpty)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func exportText() -> String {
        if let transcription {
            return transcription.formattedText
        }
        return memo.text
    }
}

#Preview {
    AppleTranscriptionView(
        memo: PlaybackFeature.VoiceMemo(
            title: "会議メモ",
            date: Date(),
            duration: 180,
            url: URL(fileURLWithPath: "/tmp/test.m4a"),
            text: "本日の会議を始めます。まず先週のアクションアイテムを確認しましょう。"
        ),
        onDismiss: {}
    )
}
