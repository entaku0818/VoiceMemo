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

          if let requiredTab = nextStep.requiredTab {
            state.targetTab = requiredTab
            return .send(.delegate(.switchToTab(requiredTab)))
          }

          return .none

        case .previousStep:
          let previousStep = state.currentStep.previous()
          state.currentStep = previousStep

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
  case welcome      = "welcome"       // Step 1: 価値提案カード
  case tryRecording = "try_recording" // Step 2: 録音ボタン誘導（非ブロック）
  case complete     = "complete"      // Step 3: 自動トリガー（表示なし）

  var title: String {
    switch self {
    case .welcome:
      return "VoiLogへようこそ！"
    case .tryRecording:
      return String(localized: "録音してみよう")
    case .complete:
      return "チュートリアル完了"
    }
  }

  var message: String {
    switch self {
    case .welcome:
      return "会議・講義・アイデアを\nワンタップで録音保存。\n実際に試してみましょう！"
    case .tryRecording:
      return String(localized: "下の録音ボタンをタップしてください")
    case .complete:
      return "チュートリアル完了です！\nVoiLogをお楽しみください。"
    }
  }

  var requiredTab: Int? {
    switch self {
    case .welcome, .tryRecording, .complete:
      return 0  // 録音タブ
    }
  }

  var hasNext: Bool {
    self == .welcome
  }

  var hasPrevious: Bool {
    false
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
}

// MARK: - UserDefaults Keys
enum UserDefaultsKeys {
  static let tutorialCompleted = "tutorial_completed"
  static let firstLaunch = "first_launch"
  static let firstRecordingCompleted = "first_recording_completed"
}

// MARK: - Tutorial Overlay View
struct TutorialOverlayView: View {
  @Perception.Bindable var store: StoreOf<TutorialFeature>

  private func send(_ action: TutorialFeature.Action.View) {
    store.send(.view(action))
  }

  var body: some View {
    if store.currentStep == .tryRecording {
      // tryRecording: 非ブロックモード（背景タップ通過、ヒントカードのみ）
      ZStack(alignment: .top) {
        Color.black.opacity(0.3)
          .edgesIgnoringSafeArea(.all)
          .allowsHitTesting(false)

        VStack(spacing: 8) {
          Text("⏺ \(String(localized: "録音してみよう"))")
            .font(.headline)
          Text(String(localized: "下の録音ボタンをタップしてください"))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
          Button("スキップ") { send(.confirmSkip) }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 60)
      }
      .alert(String(localized: "チュートリアルをスキップ"), isPresented: $store.showSkipConfirmation) {
        Button("スキップ", role: .destructive) { send(.confirmSkip) }
        Button("キャンセル", role: .cancel) { send(.cancelSkip) }
      } message: {
        Text(String(localized: "チュートリアルをスキップしますか？\n後で設定画面から再度確認できます。"))
      }
    } else {
      // welcome: フルスクリーンオーバーレイカード
      ZStack {
        Color.black.opacity(0.7)
          .edgesIgnoringSafeArea(.all)
          .onTapGesture {
            if store.currentStep.hasNext {
              send(.nextStep)
            } else {
              send(.complete)
            }
          }

        VStack(spacing: 0) {
          Spacer()

          VStack(spacing: 20) {
            progressView

            Text(store.currentStep.title)
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(.primary)
              .multilineTextAlignment(.center)

            Text(store.currentStep.message)
              .font(.body)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .lineSpacing(4)

            HStack(spacing: 16) {
              Spacer()

              Button("スキップ") { send(.skip) }
                .foregroundColor(.secondary)

              Button(store.currentStep.hasNext ? "録音してみる →" : "完了") {
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
      .alert(String(localized: "チュートリアルをスキップ"), isPresented: $store.showSkipConfirmation) {
        Button("スキップ", role: .destructive) { send(.confirmSkip) }
        Button("キャンセル", role: .cancel) { send(.cancelSkip) }
      } message: {
        Text(String(localized: "チュートリアルをスキップしますか？\n後で設定画面から再度確認できます。"))
      }
    }
  }

  private var progressView: some View {
    let visibleSteps = 2 // welcome と tryRecording の2ステップを表示
    let currentIndex: Int = {
      switch store.currentStep {
      case .welcome: return 0
      case .tryRecording: return 1
      case .complete: return 2
      }
    }()
    let progress = Double(currentIndex + 1) / Double(visibleSteps)

    return VStack(spacing: 8) {
      HStack {
        Text(String(format: NSLocalizedString("ステップ %lld / %lld", comment: ""), currentIndex + 1, visibleSteps))
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
      }

      ProgressView(value: min(progress, 1.0))
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
