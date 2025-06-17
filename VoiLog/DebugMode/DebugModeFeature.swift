import SwiftUI
import ComposableArchitecture

// MARK: - Main App Feature
@Reducer
struct VoiceAppFeature {
  @ObservableState
  struct State: Equatable {
    var recordingFeature = RecordingFeature.State()
    var playbackFeature = PlaybackFeature.State()
    var selectedTab: Int = 0  // 0=録音, 1=再生
  }

  enum Action: ViewAction, BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case recordingFeature(RecordingFeature.Action)
    case playbackFeature(PlaybackFeature.Action)

    enum View {
      case onAppear
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    
    Scope(state: \.recordingFeature, action: \.recordingFeature) {
      RecordingFeature()
    }
    
    Scope(state: \.playbackFeature, action: \.playbackFeature) {
      PlaybackFeature()
    }
    
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          return .none
        }

      case .recordingFeature(.delegate(.recordingCompleted(let result))):
        // 録音完了時に再生タブに自動切り替え
        state.selectedTab = 1
        // 録音完了時に再生画面のデータを自動更新
        return .send(.playbackFeature(.view(.reloadData)))
        
      case .recordingFeature:
        return .none

      case .playbackFeature:
        return .none
      }
    }
  }
}

@ViewAction(for: VoiceAppFeature.self)
struct VoiceAppView: View {
  @Perception.Bindable var store: StoreOf<VoiceAppFeature>

  var body: some View {
    TabView(selection: $store.selectedTab) {
      // 録音タブ
      NavigationStack {
        RecordingView(
          store: store.scope(state: \.recordingFeature, action: \.recordingFeature)
        )
      }
      .tabItem {
        Image(systemName: "record.circle")
        Text("録音")
      }
      .tag(0)
      
      // 再生タブ
      NavigationStack {
        PlaybackView(
          store: store.scope(state: \.playbackFeature, action: \.playbackFeature)
        )
      }
      .tabItem {
        Image(systemName: "play.circle")
        Text("再生")
      }
      .tag(1)
    }
    .onAppear {
      send(.onAppear)
                      }
  }
}

// MARK: - App Entry Point
struct VoiceAppEntryView: View {
  var body: some View {
    VoiceAppView(
      store: Store(initialState: VoiceAppFeature.State()) {
        VoiceAppFeature()
      }
    )
  }
}

#Preview {
  VoiceAppView(
    store: Store(initialState: VoiceAppFeature.State()) {
      VoiceAppFeature()
    }
  )
} 