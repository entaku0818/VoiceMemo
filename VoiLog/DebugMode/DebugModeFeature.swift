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

    // Tutorial state
    var tutorialFeature = TutorialFeature.State()
    var shouldShowTutorial = false
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case recordingFeature(RecordingFeature.Action)
    case playbackFeature(PlaybackFeature.Action)
    case playlistFeature(PlaylistListFeature.Action)
    case settingFeature(SettingReducer.Action)
    case tutorialFeature(TutorialFeature.Action)

    enum View {
      case onAppear
      case syncToCloud
      case dismissSyncError
      case startTutorial
    }

    // Internal actions
    case syncCompleted(Result<Bool, Error>)
  }

  @Dependency(\.voiceMemoRepository) var voiceMemoRepository
  @Dependency(\.userDefaults) var userDefaultsClient

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

    Scope(state: \.tutorialFeature, action: \.tutorialFeature) {
      TutorialFeature()
    }

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          // 初回起動時のチュートリアル表示判定
          let isFirstLaunch = !userDefaultsClient.bool(UserDefaultsKeys.firstLaunch)
          let tutorialCompleted = userDefaultsClient.bool(UserDefaultsKeys.tutorialCompleted)

          if isFirstLaunch {
            userDefaultsClient.set(true, UserDefaultsKeys.firstLaunch)
          }

          if isFirstLaunch && !tutorialCompleted {
            state.shouldShowTutorial = true
            return .send(.tutorialFeature(.view(.start)))
          }

          return .none

        case .startTutorial:
          state.shouldShowTutorial = true
          return .send(.tutorialFeature(.view(.start)))

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

      case .recordingFeature(.delegate(.recordingWillStart)):
        // 録音開始時に再生中の音声を停止
        if state.playbackFeature.playbackState == .playing {
          return .send(.playbackFeature(.view(.stopButtonTapped)))
        }
        return .none

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

      case .settingFeature(.delegate(.startTutorialRequested)):
        state.shouldShowTutorial = true
        return .send(.tutorialFeature(.view(.start)))

      case .settingFeature:
        return .none

      case .tutorialFeature(.delegate(.tutorialCompleted)):
        state.shouldShowTutorial = false
        return .none

      case .tutorialFeature(.delegate(.switchToTab(let tabIndex))):
        state.selectedTab = tabIndex
        return .none

      case .tutorialFeature:
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

struct VoiceAppView: View {
  @Perception.Bindable var store: StoreOf<VoiceAppFeature>
  let recordAdmobUnitId: String
  let playListAdmobUnitId: String
  let admobUnitId: String

  var body: some View {
    TabView(selection: $store.selectedTab) {
      // 録音タブ
      NavigationStack {
        VStack(spacing: 0) {
          RecordingView(
            store: store.scope(state: \.recordingFeature, action: \.recordingFeature)
          )

          if !store.settingFeature.hasPurchasedPremium {
            AdmobBannerView(unitId: recordAdmobUnitId)
              .frame(height: 50)
          }
        }
      }
      .tabItem {
        Image(systemName: "record.circle")
        Text("録音")
      }
      .tag(0)

      // 再生タブ
      NavigationStack {
        VStack(spacing: 0) {
          PlaybackView(
            store: store.scope(state: \.playbackFeature, action: \.playbackFeature)
          )

          if !store.settingFeature.hasPurchasedPremium {
            AdmobBannerView(unitId: recordAdmobUnitId)
              .frame(height: 50)
          }
        }
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
                store.send(.view(.syncToCloud))
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
        VStack(spacing: 0) {
          ModernPlaylistListView(
            store: store.scope(state: \.playlistFeature, action: \.playlistFeature)
          )

          if !store.settingFeature.hasPurchasedPremium {
            AdmobBannerView(unitId: playListAdmobUnitId)
              .frame(height: 50)
          }
        }
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
          admobUnitId: admobUnitId
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
      store.send(.view(.onAppear))
    }
    .alert("同期エラー", isPresented: $store.showSyncError) {
      Button("OK") {
        store.send(.view(.dismissSyncError))
      }
    } message: {
      Text(store.syncError ?? "同期中にエラーが発生しました")
    }
    .overlay {
      // チュートリアルオーバーレイ
      if store.shouldShowTutorial && store.tutorialFeature.isActive {
        TutorialOverlayView(
          store: store.scope(state: \.tutorialFeature, action: \.tutorialFeature)
        )
      }
    }
  }
}

// MARK: - App Entry Point
struct VoiceAppEntryView: View {
  let recordAdmobUnitId: String
  let playListAdmobUnitId: String
  let admobUnitId: String

  var body: some View {
    VoiceAppView(
      store: Store(initialState: VoiceAppFeature.State()) {
        VoiceAppFeature()
      },
      recordAdmobUnitId: recordAdmobUnitId,
      playListAdmobUnitId: playListAdmobUnitId,
      admobUnitId: admobUnitId
    )
  }
}

#Preview {
  VoiceAppView(
    store: Store(initialState: VoiceAppFeature.State()) {
      VoiceAppFeature()
    },
    recordAdmobUnitId: "ca-app-pub-3940256099942544/2934735716",
    playListAdmobUnitId: "ca-app-pub-3940256099942544/2934735716",
    admobUnitId: "ca-app-pub-3940256099942544/2934735716"
  )
}
