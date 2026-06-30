import SwiftUI
import ComposableArchitecture

/// iOS 26 限定の議事録生成ビュー。TranscriptionTabsView の3タブ目として表示。
@available(iOS 26, *)
struct MeetingMinutesView: View {
    @SwiftUI.Bindable var store: StoreOf<MeetingMinutesFeature>
    let hasPurchasedPremium: Bool
    var onSaved: ((String) -> Void)?

    var body: some View {
        WithPerceptionTracking {
            if !hasPurchasedPremium {
                premiumPromptView
            } else {
                switch store.status {
                case .idle:
                    idleView
                case .generating:
                    generatingView
                case let .done(result):
                    resultView(result)
                case let .failed(message):
                    failedView(message: message)
                }
            }
        }
    }

    // MARK: - Premium prompt

    private var premiumPromptView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text(String(localized: "AI議事録はプレミアム機能です", table: "MeetingMinutes"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(String(localized: "サブスクリプションに登録すると、文字起こし結果から要約とTODOを自動生成できます。", table: "MeetingMinutes"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Idle (generate button or saved result)

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                if let saved = store.savedMinutes {
                    savedPreview(saved)
                } else {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                    Text(String(localized: "文字起こし結果から議事録を自動生成します", table: "MeetingMinutes"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(store.savedMinutes == nil
                    ? String(localized: "議事録を生成", table: "MeetingMinutes")
                    : String(localized: "再生成", table: "MeetingMinutes")
                ) {
                    store.send(.view(.generateTapped))
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }

    private func savedPreview(_ result: MeetingMinutesResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text(String(localized: "前回の議事録", table: "MeetingMinutes"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            summarySection(result.summary)
            if !result.todos.isEmpty {
                todoSection(result.todos)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            VStack(spacing: 6) {
                Text(String(localized: "Apple Intelligence で議事録を生成中...", table: "MeetingMinutes"))
                    .font(.subheadline.bold())
                Text(String(localized: "オンデバイスで処理しています。しばらくお待ちください。", table: "MeetingMinutes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Result

    private func resultView(_ result: MeetingMinutesResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summaryCard(result.summary)

                if !result.todos.isEmpty {
                    Divider()
                    todoCard(result.todos)
                }

                Button(String(localized: "保存", table: "MeetingMinutes")) {
                    store.send(.view(.saveTapped))
                    if case let .done(r) = store.status {
                        onSaved?(formatForDisplay(r))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private func summaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text(String(localized: "要約", table: "MeetingMinutes"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
            }
            summarySection(text)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.06))
    }

    private func todoCard(_ todos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist").foregroundStyle(.purple)
                Text(String(localized: "TODO", table: "MeetingMinutes"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
            }
            todoSection(todos)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summarySection(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todoSection(_ todos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .padding(.top, 3)
                    Text(todo)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text(String(localized: "議事録の生成に失敗しました", table: "MeetingMinutes"))
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            Button(String(localized: "再試行", table: "MeetingMinutes")) {
                store.send(.view(.generateTapped))
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }

    private func formatForDisplay(_ result: MeetingMinutesResult) -> String {
        var lines = ["# 要約", result.summary]
        if !result.todos.isEmpty {
            lines += ["", "# TODO"]
            lines += result.todos.map { "- \($0)" }
        }
        return lines.joined(separator: "\n")
    }
}
