import SwiftUI
import ComposableArchitecture
import AVFoundation

@Reducer
struct PlaybackFeature {
  @ObservableState
  struct State: Equatable {
    var voiceMemos: [VoiceMemo] = []
    var searchQuery: String = ""
    var isLoading = false
    var currentPlayingMemo: VoiceMemo.ID?
    var playbackState: PlaybackState = .idle
    var currentTime: TimeInterval = 0
    var selectedMemoForDeletion: VoiceMemo.ID?
    var showDeleteConfirmation = false
    var editingMemoId: VoiceMemo.ID?
    var editingTitle: String = ""

    enum PlaybackState: Equatable {
      case idle
      case playing
      case paused
    }
  }

  struct VoiceMemo: Identifiable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var url: URL
    var text: String
    var isFavorite = false

    init(
      id: UUID = UUID(),
      title: String,
      date: Date,
      duration: TimeInterval,
      url: URL,
      text: String = ""
    ) {
      self.id = id
      self.title = title
      self.date = date
      self.duration = duration
      self.url = url
      self.text = text
    }
  }

  enum Action: ViewAction, BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case delegate(DelegateAction)

    // Internal actions
    case memosLoaded([VoiceMemo])
    case playbackTimeUpdated(TimeInterval)
    case playbackFinished
    case audioPlayerDidFinish

    enum View {
      case onAppear
      case refreshRequested
      case memoSelected(VoiceMemo.ID)
      case playPauseButtonTapped(VoiceMemo.ID)
      case stopButtonTapped
      case seekTo(TimeInterval)
      case toggleFavorite(VoiceMemo.ID)
      case deleteMemo(VoiceMemo.ID)
      case confirmDelete
      case cancelDelete
      case reloadData
      case updateTitle(VoiceMemo.ID, String)
      case startEditingTitle(VoiceMemo.ID)
      case cancelEditingTitle
      case saveEditingTitle
      case editingTitleChanged(String)
    }

    enum DelegateAction: Equatable {
      case memoDeleted(VoiceMemo.ID)
    }
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  @Dependency(\.voiceMemoRepository) var voiceMemoRepository

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          return loadMemos()

        case .refreshRequested:
          state.isLoading = true
          return loadMemos()

        case let .memoSelected(id):
          if state.currentPlayingMemo == id {
            // 同じメモが選択された場合は再生/一時停止を切り替え
            return .send(.view(.playPauseButtonTapped(id)))
          } else {
            // 別のメモが選択された場合は新しいメモを再生
            state.currentPlayingMemo = id
            state.playbackState = .playing
            state.currentTime = 0

            if let memo = state.voiceMemos.first(where: { $0.id == id }) {
              return startPlayback(url: memo.url)
            }
          }
          return .none

        case let .playPauseButtonTapped(id):
          if state.currentPlayingMemo == id {
            if state.playbackState == .playing {
              // 再生中の場合は停止
              state.playbackState = .idle
              state.currentPlayingMemo = nil
              state.currentTime = 0
              return .run { _ in
                try await audioPlayer.stop()
              }
            } else {
              // 停止中の場合は再生開始
              state.playbackState = .playing
              if let memo = state.voiceMemos.first(where: { $0.id == id }) {
                return startPlayback(url: memo.url)
              }
            }
          } else {
            // 新しいメモの再生開始
            state.currentPlayingMemo = id
            state.playbackState = .playing
            state.currentTime = 0

            if let memo = state.voiceMemos.first(where: { $0.id == id }) {
              return startPlayback(url: memo.url)
            }
          }
          return .none

        case .stopButtonTapped:
          state.playbackState = .idle
          state.currentPlayingMemo = nil
          state.currentTime = 0
          return .run { _ in
            try await audioPlayer.stop()
          }

        case let .seekTo(time):
          state.currentTime = time
          // 既存のAudioPlayerClientにはseekメソッドがないため、
          // 現在の再生を停止して新しい位置から再生を開始
          if let memo = state.voiceMemos.first(where: { $0.id == state.currentPlayingMemo }) {
            return startPlayback(url: memo.url, startTime: time)
          }
          return .none

        case let .toggleFavorite(id):
          if let index = state.voiceMemos.firstIndex(where: { $0.id == id }) {
            state.voiceMemos[index].isFavorite.toggle()
          }
          return .none

        case let .deleteMemo(id):
          state.selectedMemoForDeletion = id
          state.showDeleteConfirmation = true
          return .none

        case .confirmDelete:
          if let id = state.selectedMemoForDeletion {
            // データベースから削除
            voiceMemoRepository.delete(id)

            state.voiceMemos.removeAll { $0.id == id }
            if state.currentPlayingMemo == id {
              state.currentPlayingMemo = nil
              state.playbackState = .idle
              state.currentTime = 0
            }
            state.selectedMemoForDeletion = nil
            state.showDeleteConfirmation = false
            return .send(.delegate(.memoDeleted(id)))
          }
          return .none

        case .cancelDelete:
          state.selectedMemoForDeletion = nil
          state.showDeleteConfirmation = false
          return .none

        case .reloadData:
          return loadMemos()

        case let .updateTitle(id, newTitle):
          // データベースでタイトルを更新
          voiceMemoRepository.updateTitle(id, newTitle)

          // ローカル状態も更新
          if let index = state.voiceMemos.firstIndex(where: { $0.id == id }) {
            state.voiceMemos[index].title = newTitle
          }
          return .none

        case let .startEditingTitle(id):
          state.editingMemoId = id
          // 現在のタイトルを編集用テキストとして設定
          if let memo = state.voiceMemos.first(where: { $0.id == id }) {
            state.editingTitle = memo.title
          }
          return .none

        case .cancelEditingTitle:
          state.editingMemoId = nil
          state.editingTitle = ""
          return .none

        case .saveEditingTitle:
          if let editingId = state.editingMemoId {
            let trimmedTitle = state.editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = trimmedTitle.isEmpty ? "無題の録音" : trimmedTitle

            // タイトルを更新
            return .send(.view(.updateTitle(editingId, finalTitle)))
              .concatenate(with: .send(.view(.cancelEditingTitle)))
          }
          return .none

        case let .editingTitleChanged(newTitle):
          state.editingTitle = newTitle
          return .none
        }

      case let .memosLoaded(memos):
        state.voiceMemos = memos
        state.isLoading = false
        return .none

      case let .playbackTimeUpdated(time):
        state.currentTime = time
        return .none

      case .playbackFinished:
        state.playbackState = .idle
        state.currentPlayingMemo = nil
        state.currentTime = 0
        return .none

      case .audioPlayerDidFinish:
        return .send(.playbackFinished)

      case .delegate:
        return .none
      }
    }
  }

  private func loadMemos() -> Effect<Action> {
    .run { send in
      // データベースからデータを読み込み
      let voiceMemoVoices = voiceMemoRepository.selectAllData()

      let memos = voiceMemoVoices.map { voice in
        VoiceMemo(
          id: voice.uuid,
          title: voice.title.isEmpty ? "無題の録音" : voice.title,
          date: voice.date,
          duration: voice.duration,
          url: voice.url,
          text: voice.text
        )
      }

      await send(.memosLoaded(memos))
    }
  }

  private func startPlayback(url: URL, startTime: TimeInterval = 0) -> Effect<Action> {
    .run { send in
      // 音声再生開始
      async let playback: Void = {
        do {
          // AudioPlayerClientのplayメソッドのシグネチャに合わせる
          // play(URL, startTime: Double, speed: PlaybackSpeed, isLooping: Bool)
          _ = try await audioPlayer.play(url, startTime, .normal, false)
          await send(.audioPlayerDidFinish)
        } catch {
          await send(.playbackFinished)
        }
      }()

      // 再生時間の更新
      async let timeUpdates: Void = {
        for await _ in clock.timer(interval: .milliseconds(100)) {
          do {
            let currentTime = try await audioPlayer.getCurrentTime()
            await send(.playbackTimeUpdated(currentTime))
          } catch {
            // エラーが発生した場合は更新を停止
            break
          }
        }
      }()

      _ = await (playback, timeUpdates)
    }
  }
}

@ViewAction(for: PlaybackFeature.self)
struct PlaybackView: View {
  @Perception.Bindable var store: StoreOf<PlaybackFeature>

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Search Bar
        searchBarView

        // Voice Memos List
        voiceMemosListView

        // Playback Controls (if playing)
        if store.currentPlayingMemo != nil {
          playbackControlsView
        }
      }
      .navigationTitle("録音ファイル")
      .onAppear {
        send(.onAppear)
      }
      .refreshable {
        await send(.refreshRequested).finish()
      }
      .alert("削除確認", isPresented: $store.showDeleteConfirmation) {
        Button("削除", role: .destructive) {
          send(.confirmDelete)
        }
        Button("キャンセル", role: .cancel) {
          send(.cancelDelete)
        }
      } message: {
        Text("この録音ファイルを削除しますか？")
      }
    }
  }

  private var searchBarView: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.gray)
      TextField("録音を検索...", text: $store.searchQuery)
        .textFieldStyle(.roundedBorder)
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }

  private var voiceMemosListView: some View {
    List {
      ForEach(filteredMemos) { memo in
        VoiceMemoRow(
          memo: memo,
          isPlaying: store.currentPlayingMemo == memo.id && store.playbackState == .playing,
          isPaused: store.currentPlayingMemo == memo.id && store.playbackState == .paused,
          currentTime: store.currentPlayingMemo == memo.id ? store.currentTime : 0,
          isEditing: store.editingMemoId == memo.id,
          editingTitle: store.editingTitle
        ) {
          send(.memoSelected(memo.id))
        } onPlayPause: {
          send(.playPauseButtonTapped(memo.id))
        } onFavoriteToggle: {
          send(.toggleFavorite(memo.id))
        } onDelete: {
          send(.deleteMemo(memo.id))
        } onStartEdit: {
          send(.startEditingTitle(memo.id))
        } onCancelEdit: {
          send(.cancelEditingTitle)
        } onSaveEdit: {
          send(.saveEditingTitle)
        } onEditingChanged: { newTitle in
          send(.editingTitleChanged(newTitle))
        }
      }
    }
    .listStyle(.plain)
    .overlay {
      if store.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(0.1))
      }
    }
  }

  private var playbackControlsView: some View {
    VStack(spacing: 12) {
      Divider()

      if let currentMemo = store.voiceMemos.first(where: { $0.id == store.currentPlayingMemo }) {
        VStack(spacing: 8) {
          // Now Playing Info
          HStack {
            VStack(alignment: .leading) {
              Text(currentMemo.title.isEmpty ? "無題の録音" : currentMemo.title)
                .font(.headline)
                .lineLimit(1)
              Text(formatDate(currentMemo.date))
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
              send(.stopButtonTapped)
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
            }
          }

          // Progress Slider
          VStack(spacing: 4) {
            Slider(
              value: Binding(
                get: { store.currentTime },
                set: { send(.seekTo($0)) }
              ),
              in: 0...currentMemo.duration
            )

            HStack {
              Text(formatDuration(store.currentTime))
                .font(.caption)
                .monospacedDigit()

              Spacer()

              Text(formatDuration(currentMemo.duration))
                .font(.caption)
                .monospacedDigit()
            }
            .foregroundColor(.secondary)
          }

          // Playback Controls
          HStack(spacing: 32) {
            Button {
              send(.playPauseButtonTapped(currentMemo.id))
            } label: {
              Image(systemName: store.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            }
          }
        }
        .padding()
      }
    }
    .background(Color(.systemBackground))
  }

  private var filteredMemos: [PlaybackFeature.VoiceMemo] {
    if store.searchQuery.isEmpty {
      return store.voiceMemos
    } else {
      return store.voiceMemos.filter {
        $0.title.localizedCaseInsensitiveContains(store.searchQuery) ||
        $0.text.localizedCaseInsensitiveContains(store.searchQuery)
      }
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

struct VoiceMemoRow: View {
  let memo: PlaybackFeature.VoiceMemo
  let isPlaying: Bool
  let isPaused: Bool
  let currentTime: TimeInterval
  let isEditing: Bool
  let editingTitle: String
  let onTap: () -> Void
  let onPlayPause: () -> Void
  let onFavoriteToggle: () -> Void
  let onDelete: () -> Void
  let onStartEdit: () -> Void
  let onCancelEdit: () -> Void
  let onSaveEdit: () -> Void
  let onEditingChanged: (String) -> Void

  var body: some View {
    HStack(spacing: 12) {
      // Play/Pause Button
      Button(action: onPlayPause) {
        Image(systemName: playButtonIcon)
          .font(.title2)
          .foregroundColor(isPlaying ? .red : .accentColor)
          .frame(width: 30, height: 30)
      }
      .buttonStyle(.plain)

      // Memo Info
      VStack(alignment: .leading, spacing: 4) {
        if isEditing {
          HStack(spacing: 8) {
            TextField("タイトル", text: Binding(
              get: { editingTitle },
              set: { onEditingChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.headline)
            .submitLabel(.done)
            .onSubmit {
              onSaveEdit()
            }

            Button("保存") {
              onSaveEdit()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)

            Button("キャンセル") {
              onCancelEdit()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.mini)
          }
        } else {
          HStack {
            Text(memo.title.isEmpty ? "無題の録音" : memo.title)
              .font(.headline)
              .lineLimit(1)

            Button {
              onStartEdit()
            } label: {
              Image(systemName: "pencil")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
          }
        }

        HStack {
          Text(formatDate(memo.date))
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          Text(formatDuration(memo.duration))
            .font(.caption)
            .foregroundColor(.secondary)
            .monospacedDigit()
        }

        if !memo.text.isEmpty {
          Text(memo.text)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }

        // Progress Bar (if playing)
        if isPlaying || isPaused {
          ProgressView(value: currentTime, total: memo.duration)
            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
        }
      }

      Spacer()

      // Actions
      VStack(spacing: 8) {
        Button(action: onFavoriteToggle) {
          Image(systemName: memo.isFavorite ? "star.fill" : "star")
            .foregroundColor(memo.isFavorite ? .yellow : .gray)
        }
        .buttonStyle(.plain)

        Button(action: onDelete) {
          Image(systemName: "trash")
            .foregroundColor(.red)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
  }

  private var playButtonIcon: String {
    if isPlaying {
      return "pause.circle.fill"
    } else if isPaused {
      return "play.circle.fill"
    } else {
      return "play.circle"
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

#Preview {
  PlaybackView(
    store: Store(initialState: PlaybackFeature.State()) {
      PlaybackFeature()
    }
  )
}
