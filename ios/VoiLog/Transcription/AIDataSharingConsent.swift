import SwiftUI
import ComposableArchitecture

/// 外部の AI（Google Gemini API）へ音声・文字起こしテキストを送る前の同意（App Review Guideline 5.1.2(i)）。
///
/// AI文字起こし（音声を送る）と、Apple Intelligence が使えない端末での議事録作成（テキストを送る）の
/// データと目的ごとに同意を分ける。説明不足の v1 同意は引き継がない。
enum AIDataSharingConsent {
    static let transcriptionKey = "ai_data_sharing_transcription_consent_v2"
    static let minutesKey = "ai_data_sharing_minutes_consent_v2"
    static let privacyPolicyURL = URL(string: "https://voilog.web.app/privacy_policy.html")!

    /// Defense in depth for callers outside a reducer (including Shortcuts).
    static func require(_ purpose: Purpose) throws {
        @Dependency(\.userDefaults)
        var userDefaults
        let key = purpose == .transcription ? transcriptionKey : minutesKey
        guard userDefaults.bool(key) else { throw TranscriptionError.consentRequired }
    }

    /// 何を送るか（画面の説明文が変わる）
    enum Purpose: Equatable {
        /// 録音の音声を送る
        case transcription
        /// 文字起こしのテキストを送る
        case minutes
    }
}

struct AIDataSharingConsentView: View {
    let purpose: AIDataSharingConsent.Purpose
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                    Text(String(localized: "外部のAIサービスへの送信について", table: "Transcription"))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    Text(purposeText)
                        .font(.body)

                    Text(String(localized: "録音には、話している人の声や会話の内容など、個人に関する情報が含まれることがあります。", table: "Transcription"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(
                        localized: "Personal information contained in the audio or text, including names, will also be sent. Google Firebase Authentication and our server use an anonymous ID for authentication and abuse prevention. We do not add advertising IDs to AI requests.",
                        table: "Transcription"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "Permission applies to future uses of this feature, including Shortcuts for audio transcription. You can reset AI sharing permissions in Settings.", table: "Transcription"))
                        .font(.subheadline)

                    Link(String(localized: "プライバシーポリシー", table: "Transcription"), destination: AIDataSharingConsent.privacyPolicyURL)
                        .font(.subheadline)
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    onAccept()
                } label: {
                    Text(String(localized: "同意して送信する", table: "Transcription"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("aiConsent.accept")
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(String(localized: "送信しない", table: "Transcription")) {
                    onDecline()
                }
                .accessibilityIdentifier("aiConsent.decline")
                .controlSize(.large)
            }
            .padding(24)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private var purposeText: String {
        switch purpose {
        case .transcription:
            String(localized: "The audio of this recording and the language setting will be sent through Google Cloud (our server and Cloud Storage) to Google’s Gemini API to create a transcript, distinguish speakers, and produce a summary.", table: "Transcription")
        case .minutes:
            String(localized: "To create cloud meeting minutes, the transcript text and language setting will be sent through our server on Google Cloud to Google’s Gemini API to produce a summary and to-do items. This action does not send the audio file.", table: "Transcription")
        }
    }
}

extension View {
    /// 外部の AI への送信の同意をシートで出す。スワイプでは閉じられず、閉じるのは「送信しない」と同じ扱い
    func aiDataSharingConsentSheet(
        isPresented: Bool,
        purpose: AIDataSharingConsent.Purpose,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: Binding(
            get: { isPresented },
            set: { if !$0 { onDecline() } }
        )) {
            AIDataSharingConsentView(purpose: purpose, onAccept: onAccept, onDecline: onDecline)
        }
    }
}

#Preview("Transcription") {
    AIDataSharingConsentView(purpose: .transcription, onAccept: {}, onDecline: {})
}

#Preview("Minutes") {
    AIDataSharingConsentView(purpose: .minutes, onAccept: {}, onDecline: {})
}
