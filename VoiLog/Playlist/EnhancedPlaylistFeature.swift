//
//  EnhancedPlaylistFeature.swift
//  VoiLog
//
//  Created for Issue #81: プレイリスト機能の実装
//

import Foundation
import ComposableArchitecture
import SwiftUI
import OSLog
import IdentifiedCollections

// MARK: - Enhanced Playlist Feature

@Reducer
struct EnhancedPlaylistFeature {

    // MARK: - Playback Modes
    enum PlaybackMode: String, CaseIterable, Equatable {
        case sequential = "順次再生"
        case shuffle = "シャッフル"
        case random = "ランダム"

        var icon: String {
            switch self {
            case .sequential: return "list.number"
            case .shuffle: return "shuffle"
            case .random: return "arrow.uturn.up"
            }
        }
    }

    enum RepeatMode: String, CaseIterable, Equatable {
        case off = "リピートオフ"
        case one = "1曲リピート"
        case all = "全曲リピート"

        var icon: String {
            switch self {
            case .off: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        let id: UUID
        var name: String
        var voices: [VoiceMemoRepository.Voice]
        var createdAt: Date
        var updatedAt: Date
        var isLoading = false
        var error: String?

        // Enhanced Playback Features
        var playbackMode: PlaybackMode = .sequential
        var repeatMode: RepeatMode = .off
        var isPlaying = false
        var currentPlayingIndex: Int?
        var currentTime: TimeInterval = 0
        var shuffledOrder: [URL] = []
        var playbackHistory: [URL] = []

        // UI State
        var isEditingName = false
        var editingName: String = ""
        var isShowingVoiceSelection = false
        var showingPlaybackModeSelection = false
        var showingRepeatModeSelection = false

        // Voice Memos
        var voiceMemos: IdentifiedArrayOf<EnhancedVoiceMemoState> = []

        var asPlaylist: Playlist {
            Playlist(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        // Current playing memo
        var currentPlayingMemo: EnhancedVoiceMemoState? {
            guard let index = currentPlayingIndex,
                  index < voiceMemos.count else { return nil }
            return voiceMemos[index]
        }

        // Next memo to play based on current mode
        var nextMemoIndex: Int? {
            guard !voiceMemos.isEmpty else { return nil }
            guard let currentIndex = currentPlayingIndex else { return 0 }

            switch playbackMode {
            case .sequential:
                let nextIndex = currentIndex + 1
                return nextIndex < voiceMemos.count ? nextIndex : nil

            case .shuffle:
                if shuffledOrder.isEmpty {
                    return generateShuffleOrder()
                }
                // Find current position in shuffle order and get next
                if currentIndex < voiceMemos.count,
                   let shuffleIndex = shuffledOrder.firstIndex(of: voiceMemos[currentIndex].url) {
                    let nextShuffleIndex = shuffleIndex + 1
                    if nextShuffleIndex < shuffledOrder.count {
                        let nextURL = shuffledOrder[nextShuffleIndex]
                        return voiceMemos.firstIndex { $0.url == nextURL }
                    }
                }
                return nil

            case .random:
                // Generate random index that's not the current one
                let availableIndices = Array(0..<voiceMemos.count).filter { $0 != currentIndex }
                return availableIndices.randomElement()
            }
        }

        private func generateShuffleOrder() -> Int? {
            let urls = voiceMemos.map { $0.url }
            // Create shuffled array excluding currently playing item if any
            var shuffleable = urls
            if let currentIndex = currentPlayingIndex {
                shuffleable.removeAll { $0 == voiceMemos[currentIndex].url }
                shuffleable.shuffle()
                // Insert current item at beginning
                shuffleable.insert(voiceMemos[currentIndex].url, at: 0)
            } else {
                shuffleable.shuffle()
            }
            return shuffleable.isEmpty ? nil : 0
        }
    }

    // MARK: - Enhanced Voice Memo State
    struct EnhancedVoiceMemoState: Equatable, Identifiable {
        let id: UUID
        let url: URL
        var title: String
        var date: Date
        var duration: TimeInterval
        var text: String
        var isPlaying = false
        var currentTime: TimeInterval = 0

        init(from voice: VoiceMemoRepository.Voice) {
            self.id = voice.id
            self.url = voice.url
            self.title = voice.title
            self.date = voice.createdAt
            self.duration = voice.duration
            self.text = voice.text
        }
    }

    // MARK: - Actions
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case delegate(Delegate)

        // Internal actions
        case dataLoaded(PlaylistDetail)
        case playlistLoadingFailed(PlaylistError)
        case nameUpdateSuccess(PlaylistDetail)
        case nameUpdateFailed(PlaylistError)
        case voiceRemoved(PlaylistDetail)
        case voiceRemovalFailed(PlaylistError)
        case voiceMemosLoaded([EnhancedVoiceMemoState])
        case voiceMemosLoadFailed(PlaylistError)
        case voiceAddedToPlaylist(PlaylistDetail)
        case voiceAddFailedToPlaylist(PlaylistError)
        case playbackTimeUpdated(TimeInterval)
        case playbackFinished
        case playbackFailed(Error)

        enum View: Equatable {
            case onAppear
            case editButtonTapped
            case saveNameButtonTapped
            case cancelEditButtonTapped
            case removeVoice(UUID)
            case loadVoiceMemos
            case showVoiceSelectionSheet
            case hideVoiceSelectionSheet
            case addVoiceToPlaylist(UUID)

            // Enhanced Playback Actions
            case playButtonTapped
            case pauseButtonTapped
            case stopButtonTapped
            case nextTrackTapped
            case previousTrackTapped
            case seekTo(TimeInterval)
            case playMemoAtIndex(Int)
            case setPlaybackMode(PlaybackMode)
            case setRepeatMode(RepeatMode)
            case shufflePlaylist
            case showPlaybackModeSelection
            case hidePlaybackModeSelection
            case showRepeatModeSelection
            case hideRepeatModeSelection
        }

        enum Delegate: Equatable {
            case playlistUpdated(Playlist)
            case playlistDeleted(UUID)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.playlistRepository) var playlistRepository
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock

    private enum CancelID: Hashable {
        case playback
        case timeUpdates
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.voilog", category: "EnhancedPlaylist")

    // MARK: - Reducer Body
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .view(viewAction):
                return handleViewAction(state: &state, action: viewAction)

            case let .dataLoaded(detail):
                state.name = detail.name
                state.voices = detail.voices
                state.createdAt = detail.createdAt
                state.updatedAt = detail.updatedAt
                state.isLoading = false
                state.error = nil
                return loadVoiceMemos(voices: detail.voices)

            case let .playlistLoadingFailed(error):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case let .nameUpdateSuccess(detail):
                state.name = detail.name
                state.voices = detail.voices
                state.updatedAt = detail.updatedAt
                state.isEditingName = false
                state.editingName = ""
                return .none

            case let .nameUpdateFailed(error):
                state.error = error.localizedDescription
                return .none

            case let .voiceRemoved(detail):
                state.voices = detail.voices
                state.updatedAt = detail.updatedAt
                return loadVoiceMemos(voices: detail.voices)

            case let .voiceRemovalFailed(error):
                state.error = error.localizedDescription
                return .none

            case let .voiceMemosLoaded(memos):
                state.voiceMemos = IdentifiedArrayOf(uniqueElements: memos)
                return .none

            case let .voiceMemosLoadFailed(error):
                state.error = error.localizedDescription
                return .none

            case let .voiceAddedToPlaylist(detail):
                state.voices = detail.voices
                state.updatedAt = detail.updatedAt
                return loadVoiceMemos(voices: detail.voices)

            case let .voiceAddFailedToPlaylist(error):
                state.error = error.localizedDescription
                return .none

            case let .playbackTimeUpdated(time):
                state.currentTime = time
                if let index = state.currentPlayingIndex {
                    state.voiceMemos[index].currentTime = time
                }
                return .none

            case .playbackFinished:
                return handlePlaybackFinished(state: &state)

            case let .playbackFailed(error):
                logger.error("Playback failed: \(error.localizedDescription)")
                state.error = "再生に失敗しました"
                state.isPlaying = false
                state.currentPlayingIndex = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - View Action Handler
    private func handleViewAction(state: inout State, action: Action.View) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
            return .run { [id = state.id] send in
                do {
                    guard let detail = try await playlistRepository.fetch(id) else {
                        throw PlaylistRepositoryError.notFound
                    }
                    await send(.dataLoaded(detail))
                } catch {
                    await send(.playlistLoadingFailed(PlaylistError.from(error)))
                }
            }

        case .editButtonTapped:
            state.isEditingName = true
            state.editingName = state.name
            return .none

        case .saveNameButtonTapped:
            let newName = state.editingName
            return .run { [playlist = state.asPlaylist] send in
                do {
                    let updated = try await playlistRepository.update(playlist, newName)
                    guard let detail = try await playlistRepository.fetch(updated.id) else {
                        throw PlaylistRepositoryError.notFound
                    }
                    await send(.nameUpdateSuccess(detail))
                } catch {
                    await send(.nameUpdateFailed(PlaylistError.from(error)))
                }
            }

        case .cancelEditButtonTapped:
            state.isEditingName = false
            state.editingName = ""
            return .none

        case let .removeVoice(voiceId):
            return .run { [playlist = state.asPlaylist] send in
                do {
                    let updated = try await playlistRepository.removeVoice(voiceId, playlist)
                    guard let detail = try await playlistRepository.fetch(updated.id) else {
                        throw PlaylistRepositoryError.notFound
                    }
                    await send(.voiceRemoved(detail))
                } catch {
                    await send(.voiceRemovalFailed(PlaylistError.from(error)))
                }
            }

        case .loadVoiceMemos:
            return loadVoiceMemos(voices: state.voices)

        case .showVoiceSelectionSheet:
            state.isShowingVoiceSelection = true
            return .none

        case .hideVoiceSelectionSheet:
            state.isShowingVoiceSelection = false
            return .none

        case let .addVoiceToPlaylist(voiceId):
            return .run { [playlist = state.asPlaylist] send in
                do {
                    let updated = try await playlistRepository.addVoice(voiceId, playlist)
                    guard let detail = try await playlistRepository.fetch(updated.id) else {
                        throw PlaylistRepositoryError.notFound
                    }
                    await send(.voiceAddedToPlaylist(detail))
                } catch {
                    await send(.voiceAddFailedToPlaylist(PlaylistError.from(error)))
                }
            }

        // Enhanced Playback Actions
        case .playButtonTapped:
            if state.isPlaying {
                return .send(.view(.pauseButtonTapped))
            } else {
                if let index = state.currentPlayingIndex {
                    return resumePlayback(state: &state, index: index)
                } else if !state.voiceMemos.isEmpty {
                    return startPlayback(state: &state, index: 0)
                }
            }
            return .none

        case .pauseButtonTapped:
            state.isPlaying = false
            if let index = state.currentPlayingIndex {
                state.voiceMemos[index].isPlaying = false
            }
            return .cancel(id: CancelID.playback)
                .concatenate(with: .cancel(id: CancelID.timeUpdates))

        case .stopButtonTapped:
            return stopPlayback(state: &state)

        case .nextTrackTapped:
            return playNextTrack(state: &state)

        case .previousTrackTapped:
            return playPreviousTrack(state: &state)

        case let .seekTo(time):
            state.currentTime = time
            if let index = state.currentPlayingIndex {
                state.voiceMemos[index].currentTime = time
                let memo = state.voiceMemos[index]
                return startPlayback(state: &state, index: index, startTime: time)
            }
            return .none

        case let .playMemoAtIndex(index):
            return startPlayback(state: &state, index: index)

        case let .setPlaybackMode(mode):
            state.playbackMode = mode
            state.showingPlaybackModeSelection = false
            if mode == .shuffle {
                return .send(.view(.shufflePlaylist))
            }
            return .none

        case let .setRepeatMode(mode):
            state.repeatMode = mode
            state.showingRepeatModeSelection = false
            return .none

        case .shufflePlaylist:
            state.shuffledOrder = Array(state.voiceMemos.map { $0.url }).shuffled()
            return .none

        case .showPlaybackModeSelection:
            state.showingPlaybackModeSelection = true
            return .none

        case .hidePlaybackModeSelection:
            state.showingPlaybackModeSelection = false
            return .none

        case .showRepeatModeSelection:
            state.showingRepeatModeSelection = true
            return .none

        case .hideRepeatModeSelection:
            state.showingRepeatModeSelection = false
            return .none
        }
    }

    // MARK: - Playback Methods
    private func startPlayback(state: inout State, index: Int, startTime: TimeInterval = 0) -> Effect<Action> {
        guard index < state.voiceMemos.count else { return .none }

        // Update state
        state.isPlaying = true
        state.currentPlayingIndex = index
        state.currentTime = startTime

        // Reset all memo states
        for i in 0..<state.voiceMemos.count {
            state.voiceMemos[i].isPlaying = (i == index)
            if i != index {
                state.voiceMemos[i].currentTime = 0
            }
        }

        let memo = state.voiceMemos[index]

        return .run { send in
            await withTaskGroup(of: Void.self) { group in
                // Start playback
                group.addTask {
                    do {
                        _ = try await audioPlayer.play(memo.url, startTime, .normal, false)
                        await send(.playbackFinished)
                    } catch {
                        await send(.playbackFailed(error))
                    }
                }

                // Time updates
                group.addTask {
                    for await _ in clock.timer(interval: .milliseconds(100)) {
                        do {
                            let currentTime = try await audioPlayer.getCurrentTime()
                            await send(.playbackTimeUpdated(currentTime))
                        } catch {
                            break
                        }
                    }
                }
            }
        }
        .cancellable(id: CancelID.playback)
    }

    private func resumePlayback(state: inout State, index: Int) -> Effect<Action> {
        let currentTime = state.voiceMemos[index].currentTime
        return startPlayback(state: &state, index: index, startTime: currentTime)
    }

    private func stopPlayback(state: inout State) -> Effect<Action> {
        state.isPlaying = false
        state.currentPlayingIndex = nil
        state.currentTime = 0

        // Reset all memo states
        for i in 0..<state.voiceMemos.count {
            state.voiceMemos[i].isPlaying = false
            state.voiceMemos[i].currentTime = 0
        }

        return .cancel(id: CancelID.playback)
            .concatenate(with: .cancel(id: CancelID.timeUpdates))
    }

    private func playNextTrack(state: inout State) -> Effect<Action> {
        guard let nextIndex = state.nextMemoIndex else {
            if state.repeatMode == .all && !state.voiceMemos.isEmpty {
                // Start from beginning
                return startPlayback(state: &state, index: 0)
            }
            return stopPlayback(state: &state)
        }

        return startPlayback(state: &state, index: nextIndex)
    }

    private func playPreviousTrack(state: inout State) -> Effect<Action> {
        guard let currentIndex = state.currentPlayingIndex, currentIndex > 0 else {
            if state.repeatMode == .all && !state.voiceMemos.isEmpty {
                // Go to last track
                return startPlayback(state: &state, index: state.voiceMemos.count - 1)
            }
            return .none
        }

        return startPlayback(state: &state, index: currentIndex - 1)
    }

    private func handlePlaybackFinished(state: inout State) -> Effect<Action> {
        guard let currentIndex = state.currentPlayingIndex else { return .none }

        switch state.repeatMode {
        case .one:
            // Repeat current track
            return startPlayback(state: &state, index: currentIndex)

        case .off, .all:
            // Try to play next track
            return playNextTrack(state: &state)
        }
    }

    private func loadVoiceMemos(voices: [VoiceMemoRepository.Voice]) -> Effect<Action> {
        .run { send in
            let memos = voices.map(EnhancedVoiceMemoState.init)
            await send(.voiceMemosLoaded(memos))
        }
    }
}

// MARK: - Helper Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Playlist Error
enum PlaylistError: Error, Equatable {
    case notFound
    case networkError(String)
    case databaseError(String)
    case unknown(String)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound):
            return true
        case let (.networkError(lhsMessage), .networkError(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.databaseError(lhsMessage), .databaseError(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.unknown(lhsMessage), .unknown(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }

    static func from(_ error: Error) -> Self {
        if let error = error as? PlaylistRepositoryError {
            switch error {
            case .notFound:
                return .notFound
            default:
                return .unknown(error.localizedDescription)
            }
        } else {
            return .unknown(error.localizedDescription)
        }
    }
}

extension PlaylistError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "プレイリストが見つかりません"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .databaseError(let message):
            return "データベースエラー: \(message)"
        case .unknown(let message):
            return "不明なエラー: \(message)"
        }
    }

    var localizedDescription: String {
        errorDescription ?? "不明なエラーが発生しました"
    }
}
