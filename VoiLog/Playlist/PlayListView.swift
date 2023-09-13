//
//  PlayListView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 13.9.2023.
//

import SwiftUI
import ComposableArchitecture


struct PlayListsView: View {
    let store: Store<PlayListsState, PlayListsAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            List(viewStore.playlists) { playlist in
                Text(playlist.name)

            }
            .navigationBarTitle("プレイリスト一覧")

        }
    }
}

struct PlayListsView_Previews: PreviewProvider {
    static var previews: some View {
        let playlists = [
            PlayListState(name: "プレイリスト 1"),
            PlayListState(name: "プレイリスト 2"),
            PlayListState(name: "プレイリスト 3")
        ]

        let initialState = PlayListsState(playlists: playlists)
        let store = Store(initialState: initialState, reducer: playlistReducer, environment: ())

        return PlayListsView(store: store)
    }
}
