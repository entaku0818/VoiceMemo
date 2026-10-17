#if DEBUG
import SwiftUI
import ComposableArchitecture

/// Exercises the production tabs/sheets with synthetic content and no external services.
/// Available only in Debug builds when explicitly launched by the UI test suite.
enum AIConsentUITestFixture {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--ai-consent-ui-test")
    }

    @MainActor
    static func makeView() -> some View {
        let consent = LockIsolated<[String: Bool]>(["ai_data_sharing_consent_v1": true])
        let memo = PlaybackFeature.VoiceMemo(
            title: "Consent test recording",
            date: Date(), duration: 10,
            url: URL(fileURLWithPath: "/synthetic-consent-test.m4a"),
            text: "Synthetic meeting transcript. Prepare the agenda."
        )
        return withDependencies {
            $0.userDefaults.bool = { key in consent.value[key] ?? false }
            $0.userDefaults.set = { value, key in consent.withValue { $0[key] = value } }
            $0.firebaseAuthClient.currentUserIDToken = { _ in "test-token" }
            $0.transcriptionClient = TranscriptionClient(
                uploadURL: { _, _ in .init(uploadUrl: "https://invalid.test", fileId: "test", blobName: "test") },
                transcribe: { _, _, _ in .init(transcription: "CONSENT_AUDIO_SUCCESS", segments: nil, summary: "Test") },
                uploadAudio: { _, _, _ in },
                generateMinutes: { _, _, _ in .init(summary: "CONSENT_MINUTES_SUCCESS", todos: []) }
            )
            $0.meetingMinutesClient = MeetingMinutesClient(
                generate: { _ in .init(summary: "CONSENT_MINUTES_SUCCESS", todos: []) },
                usesCloud: { true }
            )
        } operation: {
            NavigationStack {
                TranscriptionTabsView(memo: memo, hasPurchasedPremium: true)
                    .navigationTitle(memo.title)
            }
        }
    }
}
#endif
