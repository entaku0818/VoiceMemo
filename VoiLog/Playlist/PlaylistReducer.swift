//
//  PlaylistReducer.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 13.9.2023.
//

import Foundation
import ComposableArchitecture

struct PlayListsState: Equatable {
    static func == (lhs: PlayListsState, rhs: PlayListsState) -> Bool {
        lhs.playlists.first?.id == rhs.playlists.first?.id
    }

    var playlists: [PlayListState]
}

struct PlayListState: Identifiable {
    let id = UUID()
    let name: String
}
enum PlayListsAction {
    case startLoading
    case playlistTapped(Playlist)
}

let playlistReducer = Reducer<PlayListsState, PlayListsAction, Void> { state, action, _ in
    switch action {
    case .playlistTapped(let playlist):
        // プレイリストがタップされたときの処理を追加できます
        // ここでは何も行いません
        return .none
    case .startLoading:
        return .none
    }
}
