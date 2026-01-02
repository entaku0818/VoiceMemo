import SwiftUI
import ComposableArchitecture
import os.log
import StoreKit

// MARK: - Main App Feature
@Reducer
struct VoiceAppFeature {
  enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case error
  }

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
    var syncStatus: SyncStatus = .idle
    var syncError: String?
    var showSyncError = false

    // Tutorial state
    var tutorialFeature = TutorialFeature.State()
    var shouldShowTutorial = false

    // Paywall state
    var showPaywall = false

    // Recording lock alert
    var showRecordingLockAlert = false
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
      case checkSyncStatus
      case dismissSyncError
      case startTutorial
      case dismissPaywall
    }

    // Internal actions
    case syncCompleted(Result<Bool, Error>)
    case syncStatusChecked(hasDifferences: Bool)
    case resetSyncStatus
  }

  @Dependency(\.voiceMemoRepository) var voiceMemoRepository
  @Dependency(\.userDefaults) var userDefaultsClient
  @Dependency(\.voiceMemoCoredataAccessor) var coreDataAccessor

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
      case .binding(\.selectedTab):
        // 録音中は他タブへの移動を禁止
        let isRecording = state.recordingFeature.recordingState == .recording
          || state.recordingFeature.recordingState == .paused
          || state.recordingFeature.recordingState == .encoding
        if isRecording && state.selectedTab != 0 {
          state.selectedTab = 0  // 録音タブに戻す
          state.showRecordingLockAlert = true
        }
        return .none

      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          // 課金状態を更新
          let hasPurchased = UserDefaultsManager.shared.hasPurchasedProduct
          state.settingFeature.hasPurchasedPremium = hasPurchased
          state.playbackFeature.hasPurchasedPremium = hasPurchased

          // 初回起動時のチュートリアル表示判定
          let isFirstLaunch = !userDefaultsClient.bool(UserDefaultsKeys.firstLaunch)
          let tutorialCompleted = userDefaultsClient.bool(UserDefaultsKeys.tutorialCompleted)

          if isFirstLaunch {
            userDefaultsClient.set(true, UserDefaultsKeys.firstLaunch)
          }

          // 重複データを削除（バックグラウンドで実行）
          let cleanupEffect: Effect<Action> = .run { _ in
            await MainActor.run {
              let removedCount = coreDataAccessor.removeDuplicates()
              if removedCount > 0 {
                AppLogger.data.info("Cleaned up \(removedCount) duplicate records on startup")
              }
            }
          }

          if isFirstLaunch && !tutorialCompleted {
            state.shouldShowTutorial = true
            return .merge(
              cleanupEffect,
              .send(.tutorialFeature(.view(.start)))
            )
          }

          // レビューリクエストの表示判定（2回目以降の起動時）
          let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")
          let lastReviewRequestDate = UserDefaults.standard.object(forKey: "lastReviewRequestDate") as? Date
          let shouldShowReview: Bool = {
            guard appUsageCount >= 2 else { return false }
            if let lastRequestDate = lastReviewRequestDate {
              let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
              return daysSinceLastRequest >= 30
            }
            return true
          }()

          if shouldShowReview {
            let reviewEffect: Effect<Action> = .run { _ in
              try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
              await MainActor.run {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                  SKStoreReviewController.requestReview(in: windowScene)
                  UserDefaults.standard.set(Date(), forKey: "lastReviewRequestDate")
                }
              }
            }
            return .merge(cleanupEffect, reviewEffect)
          }

          return cleanupEffect

        case .startTutorial:
          state.shouldShowTutorial = true
          return .send(.tutorialFeature(.view(.start)))

        case .syncToCloud:
          // 課金チェック
          guard state.settingFeature.hasPurchasedPremium else {
            state.showPaywall = true
            return .none
          }

          guard !state.isSyncing else { return .none }
          state.isSyncing = true
          state.syncStatus = .syncing
          state.syncError = nil

          return .run { send in
            do {
              let success = await voiceMemoRepository.syncToCloud()
              await send(.syncCompleted(.success(success)))
            } catch {
              await send(.syncCompleted(.failure(error)))
            }
          }

        case .checkSyncStatus:
          // 既に同期中の場合はスキップ
          let currentStatus = state.syncStatus
          AppLogger.sync.debug("checkSyncStatus called, current status: \(String(describing: currentStatus))")
          guard currentStatus != .syncing else {
            AppLogger.sync.debug("Skipping - already syncing")
            return .none
          }

          return .run { send in
            AppLogger.sync.debug("Checking for differences...")
            let hasDifferences = await voiceMemoRepository.checkForDifferences()
            AppLogger.sync.debug("hasDifferences: \(hasDifferences)")
            await send(.syncStatusChecked(hasDifferences: hasDifferences))
          }

        case .dismissSyncError:
          state.showSyncError = false
          state.syncError = nil
          state.syncStatus = .idle
          return .none

        case .dismissPaywall:
          state.showPaywall = false
          // 購入状態を更新
          state.settingFeature.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
          state.playbackFeature.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
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

      case .playbackFeature(.view(.onAppear)):
        // 課金ユーザーのみ同期状態をチェック
        guard state.settingFeature.hasPurchasedPremium else {
          return .none
        }
        AppLogger.sync.debug("PlaybackView onAppear - checking sync status")
        return .send(.view(.checkSyncStatus))

      case .playbackFeature(.delegate(.showPaywall)):
        state.showPaywall = true
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
            state.syncStatus = .error
          } else {
            state.syncStatus = .synced
          }
          // Reload data after sync (同期完了表示は維持)
          return .send(.playbackFeature(.view(.reloadData)))
        case .failure(let error):
          state.syncError = error.localizedDescription
          state.showSyncError = true
          state.syncStatus = .error
          return .none
        }

      case let .syncStatusChecked(hasDifferences):
        AppLogger.sync.debug("syncStatusChecked - hasDifferences: \(hasDifferences)")
        if hasDifferences {
          // 差分がある場合はidleのまま（同期ボタン押下を促す）
          state.syncStatus = .idle
          AppLogger.sync.debug("Status set to: idle (has differences)")
        } else {
          // 差分がない場合は同期完了表示（維持）
          state.syncStatus = .synced
          AppLogger.sync.debug("Status set to: synced (no differences)")
        }
        return .none

      case .resetSyncStatus:
        state.syncStatus = .idle
        return .none
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
            SyncStatusView(
              syncStatus: store.syncStatus,
              onSync: { store.send(.view(.syncToCloud)) }
            )
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
    .alert("録音中", isPresented: $store.showRecordingLockAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("録音中は他の操作ができません")
    }
    .overlay {
      // チュートリアルオーバーレイ
      if store.shouldShowTutorial && store.tutorialFeature.isActive {
        TutorialOverlayView(
          store: store.scope(state: \.tutorialFeature, action: \.tutorialFeature)
        )
      }
    }
    .sheet(isPresented: $store.showPaywall) {
      PaywallView(purchaseManager: PurchaseManager.shared)
        .onDisappear {
          store.send(.view(.dismissPaywall))
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

// MARK: - Sync Status View
struct SyncStatusView: View {
  let syncStatus: VoiceAppFeature.SyncStatus
  let onSync: () -> Void

  var body: some View {
    switch syncStatus {
    case .idle:
      Button(action: onSync) {
        HStack(spacing: 4) {
          Image(systemName: "icloud.and.arrow.up")
          Text("同期")
        }
        .font(.caption)
      }

    case .syncing:
      HStack(spacing: 4) {
        ProgressView()
          .controlSize(.mini)
        Text("同期中")
          .font(.caption)
          .foregroundColor(.secondary)
      }

    case .synced:
      HStack(spacing: 4) {
        Image(systemName: "checkmark.icloud")
          .foregroundColor(.green)
        Text("同期完了")
          .font(.caption)
          .foregroundColor(.green)
      }

    case .error:
      HStack(spacing: 4) {
        Image(systemName: "exclamationmark.icloud")
          .foregroundColor(.red)
        Text("エラー")
          .font(.caption)
          .foregroundColor(.red)
      }
    }
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
