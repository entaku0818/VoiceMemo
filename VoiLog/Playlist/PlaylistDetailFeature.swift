//
//  PlaylistDetailFeture.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation

import ComposableArchitecture
import SwiftUI

// MARK: - Feature
struct PlaylistDetailFeature: Reducer {
    struct State: Equatable {
        let id: UUID
        var playlistDetail: PlaylistDetail?
        var isLoading: Bool = false
        var error: String?
        var isEditingName: Bool = false
        var editingName: String = ""
        var voiceMemos: [VoiceMemoRepository.Voice] = []
        var isShowingVoiceSelection: Bool = false
        var isPlaying: Bool = false
        var currentPlayingIndex: Int?
        var currentTime: TimeInterval = 0
        var playbackSpeed: AudioPlayerClient.PlaybackSpeed = .normal
    }

    enum Action {
        case onAppear
        case playlistDetailLoaded(PlaylistDetail)
        case playlistLoadingFailed(Error)
        case editButtonTapped
        case updateName(String)
        case saveNameButtonTapped
        case nameUpdateSuccess(PlaylistDetail)
        case nameUpdateFailed(Error)
        case cancelEditButtonTapped
        case removeVoice(UUID)
        case voiceRemoved(PlaylistDetail)
        case voiceRemovalFailed(Error)
        case loadVoiceMemos
        case voiceMemosLoaded([VoiceMemoRepository.Voice])
        case voiceMemosLoadFailed(Error)
        case showVoiceSelectionSheet
        case hideVoiceSelectionSheet
        case addVoiceToPlaylist(UUID)
        case voiceAddedToPlaylist(PlaylistDetail)
        case voiceAddFailedToPlaylist(Error)
        case playAllButtonTapped
       case pauseButtonTapped
       case playNextVoice
       case playbackFinished(Bool)
       case updatePlaybackTime(TimeInterval)
       case changePlaybackSpeed
    }

    @Dependency(\.playlistRepository) var playlistRepository
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case player }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [id = state.id] send in
                    do {
                        guard let detail = try await playlistRepository.fetch(by: id) else {
                            throw PlaylistRepositoryError.notFound
                        }
                        await send(.playlistDetailLoaded(detail))
                    } catch {
                        await send(.playlistLoadingFailed(error))
                    }
                }

            case let .playlistDetailLoaded(detail):
                state.playlistDetail = detail
                state.isLoading = false
                state.error = nil
                return .none

            case let .playlistLoadingFailed(error):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .editButtonTapped:
                state.isEditingName = true
                if let currentName = state.playlistDetail?.name {
                    state.editingName = currentName
                }
                return .none

            case let .updateName(name):
                state.editingName = name
                return .none

            case .saveNameButtonTapped:
                guard let playlist = state.playlistDetail else { return .none }
                let newName = state.editingName

                return .run { send in
                    do {
                        let updated = try await playlistRepository.update(playlist.asPlaylist, name: newName)
                        guard let detail = try await playlistRepository.fetch(by: updated.id) else {
                            throw PlaylistRepositoryError.notFound
                        }
                        await send(.nameUpdateSuccess(detail))
                    } catch {
                        await send(.nameUpdateFailed(error))
                    }
                }

            case let .nameUpdateSuccess(detail):
                state.playlistDetail = detail
                state.isEditingName = false
                state.editingName = ""
                return .none

            case let .nameUpdateFailed(error):
                state.error = error.localizedDescription
                return .none

            case .cancelEditButtonTapped:
                state.isEditingName = false
                state.editingName = ""
                return .none

            case let .removeVoice(voiceId):
                guard let playlist = state.playlistDetail else { return .none }

                return .run { send in
                    do {
                        let updated = try await playlistRepository.removeVoice(voiceId: voiceId, from: playlist.asPlaylist)
                        guard let detail = try await playlistRepository.fetch(by: updated.id) else {
                            throw PlaylistRepositoryError.notFound
                        }
                        await send(.voiceRemoved(detail))
                    } catch {
                        await send(.voiceRemovalFailed(error))
                    }
                }

            case let .voiceRemoved(detail):
                state.playlistDetail = detail
                return .none

            case let .voiceRemovalFailed(error):
                state.error = error.localizedDescription
                return .none
            case .loadVoiceMemos:
                return .run { send in
                    do {
                        let voices = voiceMemoAccessor.selectAllData()
                        await send(.voiceMemosLoaded(voices))
                    } catch {
                        await send(.voiceMemosLoadFailed(error))
                    }
                }

            case let .voiceMemosLoaded(voices):
                state.voiceMemos = voices
                return .none

            case let .voiceMemosLoadFailed(error):
                state.error = error.localizedDescription
                return .none

            case .showVoiceSelectionSheet:
                state.isShowingVoiceSelection = true
                return .send(.loadVoiceMemos)

            case .hideVoiceSelectionSheet:
                state.isShowingVoiceSelection = false
                return .none

            case let .addVoiceToPlaylist(voiceId):
                guard let playlist = state.playlistDetail else { return .none }

                return .run { send in
                    do {
                        let updated = try await playlistRepository.addVoice(voiceId: voiceId, to: playlist.asPlaylist)
                        guard let detail = try await playlistRepository.fetch(by: updated.id) else {
                            throw PlaylistRepositoryError.notFound
                        }
                        await send(.voiceAddedToPlaylist(detail))
                    } catch {
                        await send(.voiceAddFailedToPlaylist(error))
                    }
                }

            case let .voiceAddedToPlaylist(detail):
                state.playlistDetail = detail
                return .none

            case let .voiceAddFailedToPlaylist(error):
                state.error = error.localizedDescription
                return .none

            case let .voiceRemoved(detail):
                state.playlistDetail = detail
                return .send(.loadVoiceMemos) // 音声削除後に一覧を更新

            case .playAllButtonTapped:
                     guard let playlist = state.playlistDetail, !playlist.voices.isEmpty else { return .none }
                     state.isPlaying = true
                     state.currentPlayingIndex = 0

                     return .run { [voices = playlist.voices, speed = state.playbackSpeed] send in
                         let voice = voices[0]
                         do {
                             let result = try await audioPlayer.play(voice.url, 0, speed, false)
                             await send(.playbackFinished(result))

                             for await _ in clock.timer(interval: .seconds(0.5)) {
                                 let currentTime = try await audioPlayer.getCurrentTime()
                                 await send(.updatePlaybackTime(currentTime))
                             }
                         } catch {
                             await send(.playbackFinished(false))
                         }
                     }
                     .cancellable(id: CancelID.player)

                 case .pauseButtonTapped:
                     state.isPlaying = false
                     return .run { _ in
                         _ = try await audioPlayer.stop()
                     }
                     .cancellable(id: CancelID.player)

                 case .playNextVoice:
                     guard let playlist = state.playlistDetail,
                           let currentIndex = state.currentPlayingIndex,
                           currentIndex + 1 < playlist.voices.count
                     else {
                         state.isPlaying = false
                         state.currentPlayingIndex = nil
                         state.currentTime = 0
                         return .none
                     }

                     state.currentPlayingIndex = currentIndex + 1
                     let nextVoice = playlist.voices[currentIndex + 1]

                     return .run { [speed = state.playbackSpeed] send in
                         let result = try await audioPlayer.play(nextVoice.url, 0, speed, false)
                         await send(.playbackFinished(result))
                     }
                     .cancellable(id: CancelID.player)

                 case let .playbackFinished(success):
                     if success {
                         return .send(.playNextVoice)
                     }
                     state.isPlaying = false
                     state.currentPlayingIndex = nil
                     state.currentTime = 0
                     return .none

                 case let .updatePlaybackTime(time):
                     state.currentTime = time
                     return .none

                 case .changePlaybackSpeed:
                     state.playbackSpeed = state.playbackSpeed.next()
                     if state.isPlaying {
                         return .send(.pauseButtonTapped)
                     }
                     return .none
            }
        }
    }
}
