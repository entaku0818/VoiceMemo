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
    @ObservableState
    struct State: Equatable {
        let id: UUID
        var name: String
        var voices: [VoiceMemoRepository.Voice]
        var createdAt: Date
        var updatedAt: Date
        var isLoading: Bool = false
        var error: String?
        var isEditingName: Bool = false
        var editingName: String = ""
        var voiceMemos: IdentifiedArrayOf<VoiceMemoReducer.State> = []
        var isShowingVoiceSelection: Bool = false
        var isPlaying: Bool = false
        var currentPlayingId: VoiceMemoReducer.State.ID?
        var currentTime: TimeInterval = 0
        var playbackSpeed: AudioPlayerClient.PlaybackSpeed = .normal
        var hasPurchasedPremium: Bool = false

        var asPlaylist: Playlist {
            Playlist(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    enum Action: ViewAction, Equatable {
        case binding(BindingAction<State>)
        case dataLoaded(PlaylistDetail)
        case playlistLoadingFailed(Error)
        case nameUpdateSuccess(PlaylistDetail)
        case nameUpdateFailed(Error)
        case voiceRemoved(PlaylistDetail)
        case voiceRemovalFailed(Error)
        case voiceMemosLoaded([VoiceMemoReducer.State])
        case voiceMemosLoadFailed(Error)
        case voiceAddedToPlaylist(PlaylistDetail)
        case voiceAddFailedToPlaylist(Error)
        case voiceMemos(id: VoiceMemoReducer.State.ID, action: VoiceMemoReducer.Action)
        case view(View)
        
        enum View {
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
        }
    }

    @Dependency(\.playlistRepository) var playlistRepository
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case player }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.voilog", category: "PlaylistDetail")

    private func handleVoiceMemoDelegate(
           state: inout State,
           id: VoiceMemoReducer.State.ID,
           delegateAction: VoiceMemoReducer.Action.Delegate
       ) -> Effect<Action> {
           switch delegateAction {
           case .playbackFailed:
               logger.error("Playback Failed - ID: \(id.description)")
               state.error = "再生に失敗しました"
               state.isPlaying = false
               state.currentPlayingId = nil
               return .none

           case .playbackStarted:
               logger.debug("Playback Started - ID: \(id.description)")
               state.currentPlayingId = id
               state.isPlaying = true
               resetOtherMemos(state: &state, exceptId: id)
               return .none

           case let .playbackInProgress(currentTime):
               logger.debug("Playback Progress - ID: \(id.description), Time: \(currentTime)")
               if let index = state.voiceMemos.index(id: id) {
                   state.voiceMemos[index].time = currentTime
               }
               return .none

           case .playbackComplete:
               logger.debug("Playback Complete - ID: \(id.description)")
               if let currentId = state.currentPlayingId,
                  let currentIndex = state.voiceMemos.index(id: currentId) {
                   if currentIndex > 0 {  // 前の音声に移動
                       let nextMemoId = state.voiceMemos[currentIndex - 1].id
                       state.currentPlayingId = nextMemoId
                       return .send(.voiceMemos(id: nextMemoId, action: .playButtonTapped))
                   } else {
                       logger.debug("Reached beginning of playlist")
                       state.isPlaying = false
                       state.currentPlayingId = nil
                       if let index = state.voiceMemos.index(id: currentId) {
                           state.voiceMemos[index].time = 0
                       }
                   }
               }
               return .none
           }
       }

    private func resetOtherMemos(state: inout State, exceptId: VoiceMemoReducer.State.ID) {
        for memoID in state.voiceMemos.ids where memoID != exceptId {
            state.voiceMemos[id: memoID]?.mode = .notPlaying
            state.voiceMemos[id: memoID]?.time = 0
        }
    }

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
                            await send(.playlistLoadingFailed(error))
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
                            await send(.nameUpdateFailed(error))
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
                            await send(.voiceRemovalFailed(error))
                        }
                    }

                case .loadVoiceMemos:
                    return .run { send in
                        do {
                            let voices = voiceMemoAccessor.selectAllData().map { voice in
                                VoiceMemoReducer.State(
                                    uuid: voice.id,
                                    date: voice.createdAt,
                                    duration: voice.duration,
                                    time: 0,
                                    mode: .notPlaying,
                                    title: voice.title,
                                    url: voice.url,
                                    text: voice.text,
                                    fileFormat: voice.fileFormat,
                                    samplingFrequency: voice.samplingFrequency,
                                    quantizationBitDepth: Int(voice.quantizationBitDepth),
                                    numberOfChannels: Int(voice.numberOfChannels),
                                    hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
                                )
                            }
                            await send(.voiceMemosLoaded(voices))
                        } catch {
                            await send(.voiceMemosLoadFailed(error))
                        }
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
                            await send(.voiceAddFailedToPlaylist(error))
                        }
                    }

                case let .playButtonTapped(voiceId):
                    guard let voice = state.voices.first(where: { $0.id == voiceId }) else {
                        return .none
                    }

                    if state.voiceMemos[id: voice.url] != nil {
                        return .send(.voiceMemos(id: voice.url, action: .playButtonTapped))
                    }
                    return .none
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
                state.voiceMemos = IdentifiedArray(
                    uniqueElements: voices.map { voice in
                        VoiceMemoReducer.State(
                            uuid: voice.uuid,
                            date: voice.date,
                            duration: voice.duration,
                            time: 0,
                            mode: .notPlaying,
                            title: voice.title,
                            url: voice.url,
                            text: voice.text,
                            fileFormat: voice.fileFormat,
                            samplingFrequency: voice.samplingFrequency,
                            quantizationBitDepth: voice.quantizationBitDepth,
                            numberOfChannels: voice.numberOfChannels,
                            hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
                        )
                    }
                )
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

            case .voiceMemos(id: let id, action: let action):
                switch action {
                case let .delegate(delegateAction):
                    logger.debug("\(id.absoluteString)")
                    return handleVoiceMemoDelegate(state: &state, id: id, delegateAction: delegateAction)
                default:
                    return .none
                }
            }
        }
        .forEach(\.voiceMemos, action: /Action.voiceMemos) {
            VoiceMemoReducer()
        }
    }
}
