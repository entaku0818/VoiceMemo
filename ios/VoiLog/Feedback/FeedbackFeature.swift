import SwiftUI
import FirebaseFunctions

// MARK: - Feedback Category

enum FeedbackCategory: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case other = "other"

    var displayName: String {
        switch self {
        case .bug: return String(localized: "バグ報告")
        case .feature: return String(localized: "機能要望")
        case .other: return String(localized: "その他")
        }
    }
}

// MARK: - View

struct FeedbackFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var category: FeedbackCategory = .feature
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "カテゴリ")) {
                    Picker(String(localized: "カテゴリ"), selection: $category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(String(localized: "内容")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }
                Section(String(localized: "メールアドレス（任意）")) {
                    TextField(String(localized: "返信先メールアドレス"), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(String(localized: "フィードバック"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button(String(localized: "送信")) { submit() }
                            .disabled(!canSubmit)
                    }
                }
            }
            .alert(String(localized: "送信しました"), isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(String(localized: "フィードバックありがとうございます。"))
            }
            .alert(String(localized: "送信に失敗しました"), isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submit() {
        isSending = true
        Task {
            do {
                try await sendFeedback(category: category.rawValue, message: message, email: email)
                isSending = false
                showSuccessAlert = true
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

private func sendFeedback(category: String, message: String, email: String) async throws {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let osVersion = UIDevice.current.systemVersion
    let deviceModel = UIDevice.current.model

    let functions = Functions.functions(region: "asia-northeast1")
    var data: [String: Any] = [
        "category": category,
        "message": message,
        "appVersion": appVersion,
        "buildNumber": buildNumber,
        "osVersion": osVersion,
        "deviceModel": deviceModel
    ]
    data["email"] = email
    _ = try await functions.httpsCallable("submitFeedback").call(data)
}

#Preview {
    FeedbackFormView()
}
