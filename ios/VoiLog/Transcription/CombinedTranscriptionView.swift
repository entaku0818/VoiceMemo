import SwiftUI

/// メモ行バッジから開く独立した文字起こし画面。
/// NavigationStack を持ち、TranscriptionTabsView をラップする。
struct CombinedTranscriptionView: View {
    let memo: PlaybackFeature.VoiceMemo
    let onDismiss: () -> Void
    var onAISaved: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            TranscriptionTabsView(memo: memo, onAISaved: onAISaved)
                .navigationTitle(String(localized: "文字起こし"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark").foregroundStyle(.secondary)
                        }
                    }
                }
        }
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
