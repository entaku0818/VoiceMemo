import SwiftUI

/// メモ行バッジから開く独立した文字起こし画面。
/// NavigationStack を持ち、TranscriptionTabsView をラップする。
struct CombinedTranscriptionView: View {
    let memo: PlaybackFeature.VoiceMemo
    let hasPurchasedPremium: Bool
    let onDismiss: () -> Void
    var onAISaved: ((String) -> Void)?
    var onMeetingMinutesSaved: ((String) -> Void)?

    init(
        memo: PlaybackFeature.VoiceMemo,
        hasPurchasedPremium: Bool = false,
        onDismiss: @escaping () -> Void,
        onAISaved: ((String) -> Void)? = nil,
        onMeetingMinutesSaved: ((String) -> Void)? = nil
    ) {
        self.memo = memo
        self.hasPurchasedPremium = hasPurchasedPremium
        self.onDismiss = onDismiss
        self.onAISaved = onAISaved
        self.onMeetingMinutesSaved = onMeetingMinutesSaved
    }

    var body: some View {
        NavigationStack {
            TranscriptionTabsView(
                memo: memo,
                hasPurchasedPremium: hasPurchasedPremium,
                onAISaved: onAISaved,
                onMeetingMinutesSaved: onMeetingMinutesSaved
            )
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
