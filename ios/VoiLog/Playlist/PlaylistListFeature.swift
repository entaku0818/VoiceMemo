//
//  PlaylistListFeature.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/24.
//

import Foundation
import ComposableArchitecture

@Reducer
struct PlaylistListFeature {

    @ObservableState
    struct State: Equatable {
        var playlists: [Playlist] = []
        var isLoading = false
        var error: String?
        var isShowingCreateSheet = false
        var newPlaylistName: String = ""
        var hasPurchasedPremium = false
        var isShowingPaywall = false
        var isShowingVoiceSelection = false
        var selectedPlaylistForVoiceAddition: Playlist?

    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case view(View)

        // Internal actions
        case onAppear
        case playlistsLoaded([Playlist])
        case playlistsLoadingFailed(Error)
        case playlistCreated(Playlist)
        case playlistCreationFailed(Error)
        case playlistDeleted(UUID)
        case playlistDeletionFailed(Error)
        case voiceAddedToPlaylist(Playlist)
        case voiceAddFailedToPlaylist(Error)

        enum View {
            case createPlaylistButtonTapped
            case createPlaylistSheetDismissed
            case updateNewPlaylistName(String)
            case createPlaylistSubmitted
            case deletePlaylist(UUID)
            case showPaywall
            case paywallDismissed
            case playlistTapped(Playlist)
            case addVoiceToPlaylist(Playlist)
            case hideVoiceSelection
            case addVoiceToSelectedPlaylist(UUID)
        }
    }

    @Dependency(\.playlistRepository) var playlistRepository

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
        switch action {
        case .onAppear:
            state.isLoading = true
            state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct

            return .run { send in
                do {
                    let playlists = try await playlistRepository.fetchAll()
                    await send(.playlistsLoaded(playlists))
                } catch {
                    await send(.playlistsLoadingFailed(error))
                }
            }

        case let .playlistsLoaded(playlists):
            state.playlists = playlists
            state.isLoading = false
            state.error = nil
            return .none

        case let .playlistsLoadingFailed(error):
            state.isLoading = false
            state.error = error.localizedDescription
            return .none

        case .view(.createPlaylistButtonTapped):
            if !state.hasPurchasedPremium && state.playlists.count >= 3 {
                state.isShowingPaywall = true
            } else {
                state.isShowingCreateSheet = true
            }
            return .none

        case .view(.createPlaylistSheetDismissed):
            state.isShowingCreateSheet = false
            state.newPlaylistName = ""
            return .none

        case let .view(.updateNewPlaylistName(name)):
            state.newPlaylistName = name
            return .none

        case .view(.createPlaylistSubmitted):
            guard !state.newPlaylistName.isEmpty else { return .none }

            // プレミアム未購入時のプレイリスト制限チェック
            if !state.hasPurchasedPremium && state.playlists.count >= 3 {
                return .none
            }

            let name = state.newPlaylistName
            return .run { send in
                do {
                    let playlist = try await playlistRepository.create(name: name)
                    await send(.playlistCreated(playlist))
                } catch {
                    await send(.playlistCreationFailed(error))
                }
            }

        case let .playlistCreated(playlist):
            state.playlists.insert(playlist, at: 0)
            state.isShowingCreateSheet = false
            state.newPlaylistName = ""
            state.error = nil
            return .none

        case let .playlistCreationFailed(error):
            state.error = error.localizedDescription
            return .none

        case let .view(.deletePlaylist(id)):
            guard let playlist = state.playlists.first(where: { $0.id == id }) else { return .none }
            return .run { send in
                do {
                    try await playlistRepository.delete(playlist)
                    await send(.playlistDeleted(id))
                } catch {
                    await send(.playlistDeletionFailed(error))
                }
            }

        case let .playlistDeleted(id):
            state.playlists.removeAll { $0.id == id }
            return .none

        case let .playlistDeletionFailed(error):
            state.error = error.localizedDescription
            return .none
        case .view(.showPaywall):
            state.isShowingPaywall = true
            return .none

        case .view(.paywallDismissed):
            state.isShowingPaywall = false
            return .none

        case let .view(.playlistTapped(playlist)):
            // プレイリストタップ時に音声追加メニューを表示
            state.selectedPlaylistForVoiceAddition = playlist
            state.isShowingVoiceSelection = true
            return .none

        case let .view(.addVoiceToPlaylist(playlist)):
            state.selectedPlaylistForVoiceAddition = playlist
            state.isShowingVoiceSelection = true
            return .none

        case .view(.hideVoiceSelection):
            state.isShowingVoiceSelection = false
            state.selectedPlaylistForVoiceAddition = nil
            return .none

        case let .view(.addVoiceToSelectedPlaylist(voiceId)):
            guard let playlist = state.selectedPlaylistForVoiceAddition else { return .none }

            return .run { send in
                do {
                    let updatedPlaylist = try await playlistRepository.addVoice(voiceId, playlist)
                    await send(.voiceAddedToPlaylist(updatedPlaylist))
                } catch {
                    await send(.voiceAddFailedToPlaylist(error))
                }
            }

        case let .voiceAddedToPlaylist(updatedPlaylist):
            // プレイリストリストを更新
            if let index = state.playlists.firstIndex(where: { $0.id == updatedPlaylist.id }) {
                state.playlists[index] = updatedPlaylist
            }
            state.isShowingVoiceSelection = false
            state.selectedPlaylistForVoiceAddition = nil
            return .none

        case let .voiceAddFailedToPlaylist(error):
            state.error = error.localizedDescription
            return .none

        case .binding:
            return .none
        }
        }
    }

}

extension PlaylistListFeature.Action {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear):
            return true

        case (.binding, .binding):
            return true

        case let (.view(lhsView), .view(rhsView)):
            return lhsView == rhsView

        case let (.playlistsLoaded(lhs), .playlistsLoaded(rhs)):
            return lhs == rhs

        case let (.playlistsLoadingFailed(lhs), .playlistsLoadingFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        case let (.playlistCreated(lhs), .playlistCreated(rhs)):
            return lhs == rhs

        case let (.playlistCreationFailed(lhs), .playlistCreationFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        case let (.playlistDeleted(lhs), .playlistDeleted(rhs)):
            return lhs == rhs

        case let (.playlistDeletionFailed(lhs), .playlistDeletionFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        case let (.voiceAddedToPlaylist(lhs), .voiceAddedToPlaylist(rhs)):
            return lhs == rhs

        case let (.voiceAddFailedToPlaylist(lhs), .voiceAddFailedToPlaylist(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        default:
            return false
        }
    }
}

extension PlaylistListFeature.Action.View {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.createPlaylistButtonTapped, .createPlaylistButtonTapped),
             (.createPlaylistSheetDismissed, .createPlaylistSheetDismissed),
             (.createPlaylistSubmitted, .createPlaylistSubmitted),
             (.showPaywall, .showPaywall),
             (.paywallDismissed, .paywallDismissed),
             (.hideVoiceSelection, .hideVoiceSelection):
            return true

        case let (.updateNewPlaylistName(lhs), .updateNewPlaylistName(rhs)):
            return lhs == rhs

        case let (.deletePlaylist(lhs), .deletePlaylist(rhs)):
            return lhs == rhs

        case let (.playlistTapped(lhs), .playlistTapped(rhs)):
            return lhs == rhs

        case let (.addVoiceToPlaylist(lhs), .addVoiceToPlaylist(rhs)):
            return lhs == rhs

        case let (.addVoiceToSelectedPlaylist(lhs), .addVoiceToSelectedPlaylist(rhs)):
            return lhs == rhs

        default:
            return false
        }
    }
}
