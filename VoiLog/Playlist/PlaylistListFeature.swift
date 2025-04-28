//
//  PlaylistListFeature.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/24.
//

import Foundation
import ComposableArchitecture
import Observation

@Reducer
struct PlaylistListFeature {
    @ObservableState
    struct State: Equatable {
        var playlists: [Playlist] = []
        var isLoading: Bool = false
        var error: String?
        var isShowingCreateSheet: Bool = false
        var newPlaylistName: String = ""
        var hasPurchasedPremium: Bool = false
        var isShowingPaywall: Bool = false
    }

    enum Action: Equatable {
        case view(View)
        case binding(BindingAction<State>)
        
        enum View: Equatable {
            case onAppear
            case createPlaylistButtonTapped
            case createPlaylistSheetDismissed
            case createPlaylistSubmitted
            case deletePlaylist(UUID)
            case showPaywall
            case paywallDismissed
        }
        
        case playlistsLoaded([Playlist])
        case playlistsLoadingFailed(Error)
        case updateNewPlaylistName(String)
        case playlistCreated(Playlist)
        case playlistCreationFailed(Error)
        case playlistDeleted(UUID)
        case playlistDeletionFailed(Error)
    }

    @Dependency(\.playlistRepository) var playlistRepository

    func reduce(into state: inout State, action: Action) -> ComposableArchitecture.Effect<Action> {
        switch action {
        case let .view(viewAction):
            switch viewAction {
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
                
            case .createPlaylistButtonTapped:
                if !state.hasPurchasedPremium && state.playlists.count >= 3 {
                    state.isShowingPaywall = true
                } else {
                    state.isShowingCreateSheet = true
                }
                return .none
                
            case .createPlaylistSheetDismissed:
                state.isShowingCreateSheet = false
                state.newPlaylistName = ""
                return .none
                
            case .createPlaylistSubmitted:
                guard !state.newPlaylistName.isEmpty else { return .none }
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
                
            case .showPaywall:
                state.isShowingPaywall = true
                return .none
                
            case .paywallDismissed:
                state.isShowingPaywall = false
                return .none
            }
            
        case let .binding(bindingAction):
            return .none
            
        case let .playlistsLoaded(playlists):
            state.playlists = playlists
            state.isLoading = false
            state.error = nil
            return .none
            
        case let .playlistsLoadingFailed(error):
            state.isLoading = false
            state.error = error.localizedDescription
            return .none
            
        case let .updateNewPlaylistName(name):
            state.newPlaylistName = name
            return .none
            
        case let .playlistCreated(playlist):
            state.playlists.insert(playlist, at: 0)
            state.isShowingCreateSheet = false
            state.newPlaylistName = ""
            state.error = nil
            return .none
            
        case let .playlistCreationFailed(error):
            state.error = error.localizedDescription
            return .none
            
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
        case let (.view(lhsView), .view(rhsView)):
            return lhsView == rhsView
            
        case let (.binding(lhsBinding), .binding(rhsBinding)):
            return lhsBinding == rhsBinding
            
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
            
        case let (.playlistDeleted(lhs), .playlistDeleted(rhs)):
            return lhs == rhs
            
        case let (.playlistDeletionFailed(lhs), .playlistDeletionFailed(rhs)):
            return (lhs as NSError) == (rhs as NSError)
            
        default:
            return false
        }
    }
}

extension PlaylistListFeature.Action.View {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear),
             (.createPlaylistButtonTapped, .createPlaylistButtonTapped),
             (.createPlaylistSheetDismissed, .createPlaylistSheetDismissed),
             (.createPlaylistSubmitted, .createPlaylistSubmitted),
             (.showPaywall, .showPaywall),
             (.paywallDismissed, .paywallDismissed):
            return true
            
        case let (.deletePlaylist(lhs), .deletePlaylist(rhs)):
            return lhs == rhs
            
        default:
            return false
        }
    }
}
