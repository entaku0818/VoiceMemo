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

    // Enhanced search properties
    var sortOption: SortOption = .dateDescending
    var showFavoritesOnly = false
    var durationFilter: DurationFilter = .all
    var showSearchFilters = false
    var selectedMemoForDetails: VoiceMemo.ID?
    var showDetailSheet = false
    var showEnhancedDetailSheet = false

    // Audio Editor
    var audioEditorState: AudioEditorReducer.State?
    var showAudioEditor = false

  }

  struct VoiceMemo: Identifiable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var url: URL
    var text: String
    var isFavorite = false
    // Legacy compatibility fields
    var fileFormat: String
    var samplingFrequency: Double
    var quantizationBitDepth: Int
    var numberOfChannels: Int
    var fileSize: Int64 = 0

    init(
      id: UUID = UUID(),
      title: String,
      date: Date,
      duration: TimeInterval,
      url: URL,
      text: String = "",
      fileFormat: String = "",
      samplingFrequency: Double = 44100.0,
      quantizationBitDepth: Int = 16,
      numberOfChannels: Int = 2,
      fileSize: Int64 = 0
    ) {
      self.id = id
      self.title = title
      self.date = date
      self.duration = duration
      self.url = url
      self.text = text
      self.fileFormat = fileFormat
      self.samplingFrequency = samplingFrequency
      self.quantizationBitDepth = quantizationBitDepth
      self.numberOfChannels = numberOfChannels
      self.fileSize = fileSize
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case delegate(DelegateAction)

    // Internal actions
    case memosLoaded([VoiceMemo])
    case playbackTimeUpdated(TimeInterval)
    case playbackFinished
    case audioPlayerDidFinish
    case audioEditor(AudioEditorReducer.Action)

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

      // Enhanced search actions
      case setSortOption(SortOption)
      case toggleFavoritesFilter
      case setDurationFilter(DurationFilter)
      case toggleSearchFilters

      // Detail view actions
      case showMemoDetails(VoiceMemo.ID)
      case hideDetailSheet
      case showEnhancedMemoDetails(VoiceMemo.ID)
      case hideEnhancedDetailSheet

      // Audio Editor Actions
      case showAudioEditor(VoiceMemo.ID)
      case dismissAudioEditor
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
            state.voiceMemos.removeAll { $0.id == id }
            if state.currentPlayingMemo == id {
              state.currentPlayingMemo = nil
              state.playbackState = .idle
              state.currentTime = 0
            }
            state.selectedMemoForDeletion = nil
            state.showDeleteConfirmation = false

            // データベースから削除
            return .run { send in
              voiceMemoRepository.delete(id)
              await send(.delegate(.memoDeleted(id)))
            }
          }
          return .none

        case .cancelDelete:
          state.selectedMemoForDeletion = nil
          state.showDeleteConfirmation = false
          return .none

        case .reloadData:
          return loadMemos()

        case let .updateTitle(id, newTitle):
          // ローカル状態も更新
          if let index = state.voiceMemos.firstIndex(where: { $0.id == id }) {
            state.voiceMemos[index].title = newTitle
          }

          // データベースでタイトルを更新
          return .run { _ in
            voiceMemoRepository.updateTitle(id, newTitle)
          }


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

        // Enhanced search actions
        case let .setSortOption(option):
          state.sortOption = option
          return .none

        case .toggleFavoritesFilter:
          state.showFavoritesOnly.toggle()
          return .none

        case let .setDurationFilter(filter):
          state.durationFilter = filter
          return .none

        case .toggleSearchFilters:
          state.showSearchFilters.toggle()
          return .none

        case let .showMemoDetails(id):
          state.selectedMemoForDetails = id
          state.showDetailSheet = true
          return .none

        case .hideDetailSheet:
          state.selectedMemoForDetails = nil
          state.showDetailSheet = false
          return .none

        case let .showEnhancedMemoDetails(id):
          state.selectedMemoForDetails = id
          state.showEnhancedDetailSheet = true
          return .none

        case .hideEnhancedDetailSheet:
          state.selectedMemoForDetails = nil
          state.showEnhancedDetailSheet = false
          return .none

        case let .showAudioEditor(memoID):
          guard let memo = state.voiceMemos.first(where: { $0.id == memoID }) else {
            return .none
          }

          state.audioEditorState = AudioEditorReducer.State(
            memoID: memo.id,
            audioURL: memo.url,
            originalTitle: memo.title,
            duration: memo.duration
          )
          state.showAudioEditor = true
          return .none

        case .dismissAudioEditor:
          state.showAudioEditor = false
          state.audioEditorState = nil
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

      case .audioEditor(.save):
        // 編集完了時にPlaybackFeatureのデータを更新
        state.showAudioEditor = false
        state.audioEditorState = nil
        return .send(.view(.onAppear))

      case .audioEditor(.cancel):
        // 編集キャンセル時
        state.showAudioEditor = false
        state.audioEditorState = nil
        return .none

      case .audioEditor:
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private func loadMemos() -> Effect<Action> {
    .run { send in
      // データベースからデータを読み込み（Legacy形式で取得）
      let voiceMemoVoices = voiceMemoRepository.selectAllData()

      let memos = voiceMemoVoices.map { voice in
        // ファイルサイズを計算
        let fileSize: Int64 = {
          do {
            let attributes = try FileManager.default.attributesOfItem(atPath: voice.url.path)
            return attributes[.size] as? Int64 ?? 0
          } catch {
            return 0
          }
        }()

        return VoiceMemo(
          id: voice.uuid,
          title: voice.title.isEmpty ? "無題の録音" : voice.title,
          date: voice.date,
          duration: voice.duration,
          url: voice.url,
          text: voice.text,
          fileFormat: voice.fileFormat,
          samplingFrequency: voice.samplingFrequency,
          quantizationBitDepth: voice.quantizationBitDepth,
          numberOfChannels: voice.numberOfChannels,
          fileSize: fileSize
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
        if let selectedId = store.selectedMemoForDeletion,
           let memo = store.voiceMemos.first(where: { $0.id == selectedId }) {
          Text("\(memo.title)\n\(formatDate(memo.date))\n再生時間: \(formatDuration(memo.duration))\n\nこの録音を削除しますか？")
        } else {
          Text("この録音ファイルを削除しますか？")
        }
      }
      .sheet(isPresented: $store.showDetailSheet) {
        if let selectedId = store.selectedMemoForDetails,
           let memo = store.voiceMemos.first(where: { $0.id == selectedId }) {
          VoiceMemoDetailView(memo: memo) {
            send(.hideDetailSheet)
          }
        }
      }
      .sheet(isPresented: $store.showAudioEditor) {
        if store.audioEditorState != nil {
          AudioEditorView(
            store: Store(initialState: store.audioEditorState!) {
              AudioEditorReducer()
            }
          )
        }
      }
    }
  }

    // 修正版: searchBarView を小さなサブビューに分割

    private var searchBarView: some View {
        VStack(spacing: 8) {
            searchInputSection

            if store.showSearchFilters {
                searchFiltersSection
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Search Input Section
    private var searchInputSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("録音を検索...", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)

            searchFilterToggleButton
        }
    }

    private var searchFilterToggleButton: some View {
        Button {
            send(.toggleSearchFilters)
        } label: {
            Image(systemName: store.showSearchFilters ?
                  "line.3.horizontal.decrease.circle.fill" :
                  "line.3.horizontal.decrease.circle")
                .foregroundColor(.accentColor)
                .font(.title2)
        }
    }

    // MARK: - Search Filters Section
    private var searchFiltersSection: some View {
        VStack(spacing: 12) {
            sortOptionsSection
            filterOptionsRow
            resultsCountView
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Sort Options
    private var sortOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("並び順")
                .font(.caption)
                .foregroundColor(.secondary)

            sortOptionsScrollView
        }
    }

    private var sortOptionsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    sortOptionButton(option)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func sortOptionButton(_ option: SortOption) -> some View {
        Button {
            send(.setSortOption(option))
        } label: {
            Text(option.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(sortOptionBackgroundColor(for: option))
                .foregroundColor(sortOptionForegroundColor(for: option))
                .cornerRadius(8)
        }
    }

    private func sortOptionBackgroundColor(for option: SortOption) -> Color {
        store.sortOption == option ? Color.accentColor : Color(.systemGray6)
    }

    private func sortOptionForegroundColor(for option: SortOption) -> Color {
        store.sortOption == option ? .white : .primary
    }

    // MARK: - Filter Options Row
    private var filterOptionsRow: some View {
        HStack {
            Spacer()
            durationFilterMenu
        }
    }

    private var durationFilterMenu: some View {
        Menu {
            ForEach(DurationFilter.allCases, id: \.self) { filter in
                durationFilterMenuItem(filter)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text(store.durationFilter.rawValue)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .cornerRadius(8)
        }
    }

    private func durationFilterMenuItem(_ filter: DurationFilter) -> some View {
        Button {
            send(.setDurationFilter(filter))
        } label: {
            HStack {
                Text(filter.rawValue)
                if store.durationFilter == filter {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // MARK: - Results Count
    private var resultsCountView: some View {
        Group {
            if !store.voiceMemos.isEmpty {
                Text("\(filteredMemos.count) / \(store.voiceMemos.count) 件")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
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
        } onInfoTap: {
          send(.showMemoDetails(memo.id))
        } onEditAudio: {
          send(.showAudioEditor(memo.id))
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
    var memos = store.voiceMemos

    // Apply text search filter
    if !store.searchQuery.isEmpty {
      memos = memos.filter {
        $0.title.localizedCaseInsensitiveContains(store.searchQuery) ||
        $0.text.localizedCaseInsensitiveContains(store.searchQuery)
      }
    }

    // Apply favorites filter
    if store.showFavoritesOnly {
      memos = memos.filter { $0.isFavorite }
    }

    // Apply duration filter
    memos = memos.filter { store.durationFilter.matches(duration: $0.duration) }

    // Apply sorting
    switch store.sortOption {
    case .dateDescending:
      memos.sort { $0.date > $1.date }
    case .dateAscending:
      memos.sort { $0.date < $1.date }
    case .titleAscending:
      memos.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    case .durationDescending:
      memos.sort { $0.duration > $1.duration }
    case .durationAscending:
      memos.sort { $0.duration < $1.duration }
    }

    return memos
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
  let onInfoTap: () -> Void
  let onEditAudio: () -> Void

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

        Button(action: onInfoTap) {
          Image(systemName: "info.circle")
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)

        Button(action: onEditAudio) {
          Image(systemName: "waveform.path")
            .foregroundColor(.purple)
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
