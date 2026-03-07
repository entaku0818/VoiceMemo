import SwiftUI
import ComposableArchitecture
import FirebaseFunctions

// MARK: - Feedback Category

enum FeedbackCategory: String, CaseIterable, Equatable {
    case bug = "バグ報告"
    case feature = "機能要望"
    case other = "その他"
}

// MARK: - Feedback Feature

@Reducer
struct FeedbackFeature {
    @ObservableState
    struct State: Equatable {
        var category: FeedbackCategory = .other
        var message: String = ""
        var isSending = false
        var showSuccessAlert = false
        var showErrorAlert = false
        var errorMessage: String = ""

        var canSubmit: Bool {
            !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case view(View)
        case sendCompleted(Result<Void, FeedbackError>)

        enum View: Equatable {
            case submitTapped
            case dismissSuccessAlert
            case dismissErrorAlert
        }
    }

    enum FeedbackError: Error, Equatable {
        case sendFailed(String)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .view(.submitTapped):
                guard state.canSubmit else { return .none }
                state.isSending = true

                let category = state.category.rawValue
                let message = state.message

                return .run { send in
                    do {
                        try await sendFeedback(category: category, message: message)
                        await send(.sendCompleted(.success(())))
                    } catch {
                        await send(.sendCompleted(.failure(.sendFailed(error.localizedDescription))))
                    }
                }

            case .sendCompleted(.success):
                state.isSending = false
                state.message = ""
                state.category = .other
                state.showSuccessAlert = true
                return .none

            case let .sendCompleted(.failure(error)):
                state.isSending = false
                if case let .sendFailed(msg) = error {
                    state.errorMessage = msg
                }
                state.showErrorAlert = true
                return .none

            case .view(.dismissSuccessAlert):
                state.showSuccessAlert = false
                return .none

            case .view(.dismissErrorAlert):
                state.showErrorAlert = false
                return .none
            }
        }
    }
}

private func sendFeedback(category: String, message: String) async throws {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let osVersion = UIDevice.current.systemVersion
    let deviceModel = UIDevice.current.model

    let functions = Functions.functions(region: "asia-northeast1")
    let data: [String: Any] = [
        "category": category,
        "message": message,
        "appVersion": appVersion,
        "buildNumber": buildNumber,
        "osVersion": osVersion,
        "deviceModel": deviceModel,
    ]

    _ = try await functions.httpsCallable("submitFeedback").call(data)
}

// MARK: - View

struct FeedbackFormView: View {
    @Perception.Bindable var store: StoreOf<FeedbackFeature>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $store.category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("内容") {
                    TextEditor(text: $store.message)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("フィードバック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if store.isSending {
                        ProgressView()
                    } else {
                        Button("送信") {
                            store.send(.view(.submitTapped))
                        }
                        .disabled(!store.canSubmit)
                    }
                }
            }
            .alert("送信しました", isPresented: $store.showSuccessAlert) {
                Button("OK") {
                    store.send(.view(.dismissSuccessAlert))
                    dismiss()
                }
            } message: {
                Text("フィードバックありがとうございます。")
            }
            .alert("送信に失敗しました", isPresented: $store.showErrorAlert) {
                Button("OK") { store.send(.view(.dismissErrorAlert)) }
            } message: {
                Text(store.errorMessage)
            }
        }
    }
}

#Preview {
    FeedbackFormView(
        store: Store(initialState: FeedbackFeature.State()) {
            FeedbackFeature()
        }
    )
}
