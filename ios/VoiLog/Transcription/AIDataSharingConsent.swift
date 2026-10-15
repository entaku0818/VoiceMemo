import SwiftUI

/// 外部の AI（Google Gemini API）へ音声・文字起こしテキストを送る前の同意（App Review Guideline 5.1.2(i)）。
///
/// AI文字起こし（音声を送る）と、Apple Intelligence が使えない端末での議事録作成（テキストを送る）の
/// どちらも同じ送信先なので、同意は1つにまとめ、一度同意したら次からは聞かない。
enum AIDataSharingConsent {
    static let userDefaultsKey = "ai_data_sharing_consent_v1"
    static let privacyPolicyURL = URL(string: "https://voilog.web.app/privacy_policy.html")!

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

                    Text(String(localized: "氏名・メールアドレス・広告IDなどは送信しません。送信したデータは文字起こし・議事録の作成のためだけに使います。", table: "Transcription"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(String(localized: "送信しない", table: "Transcription")) {
                    onDecline()
                }
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
            String(localized: "AI文字起こしでは、この録音の音声を当社のサーバー経由で Google の AI（Gemini API）に送信して、文字に起こします。", table: "Transcription")
        case .minutes:
            String(localized: "この端末では Apple Intelligence が使えないため、議事録は文字起こしのテキストを当社のサーバー経由で Google の AI（Gemini API）に送信して作成します。", table: "Transcription")
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
