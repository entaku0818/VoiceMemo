//
//  PlaylistListFeature.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/24.
//

import Foundation
import ComposableArchitecture
struct PlaylistListFeature: Reducer {

    struct State: Equatable {
        var playlists: [Playlist] = []
        var isLoading: Bool = false
        var error: String?
        var isShowingCreateSheet: Bool = false
        var newPlaylistName: String = ""
    }

    enum Action: Equatable {
        case onAppear
        case playlistsLoaded([Playlist])
        case playlistsLoadingFailed(Error)
        case createPlaylistButtonTapped
        case createPlaylistSheetDismissed
        case updateNewPlaylistName(String)
        case createPlaylistSubmitted
        case playlistCreated(Playlist)
        case playlistCreationFailed(Error)
        case deletePlaylist(UUID)
        case playlistDeleted(UUID)
        case playlistDeletionFailed(Error)
    }

    @Dependency(\.playlistRepository) var playlistRepository

    func reduce(into state: inout State, action: Action) -> ComposableArchitecture.Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
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

        case .createPlaylistButtonTapped:
            state.isShowingCreateSheet = true
            return .none

        case .createPlaylistSheetDismissed:
            state.isShowingCreateSheet = false
            state.newPlaylistName = ""
            return .none

        case let .updateNewPlaylistName(name):
            state.newPlaylistName = name
            return .none

        case .createPlaylistSubmitted:
            // 空の名前チェック
            guard !state.newPlaylistName.isEmpty else { return .none }

            // プレイリスト数の上限チェック
            guard state.playlists.count <= 3 else {
                state.error = "プレイリストは最大3つまでしか作成できません"
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

        case let .deletePlaylist(id):
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
        }
    }

}

extension PlaylistListFeature.Action {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear),
             (.createPlaylistButtonTapped, .createPlaylistButtonTapped),
             (.createPlaylistSheetDismissed, .createPlaylistSheetDismissed),
             (.createPlaylistSubmitted, .createPlaylistSubmitted):
            return true

        case let (.playlistsLoaded(lhs), .playlistsLoaded(rhs)):
            return lhs == rhs

        case let (.playlistsLoadingFailed(lhs), .playlistsLoadingFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        case let (.updateNewPlaylistName(lhs), .updateNewPlaylistName(rhs)):
            return lhs == rhs

        case let (.playlistCreated(lhs), .playlistCreated(rhs)):
            return lhs == rhs

        case let (.playlistCreationFailed(lhs), .playlistCreationFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        case let (.deletePlaylist(lhs), .deletePlaylist(rhs)):
            return lhs == rhs

        case let (.playlistDeleted(lhs), .playlistDeleted(rhs)):
            return lhs == rhs

        case let (.playlistDeletionFailed(lhs), .playlistDeletionFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)

        default:
            return false
        }
    }
}
