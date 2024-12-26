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
        var voiceMemos: [VoiceMemoRepository.Voice] = [] // 追加
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
    }

    @Dependency(\.playlistRepository) var playlistRepository
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor

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
            }
        }
    }
}

