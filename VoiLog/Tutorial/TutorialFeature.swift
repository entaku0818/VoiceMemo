import SwiftUI
import ComposableArchitecture
import Foundation

// MARK: - Tutorial Feature
@Reducer
struct TutorialFeature {
  @ObservableState
  struct State: Equatable {
    var isActive = false
    var currentStep: TutorialStep = .welcome
    var isCompleted = false
    var targetTab: Int = 0
    var highlightRect: CGRect = .zero
    var showSkipConfirmation = false
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case delegate(DelegateAction)

    enum View {
      case start
      case nextStep
      case previousStep
      case skip
      case complete
      case setHighlightRect(CGRect)
      case confirmSkip
      case cancelSkip
    }

    enum DelegateAction: Equatable {
      case tutorialCompleted
      case switchToTab(Int)
    }
  }

  @Dependency(\.userDefaults) var userDefaultsClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .start:
          state.isActive = true
          state.currentStep = .welcome
          state.isCompleted = false
          return .none

        case .nextStep:
          let nextStep = state.currentStep.next()
          state.currentStep = nextStep

          // ステップに応じてタブ切り替えが必要かチェック
          if let requiredTab = nextStep.requiredTab {
            state.targetTab = requiredTab
            return .send(.delegate(.switchToTab(requiredTab)))
          }

          return .none

        case .previousStep:
          let previousStep = state.currentStep.previous()
          state.currentStep = previousStep

          // ステップに応じてタブ切り替えが必要かチェック
          if let requiredTab = previousStep.requiredTab {
            state.targetTab = requiredTab
            return .send(.delegate(.switchToTab(requiredTab)))
          }

          return .none

        case .skip:
          state.showSkipConfirmation = true
          return .none

        case .confirmSkip:
          state.showSkipConfirmation = false
          return .send(.view(.complete))

        case .cancelSkip:
          state.showSkipConfirmation = false
          return .none

        case .complete:
          state.isActive = false
          state.isCompleted = true

          // 完了状態を永続化
          userDefaultsClient.set(true, UserDefaultsKeys.tutorialCompleted)

          return .send(.delegate(.tutorialCompleted))

        case let .setHighlightRect(rect):
          state.highlightRect = rect
          return .none
        }

      case .delegate:
        return .none
      }
    }
  }
}

// MARK: - Tutorial Steps
enum TutorialStep: String, CaseIterable, Equatable {
  case welcome = "welcome"
  case recordingBasics = "recording_basics"
  case recordingStart = "recording_start"
  case playbackTab = "playback_tab"
  case playbackList = "playback_list"
  case audioEditing = "audio_editing"
  case cloudSync = "cloud_sync"
  case complete = "complete"

  var title: String {
    switch self {
    case .welcome:
      return "VoiLogへようこそ！"
    case .recordingBasics:
      return "録音機能"
    case .recordingStart:
      return "録音を開始"
    case .playbackTab:
      return "再生機能"
    case .playbackList:
      return "録音ファイル一覧"
    case .audioEditing:
      return "音声編集"
    case .cloudSync:
      return "クラウド同期"
    case .complete:
      return "チュートリアル完了"
    }
  }

  var message: String {
    switch self {
    case .welcome:
      return "簡単で高機能な音声録音アプリです。\n主要機能をご案内します。"
    case .recordingBasics:
      return "録音タブでは音声を録音できます。\n高品質な録音が可能です。"
    case .recordingStart:
      return "中央の録音ボタンをタップして\n録音を開始・停止できます。"
    case .playbackTab:
      return "再生タブでは録音したファイルを\n管理・再生できます。"
    case .playbackList:
      return "録音ファイルの一覧表示、検索、\n並び替えができます。"
    case .audioEditing:
      return "波形アイコンから音声編集機能を\n利用できます。"
    case .cloudSync:
      return "iCloudと同期して他のデバイスでも\nファイルを利用できます。"
    case .complete:
      return "チュートリアル完了です！\nVoiLogをお楽しみください。"
    }
  }

  var requiredTab: Int? {
    switch self {
    case .welcome, .complete:
      return nil
    case .recordingBasics, .recordingStart:
      return 0  // 録音タブ
    case .playbackTab, .playbackList, .audioEditing, .cloudSync:
      return 1  // 再生タブ
    }
  }

  var hasNext: Bool {
    self != .complete
  }

  var hasPrevious: Bool {
    self != .welcome
  }

  func next() -> TutorialStep {
    let allCases = TutorialStep.allCases
    if let currentIndex = allCases.firstIndex(of: self),
       currentIndex + 1 < allCases.count {
      return allCases[currentIndex + 1]
    }
    return self
  }

  func previous() -> TutorialStep {
    let allCases = TutorialStep.allCases
    if let currentIndex = allCases.firstIndex(of: self),
       currentIndex > 0 {
      return allCases[currentIndex - 1]
    }
    return self
  }

  var highlightTarget: String? {
    switch self {
    case .recordingStart:
      return "record_button"
    case .playbackList:
      return "memo_list"
    case .audioEditing:
      return "edit_button"
    case .cloudSync:
      return "sync_button"
    default:
      return nil
    }
  }
}

// MARK: - UserDefaults Keys
enum UserDefaultsKeys {
  static let tutorialCompleted = "tutorial_completed"
  static let firstLaunch = "first_launch"
}

// MARK: - Tutorial Overlay View
struct TutorialOverlayView: View {
  @Perception.Bindable var store: StoreOf<TutorialFeature>

  private func send(_ action: TutorialFeature.Action.View) {
    store.send(.view(action))
  }

  var body: some View {
    ZStack {
      // 半透明背景
      Color.black.opacity(0.7)
        .edgesIgnoringSafeArea(.all)
        .onTapGesture {
          // 背景タップで次へ
          if store.currentStep.hasNext {
            send(.nextStep)
          } else {
            send(.complete)
          }
        }

      // メインコンテンツ
      VStack(spacing: 0) {
        Spacer()

        // チュートリアルカード
        VStack(spacing: 20) {
          // プログレス表示
          progressView

          // タイトル
          Text(store.currentStep.title)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)

          // メッセージ
          Text(store.currentStep.message)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)

          // ボタン
          HStack(spacing: 16) {
            // 戻るボタン
            if store.currentStep.hasPrevious {
              Button("戻る") {
                send(.previousStep)
              }
              .foregroundColor(.secondary)
            }

            Spacer()

            // スキップボタン
            Button("スキップ") {
              send(.skip)
            }
            .foregroundColor(.red)

            // 次へ/完了ボタン
            Button(store.currentStep.hasNext ? "次へ" : "完了") {
              if store.currentStep.hasNext {
                send(.nextStep)
              } else {
                send(.complete)
              }
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .cornerRadius(25)
          }
        }
        .padding(24)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)

        Spacer()
      }
    }
    .alert("チュートリアルをスキップ", isPresented: $store.showSkipConfirmation) {
      Button("スキップ", role: .destructive) {
        send(.confirmSkip)
      }
      Button("キャンセル", role: .cancel) {
        send(.cancelSkip)
      }
    } message: {
      Text("チュートリアルをスキップしますか？\n後で設定画面から再度確認できます。")
    }
  }

  private var progressView: some View {
    let allSteps = TutorialStep.allCases
    let currentIndex = allSteps.firstIndex(of: store.currentStep) ?? 0
    let progress = Double(currentIndex + 1) / Double(allSteps.count)

    return VStack(spacing: 8) {
      HStack {
        Text("ステップ \(currentIndex + 1) / \(allSteps.count)")
          .font(.caption)
          .foregroundColor(.secondary)

        Spacer()
      }

      ProgressView(value: progress)
        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
    }
  }
}

#Preview {
  TutorialOverlayView(
    store: Store(initialState: TutorialFeature.State(
      isActive: true,
      currentStep: .welcome
    )) {
      TutorialFeature()
    }
  )
}
