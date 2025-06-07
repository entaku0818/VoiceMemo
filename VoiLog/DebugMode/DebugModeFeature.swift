import SwiftUI
import ComposableArchitecture

// MARK: - Debug Mode Configuration
#if DEBUG
enum AppMode: String, CaseIterable {
  case production = "統合画面（既存）"
  case development = "分離画面（新規）"
}

struct DebugSettings {
  @AppStorage("debug_app_mode") static var currentMode: AppMode = .production
  @AppStorage("debug_mode_enabled") static var isDebugModeEnabled: Bool = false
}
#endif

// MARK: - Main App Feature
@Reducer
struct VoiceAppFeature {
  @ObservableState
  struct State: Equatable {
    var currentMode: AppMode = .production
    var recordingFeature = RecordingFeature.State()
    var playbackFeature = PlaybackFeature.State()
    var showModeSelector: Bool = false
    
    #if DEBUG
    var isDebugModeEnabled: Bool = DebugSettings.isDebugModeEnabled
    #endif
  }

  enum Action: ViewAction, BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case recordingFeature(RecordingFeature.Action)
    case playbackFeature(PlaybackFeature.Action)
    
    #if DEBUG
    case setAppMode(AppMode)
    case toggleDebugMode
    #endif

    enum View {
      case onAppear
      case showModeSelector(Bool)
      case navigateToPlayback
      case navigateToRecording
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
          #if DEBUG
          state.currentMode = DebugSettings.currentMode
          state.isDebugModeEnabled = DebugSettings.isDebugModeEnabled
          #endif
          return .none
          
        case let .showModeSelector(show):
          state.showModeSelector = show
          return .none
          
        case .navigateToPlayback:
          return .none
          
        case .navigateToRecording:
          return .none
        }

      case .recordingFeature(.delegate(.recordingCompleted(let result))):
        // 録音完了時に再生画面のデータを更新
        let newMemo = PlaybackFeature.VoiceMemo(
          id: UUID(),
          title: result.title,
          date: result.date,
          duration: result.duration,
          url: result.url
        )
        state.playbackFeature.voiceMemos.insert(newMemo, at: 0)
        return .none
        
      case .recordingFeature:
        return .none

      case .playbackFeature:
        return .none

      #if DEBUG
      case let .setAppMode(mode):
        state.currentMode = mode
        DebugSettings.currentMode = mode
        return .none
        
      case .toggleDebugMode:
        state.isDebugModeEnabled.toggle()
        DebugSettings.isDebugModeEnabled = state.isDebugModeEnabled
        return .none
      #endif
      }
    }
  }
}

@ViewAction(for: VoiceAppFeature.self)
struct VoiceAppView: View {
  @Perception.Bindable var store: StoreOf<VoiceAppFeature>

  var body: some View {
    Group {
      #if DEBUG
      if store.isDebugModeEnabled && store.currentMode == .development {
        developmentModeView
      } else {
        productionModeView
      }
      #else
      productionModeView
      #endif
    }
    .onAppear {
      send(.onAppear)
    }
    #if DEBUG
    .sheet(isPresented: $store.showModeSelector) {
      debugModeSelector
    }
    #endif
  }
  
  // MARK: - Production Mode (既存の統合画面)
  private var productionModeView: some View {
    Text("既存の統合画面がここに表示されます")
      .navigationTitle("シンプル録音")
      .toolbar {
        #if DEBUG
        ToolbarItem(placement: .navigationBarLeading) {
          if store.isDebugModeEnabled {
            Button("デバッグ") {
              send(.showModeSelector(true))
            }
          }
        }
        #endif
      }
  }
  
  // MARK: - Development Mode (新しい分離画面)
  private var developmentModeView: some View {
    TabView {
      // 録音タブ
      NavigationStack {
        RecordingView(
          store: store.scope(state: \.recordingFeature, action: \.recordingFeature)
        )
        .toolbar {
          #if DEBUG
          ToolbarItem(placement: .navigationBarLeading) {
            Button("デバッグ") {
              send(.showModeSelector(true))
            }
          }
          #endif
        }
      }
      .tabItem {
        Image(systemName: "record.circle")
        Text("録音")
      }
      
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
    }
  }
  
  #if DEBUG
  // MARK: - Debug Mode Selector
  private var debugModeSelector: some View {
    NavigationStack {
      VStack(spacing: 24) {
        VStack(spacing: 16) {
          Text("デバッグモード設定")
            .font(.title2)
            .fontWeight(.bold)
          
          Text("開発中の新機能をテストできます")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        
        VStack(spacing: 16) {
          // デバッグモード有効/無効
          HStack {
            Text("デバッグモード")
              .font(.headline)
            
            Spacer()
            
            Toggle("", isOn: Binding(
              get: { store.isDebugModeEnabled },
              set: { _ in send(.toggleDebugMode) }
            ))
          }
          
          if store.isDebugModeEnabled {
            Divider()
            
            // 画面モード選択
            VStack(alignment: .leading, spacing: 12) {
              Text("画面モード")
                .font(.headline)
              
              ForEach(AppMode.allCases, id: \.self) { mode in
                HStack {
                  Button {
                    send(.setAppMode(mode))
                  } label: {
                    HStack {
                      Image(systemName: store.currentMode == mode ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(store.currentMode == mode ? .accentColor : .secondary)
                      
                      VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                          .font(.body)
                          .foregroundColor(.primary)
                        
                        Text(modeDescription(mode))
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      
                      Spacer()
                    }
                  }
                  .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
              }
            }
          }
        }
        
        Spacer()
        
        Button("完了") {
          send(.showModeSelector(false))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
      .padding()
      .navigationTitle("デバッグ設定")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる") {
            send(.showModeSelector(false))
          }
        }
      }
    }
  }
  
  private func modeDescription(_ mode: AppMode) -> String {
    switch mode {
    case .production:
      return "現在の統合画面（安定版）"
    case .development:
      return "録音・再生を分離した新画面（開発版）"
    }
  }
  #endif
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

#Preview("Production Mode") {
  VoiceAppView(
    store: Store(
      initialState: VoiceAppFeature.State(currentMode: .production)
    ) {
      VoiceAppFeature()
    }
  )
}

#Preview("Development Mode") {
  VoiceAppView(
    store: Store(
      initialState: VoiceAppFeature.State(
        currentMode: .development,
        isDebugModeEnabled: true
      )
    ) {
      VoiceAppFeature()
    }
  )
} 