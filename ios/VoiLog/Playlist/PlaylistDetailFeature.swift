//
//  PlaylistDetailFeture.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation
import ComposableArchitecture
import SwiftUI
import OSLog

// MARK: - Feature
@Reducer
struct PlaylistDetailFeature {
    // MARK: - VoiceMemo Model
    struct VoiceMemo: Identifiable, Equatable {
        var id: UUID
        var title: String
        var date: Date
        var duration: TimeInterval
        var url: URL
        var text: String
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int

        init(
            id: UUID,
            title: String,
            date: Date,
            duration: TimeInterval,
            url: URL,
            text: String = "",
            fileFormat: String = "",
            samplingFrequency: Double = 44100.0,
            quantizationBitDepth: Int = 16,
            numberOfChannels: Int = 2
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
        }
    }

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

    enum PlaybackState: Equatable {
        case idle
        case playing
        case paused
    }

    @ObservableState
    struct State: Equatable {
        let id: UUID
        var name: String
        var voices: [VoiceMemoRepository.Voice]
        var createdAt: Date
        var updatedAt: Date
        var isLoading = false
        var error: String?
        var isEditingName = false
        var editingName: String = ""
        var voiceMemos: IdentifiedArrayOf<VoiceMemo> = []
        var isShowingVoiceSelection = false
        var playbackState: PlaybackState = .idle
        var currentPlayingId: URL?
        var currentTime: TimeInterval = 0
        var playbackSpeed: AudioPlayerClient.PlaybackSpeed = .normal
        var hasPurchasedPremium = false

        var asPlaylist: Playlist {
            Playlist(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    enum Action: BindableAction {

        case binding(BindingAction<State>)
        case dataLoaded(PlaylistDetail)
        case playlistLoadingFailed(PlaylistError)
        case nameUpdateSuccess(PlaylistDetail)
        case nameUpdateFailed(PlaylistError)
        case voiceRemoved(PlaylistDetail)
        case voiceRemovalFailed(PlaylistError)
        case voiceMemosLoaded([VoiceMemo])
        case voiceMemosLoadFailed(PlaylistError)
        case voiceAddedToPlaylist(PlaylistDetail)
        case voiceAddFailedToPlaylist(PlaylistError)
        case playbackTimeUpdated(TimeInterval)
        case playbackFinished
        case view(View)

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
            case playButtonTapped(UUID)
            case stopButtonTapped
        }
    }

    @Dependency(\.playlistRepository) var playlistRepository
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor
    @Dependency(\.continuousClock) var clock
    @Dependency(\.audioPlayer) var audioPlayer

    private enum CancelID { case playback }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.voilog", category: "PlaylistDetail")

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    state.isLoading = true
                    state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct

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
                    return .run { send in
                        let voiceData = await MainActor.run {
                            voiceMemoAccessor.selectAllData()
                        }
                        let voices = voiceData.map { voice in
                            VoiceMemo(
                                id: voice.id,
                                title: voice.title,
                                date: voice.createdAt,
                                duration: voice.duration,
                                url: voice.url,
                                text: voice.text,
                                fileFormat: voice.fileFormat,
                                samplingFrequency: voice.samplingFrequency,
                                quantizationBitDepth: Int(voice.quantizationBitDepth),
                                numberOfChannels: Int(voice.numberOfChannels)
                            )
                        }
                        await send(.voiceMemosLoaded(voices))
                    }

                case .showVoiceSelectionSheet:
                    state.isShowingVoiceSelection = true
                    return .send(.view(.loadVoiceMemos))

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

                case let .playButtonTapped(voiceId):
                    // 同じ音声が選択された場合は停止、異なる場合は再生開始
                    if let currentId = state.currentPlayingId,
                       state.voices.first(where: { $0.id == voiceId })?.url == currentId {
                        // 停止
                        state.playbackState = .idle
                        state.currentPlayingId = nil
                        state.currentTime = 0
                        return .run { _ in
                            try await audioPlayer.stop()
                        }
                        .cancellable(id: CancelID.playback, cancelInFlight: true)
                    } else {
                        // 新しい音声を再生
                        guard let voice = state.voices.first(where: { $0.id == voiceId }) else {
                            return .none
                        }
                        state.playbackState = .playing
                        state.currentPlayingId = voice.url
                        state.currentTime = 0
                        return startPlayback(url: voice.url)
                    }

                case .stopButtonTapped:
                    state.playbackState = .idle
                    state.currentPlayingId = nil
                    state.currentTime = 0
                    return .run { _ in
                        try await audioPlayer.stop()
                    }
                    .cancellable(id: CancelID.playback, cancelInFlight: true)
                }

            case let .dataLoaded(detail):
                state.name = detail.name
                state.voices = detail.voices
                state.createdAt = detail.createdAt
                state.updatedAt = detail.updatedAt
                state.isLoading = false
                state.error = nil
                return .none

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
                state.name = detail.name
                state.voices = detail.voices
                state.updatedAt = detail.updatedAt
                return .none

            case let .voiceRemovalFailed(error):
                state.error = error.localizedDescription
                return .none

            case let .voiceMemosLoaded(voices):
                state.voiceMemos = IdentifiedArray(uniqueElements: voices)
                return .none

            case let .voiceMemosLoadFailed(error):
                state.error = error.localizedDescription
                return .none

            case let .voiceAddedToPlaylist(detail):
                state.name = detail.name
                state.voices = detail.voices
                state.updatedAt = detail.updatedAt
                return .none

            case let .voiceAddFailedToPlaylist(error):
                state.error = error.localizedDescription
                return .none

            case let .playbackTimeUpdated(time):
                state.currentTime = time
                return .none

            case .playbackFinished:
                // プレイリストの次の音声を自動再生
                if let currentId = state.currentPlayingId,
                   let currentIndex = state.voices.firstIndex(where: { $0.url == currentId }),
                   currentIndex > 0 {
                    let nextVoice = state.voices[currentIndex - 1]
                    state.currentPlayingId = nextVoice.url
                    state.currentTime = 0
                    return startPlayback(url: nextVoice.url)
                } else {
                    // プレイリストの最初に到達したら停止
                    state.playbackState = .idle
                    state.currentPlayingId = nil
                    state.currentTime = 0
                    return .none
                }
            }
        }
    }

    private func startPlayback(url: URL) -> Effect<Action> {
        .run { send in
            // 音声再生開始
            async let playback: Void = {
                do {
                    _ = try await audioPlayer.play(url, 0, .normal, false)
                    await send(.playbackFinished)
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
                        break
                    }
                }
            }()

            _ = await (playback, timeUpdates)
        }
        .cancellable(id: CancelID.playback, cancelInFlight: true)
    }
}
