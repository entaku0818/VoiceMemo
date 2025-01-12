//
//  PlaylistListFeatureTests.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2024/12/31.
//

import Foundation
import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class PlaylistListFeatureTests: XCTestCase {

    func test_onAppear_success() async {
        let playlists = [
            Playlist(id: UUID(), name: "Test Playlist 1"),
            Playlist(id: UUID(), name: "Test Playlist 2")
        ]

        let store = TestStore(
            initialState: PlaylistListFeature.State(),
            reducer: { PlaylistListFeature() }
        ) {
            $0.playlistRepository.fetchAll = { playlists }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.playlistsLoaded(playlists)) {
            $0.playlists = playlists
            $0.isLoading = false
            $0.error = nil
        }
    }
    func test_onAppear_failure() async {
        let error = NSError(domain: "test", code: 0, userInfo: nil)

        let store = TestStore(
            initialState: PlaylistListFeature.State(),
            reducer: { PlaylistListFeature() }
        ) {
            $0.playlistRepository.fetchAll = { throw error }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.playlistsLoadingFailed(error)) {
            $0.isLoading = false
            $0.error = error.localizedDescription
        }
    }

    func test_createPlaylist_success() async {
        let newPlaylist = Playlist(id: UUID(), name: "New Playlist")

        let store = TestStore(
            initialState: PlaylistListFeature.State(
                isShowingCreateSheet: true,
                newPlaylistName: "New Playlist"
            ),
            reducer: { PlaylistListFeature() }
        ) {
            $0.playlistRepository.create = { name in
                XCTAssertEqual(name, "New Playlist")
                return newPlaylist
            }
        }

        await store.send(.createPlaylistSubmitted)
        await store.receive(.playlistCreated(newPlaylist)) {
            $0.playlists.insert(newPlaylist, at: 0)
            $0.isShowingCreateSheet = false
            $0.newPlaylistName = ""
            $0.error = nil
        }
    }

    func test_createPlaylist_failure() async {
        let error = NSError(domain: "test", code: 0, userInfo: nil)

        let store = TestStore(
            initialState: PlaylistListFeature.State(
                isShowingCreateSheet: true,
                newPlaylistName: "New Playlist"
            ),
            reducer: { PlaylistListFeature() }
        ) {
            $0.playlistRepository.create = { _ in throw error }
        }

        await store.send(.createPlaylistSubmitted)
        await store.receive(.playlistCreationFailed(error)) {
            $0.error = error.localizedDescription
        }
    }

    func test_deletePlaylist_success() async {
        let playlist = Playlist(id: UUID(), name: "Test Playlist")
        let store = TestStore(
            initialState: PlaylistListFeature.State(
                playlists: [playlist]
            ),
            reducer: { PlaylistListFeature() }
        ) {
            $0.playlistRepository.delete = { playlistToDelete in
                XCTAssertEqual(playlistToDelete.id, playlist.id)
            }
        }

        await store.send(.deletePlaylist(playlist.id))
        await store.receive(.playlistDeleted(playlist.id)) {
            $0.playlists.removeAll { $0.id == playlist.id }
        }
    }

    func test_deletePlaylist_failure() async {
        let playlist = Playlist(id: UUID(), name: "Test Playlist")
        let error = NSError(domain: "test", code: 0, userInfo: nil)

        let store = TestStore(
            initialState: PlaylistListFeature.State(
                playlists: [playlist]
            ),
            reducer: { PlaylistListFeature() }
        ) {
            $0.playlistRepository.delete = { _ in throw error }
        }

        await store.send(.deletePlaylist(playlist.id))
        await store.receive(.playlistDeletionFailed(error)) {
            $0.error = error.localizedDescription
        }
    }

    func test_createPlaylistSheet_interactions() async {
        let store = TestStore(
            initialState: PlaylistListFeature.State(),
            reducer: { PlaylistListFeature() }
        )

        await store.send(.createPlaylistButtonTapped) {
            $0.isShowingCreateSheet = true
        }
        await store.send(.updateNewPlaylistName("Test Name")) {
            $0.newPlaylistName = "Test Name"
        }
        await store.send(.createPlaylistSheetDismissed) {
            $0.isShowingCreateSheet = false
            $0.newPlaylistName = ""
        }
    }

    func test_createPlaylistSubmitted_withEmptyName() async {
        let store = TestStore(
            initialState: PlaylistListFeature.State(
                isShowingCreateSheet: true,
                newPlaylistName: ""
            ),
            reducer: { PlaylistListFeature() }
        )

        await store.send(.createPlaylistSubmitted)
        // 空の名前の場合は何も起こらないことを確認
    }

    func test_createPlaylist_failsWhenLimitReached() async {
        let existingPlaylists = [
            Playlist(id: UUID(), name: "Playlist 1"),
            Playlist(id: UUID(), name: "Playlist 2"),
            Playlist(id: UUID(), name: "Playlist 3"),
            Playlist(id: UUID(), name: "Playlist 4")
        ]

        let store = TestStore(
            initialState: PlaylistListFeature.State(
                playlists: existingPlaylists,
                isShowingCreateSheet: true,
                newPlaylistName: "New Playlist"
            ),
            reducer: { PlaylistListFeature() }
        )

        await store.send(.createPlaylistButtonTapped) {
            $0.isShowingPaywall = true
        }
    }
}
