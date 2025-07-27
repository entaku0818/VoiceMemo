import SwiftUI
import ComposableArchitecture
import StoreKit
import MessageUI

@Reducer
struct FeedbackFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var showMailComposer = false
        var showReviewRequest = false
        var appUsageCount: Int = 0
        var lastReviewRequestDate: Date?
        var feedbackEmail = "support@voilog.app" // 適切なサポートメールアドレスに変更してください

        var canSendEmail: Bool {
            MFMailComposeViewController.canSendMail()
        }

        var shouldShowReviewPrompt: Bool {
            // アプリを10回以上使用し、前回のレビューリクエストから30日以上経過している場合
            guard appUsageCount >= 10 else { return false }

            if let lastRequestDate = lastReviewRequestDate {
                let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
                return daysSinceLastRequest >= 30
            }

            return true
        }
    }

    enum Action: ViewAction, Equatable {
        case view(View)
        case reviewRequestCompleted
        case incrementAppUsage

        enum View {
            case feedbackButtonTapped
            case reviewButtonTapped
            case mailComposerDismissed
            case onAppear
        }
    }

    @Dependency(\.date) var date

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .feedbackButtonTapped:
                    if state.canSendEmail {
                        state.showMailComposer = true
                    } else {
                        // メールが送信できない場合は、サポートページを開くなどの代替手段を提供
                        if let url = URL(string: "https://voilog.app/support") {
                            UIApplication.shared.open(url)
                        }
                    }
                    return .none

                case .reviewButtonTapped:
                    return .run { send in
                        // App Storeでのレビューをリクエスト
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            await MainActor.run {
                                SKStoreReviewController.requestReview(in: windowScene)
                            }
                        }
                        await send(.reviewRequestCompleted)
                    }

                case .mailComposerDismissed:
                    state.showMailComposer = false
                    return .none

                case .onAppear:
                    // UserDefaultsから値を読み込む
                    state.appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")
                    if let lastRequestDate = UserDefaults.standard.object(forKey: "lastReviewRequestDate") as? Date {
                        state.lastReviewRequestDate = lastRequestDate
                    }

                    // 自動レビューリクエストの判定
                    if state.shouldShowReviewPrompt {
                        state.showReviewRequest = true
                        return .send(.view(.reviewButtonTapped))
                    }
                    return .none
                }

            case .reviewRequestCompleted:
                state.lastReviewRequestDate = date.now
                // UserDefaultsに保存
                UserDefaults.standard.set(date.now, forKey: "lastReviewRequestDate")
                return .none

            case .incrementAppUsage:
                state.appUsageCount += 1
                UserDefaults.standard.set(state.appUsageCount, forKey: "appUsageCount")
                return .none
            }
        }
    }
}

// MARK: - View

struct FeedbackView: View {
    @Perception.Bindable var store: StoreOf<FeedbackFeature>

    var body: some View {
        VStack(spacing: 20) {
            // フィードバックセクション
            VStack(alignment: .leading, spacing: 12) {
                Label("フィードバック", systemImage: "envelope")
                    .font(.headline)

                Text("ご意見・ご要望をお聞かせください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: {
                    store.send(.view(.feedbackButtonTapped))
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("フィードバックを送信")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }

            // アプリ評価セクション
            VStack(alignment: .leading, spacing: 12) {
                Label("アプリを評価", systemImage: "star")
                    .font(.headline)

                Text("App Storeでレビューを書いてください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: {
                    store.send(.view(.reviewButtonTapped))
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("App Storeで評価する")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }

            Spacer()
            }
        .padding()
        .navigationTitle("フィードバック")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { store.showMailComposer },
            set: { _ in store.send(.view(.mailComposerDismissed)) }
        )) {
            MailComposerView(
                recipients: [store.feedbackEmail],
                subject: "VoiLogアプリのフィードバック",
                messageBody: createFeedbackEmailBody()
            )
        }
        .onAppear {
            store.send(.view(.onAppear))
        }
    }

    private func createFeedbackEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let osVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        return """


        ―――――――――――――――
        アプリ情報:
        バージョン: \(appVersion) (\(buildNumber))
        iOS: \(osVersion)
        デバイス: \(deviceModel)
        ―――――――――――――――
        """
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let messageBody: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(messageBody, isHTML: false)
        mailComposer.mailComposeDelegate = context.coordinator
        return mailComposer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}
