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
struct PlaylistDetailFeature: Reducer {
    struct State: Equatable {
        let id: UUID
        var playlistDetail: PlaylistDetail?
        var isLoading: Bool = false
        var error: String?
        var isEditingName: Bool = false
        var editingName: String = ""
        var voiceMemos: IdentifiedArrayOf<VoiceMemoReducer.State> = []
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
        case voiceMemos(id: VoiceMemoReducer.State.ID, action: VoiceMemoReducer.Action)
        case voiceMemosLoaded([VoiceMemoReducer.State])
        case voiceMemosLoadFailed(Error)
        case showVoiceSelectionSheet
        case hideVoiceSelectionSheet
        case addVoiceToPlaylist(UUID)
        case voiceAddedToPlaylist(PlaylistDetail)
        case voiceAddFailedToPlaylist(Error)
        case playButtonTapped(at: Int)
    }

    @Dependency(\.playlistRepository) var playlistRepository
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor
    @Dependency(\.audioPlayer) var audioPlayer
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
            state.currentPlayingIndex = nil
            return .none

        case .playbackStarted:
            logger.debug("Playback Started - ID: \(id.description)")
            if let index = state.voiceMemos.index(id: id) {
                logger.debug("Found index: \(index)")
                state.currentPlayingIndex = index
                state.isPlaying = true
                resetOtherMemos(state: &state, exceptId: id)
            } else {
                logger.error("Could not find index for ID: \(id.description)")
            }
            return .none

        case let .playbackInProgress(currentTime):
            logger.debug("Playback Progress - ID: \(id.description), Time: \(currentTime)")
            state.currentTime = currentTime
            return .none

        case .playbackComplete:
            logger.debug("Playback Complete - ID: \(id.description)")
            if let currentIndex = state.currentPlayingIndex,
               let playlist = state.playlistDetail {
                logger.debug("Current Index: \(currentIndex), Total Voices: \(playlist.voices.count)")
                if currentIndex + 1 < playlist.voices.count {
                    let nextVoice = playlist.voices[currentIndex + 1]
                    if let nextMemoId = state.voiceMemos.first(where: { $0.uuid == nextVoice.id })?.id {
                        state.currentPlayingIndex = currentIndex + 1
                        return .send(.voiceMemos(id: nextMemoId, action: .playButtonTapped))
                    }
                } else {
                    logger.debug("Reached end of playlist")
                    state.isPlaying = false
                    state.currentPlayingIndex = nil
                    state.currentTime = 0
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
                
            case .voiceMemos(id: let id, action: let action):
                switch action {
                case let .delegate(delegateAction):
                    return handleVoiceMemoDelegate(state: &state, id: id, delegateAction: delegateAction)
                default:
                    return .none
                }
        
            case let .playButtonTapped(index):
                guard let playlist = state.playlistDetail,
                      index < playlist.voices.count else { return .none }

                let voice = playlist.voices[index]
                if let voiceMemo = state.voiceMemos[id: voice.url] {
                    return .send(.voiceMemos(id: voice.url, action: .playButtonTapped))
                }
                return .none
            }
            
        }.forEach(\.voiceMemos, action: /Action.voiceMemos) {
            VoiceMemoReducer()
        }
    }
}
