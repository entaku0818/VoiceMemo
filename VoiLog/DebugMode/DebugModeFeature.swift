import SwiftUI
import ComposableArchitecture

// MARK: - Main App Feature
@Reducer
struct VoiceAppFeature {
  @ObservableState
  struct State: Equatable {
    var recordingFeature = RecordingFeature.State()
    var playbackFeature = PlaybackFeature.State()
    var playlistFeature = PlaylistListFeature.State()
    var settingFeature = SettingReducer.State(
      alert: nil,
      selectedFileFormat: "WAV",
      samplingFrequency: 44100.0,
      quantizationBitDepth: 16,
      numberOfChannels: 2,
      microphonesVolume: 75.0,
      developerSupported: false,
      hasPurchasedPremium: false
    )
    var selectedTab: Int = 0  // 0=録音, 1=再生, 2=プレイリスト, 3=設定

    // Cloud sync state
    var isSyncing = false
    var syncError: String?
    var showSyncError = false
  }

  enum Action: ViewAction, BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case recordingFeature(RecordingFeature.Action)
    case playbackFeature(PlaybackFeature.Action)
    case playlistFeature(PlaylistListFeature.Action)
    case settingFeature(SettingReducer.Action)

    enum View {
      case onAppear
      case syncToCloud
      case dismissSyncError
    }

    // Internal actions
    case syncCompleted(Result<Bool, Error>)
  }

  @Dependency(\.voiceMemoRepository) var voiceMemoRepository

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.recordingFeature, action: \.recordingFeature) {
      RecordingFeature()
    }

    Scope(state: \.playbackFeature, action: \.playbackFeature) {
      PlaybackFeature()
    }

    Scope(state: \.playlistFeature, action: \.playlistFeature) {
      PlaylistListFeature()
    }

    Scope(state: \.settingFeature, action: \.settingFeature) {
      SettingReducer()
    }

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          return .none

        case .syncToCloud:
          guard !state.isSyncing else { return .none }
          state.isSyncing = true
          state.syncError = nil

          return .run { send in
            do {
              let success = await voiceMemoRepository.syncToCloud()
              await send(.syncCompleted(.success(success)))
            } catch {
              await send(.syncCompleted(.failure(error)))
            }
          }

        case .dismissSyncError:
          state.showSyncError = false
          state.syncError = nil
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

      case .playlistFeature:
        return .none

      case .settingFeature:
        return .none

      case let .syncCompleted(result):
        state.isSyncing = false
        switch result {
        case .success(let success):
          if !success {
            state.syncError = "一部のファイルの同期に失敗しました"
            state.showSyncError = true
          }
          // Reload data after sync
          return .send(.playbackFeature(.view(.reloadData)))
        case .failure(let error):
          state.syncError = error.localizedDescription
          state.showSyncError = true
          return .none
        }
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
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            if store.isSyncing {
              HStack {
                ProgressView()
                  .controlSize(.mini)
                Text("同期中")
                  .font(.caption)
              }
            } else {
              Button {
                send(.syncToCloud)
              } label: {
                HStack {
                  Image(systemName: "icloud.and.arrow.up")
                  Text("同期")
                }
                .font(.caption)
              }
            }
          }
        }
      }
      .tabItem {
        Image(systemName: "play.circle")
        Text("再生")
      }
      .tag(1)

      // プレイリストタブ
      NavigationStack {
        ModernPlaylistListView(
          store: store.scope(state: \.playlistFeature, action: \.playlistFeature)
        )
      }
      .tabItem {
        Image(systemName: "list.bullet")
        Text("プレイリスト")
      }
      .tag(2)

      // 設定タブ
      NavigationStack {
        SettingView(
          store: store.scope(state: \.settingFeature, action: \.settingFeature),
          admobUnitId: "ca-app-pub-8721923248827329/5765169094"
        )
        .navigationTitle("設定")
      }
      .tabItem {
        Image(systemName: "gearshape")
        Text("設定")
      }
      .tag(3)
    }
    .onAppear {
      send(.onAppear)
    }
    .alert("同期エラー", isPresented: $store.showSyncError) {
      Button("OK") {
        send(.dismissSyncError)
      }
    } message: {
      Text(store.syncError ?? "同期中にエラーが発生しました")
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
