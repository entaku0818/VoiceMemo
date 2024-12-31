//
//  PlaylistListView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/24.
//

import Foundation
import SwiftUI
import ComposableArchitecture
// MARK: - View
// MARK: - PlaylistListContent
struct PlaylistListContent: View {
    let viewStore: ViewStore<PlaylistListFeature.State, PlaylistListFeature.Action>

    var body: some View {
        List {
            ForEach(viewStore.playlists, id: \.id) { playlist in
                NavigationLink(
                    destination: PlaylistDetailView(
                        store: Store(
                            initialState: PlaylistDetailFeature.State(
                                id: playlist.id,
                                name: playlist.name,
                                voices: [],
                                createdAt: playlist.createdAt,
                                updatedAt: playlist.updatedAt
                            )
                        ) {
                            PlaylistDetailFeature()
                        }
                    )
                ) {
                    PlaylistRow(playlist: playlist)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        viewStore.send(.deletePlaylist(playlist.id))
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - PlaylistListToolbar
struct PlaylistListToolbar: ToolbarContent {
    let viewStore: ViewStore<PlaylistListFeature.State, PlaylistListFeature.Action>

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewStore.send(.createPlaylistButtonTapped)
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - PlaylistListView
struct PlaylistListView: View {
    let store: StoreOf<PlaylistListFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                PlaylistListContent(viewStore: viewStore)
                    .navigationTitle("プレイリスト")
                    .toolbar {
                        PlaylistListToolbar(viewStore: viewStore)
                    }
                    .sheet(
                        isPresented: viewStore.binding(
                            get: \.isShowingCreateSheet,
                            send: { $0 ? .createPlaylistButtonTapped : .createPlaylistSheetDismissed }
                        )
                    ) {
                        CreatePlaylistView(store: store)
                    }
            }
            .onAppear { viewStore.send(.onAppear) }
        }
    }
}

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playlist.name)
                .font(.headline)

            HStack {
                Text(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreatePlaylistView: View {
    let store: StoreOf<PlaylistListFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        TextField("プレイリスト名", text: viewStore.binding(
                            get: \.newPlaylistName,
                            send: PlaylistListFeature.Action.updateNewPlaylistName
                        ))
                    }
                }
                .navigationTitle("新規プレイリスト")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            viewStore.send(.createPlaylistSheetDismissed)
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("作成") {
                            viewStore.send(.createPlaylistSubmitted)
                        }
                        .disabled(viewStore.newPlaylistName.isEmpty)
                    }
                }
            }
        }
    }
}

#Preview {
    PlaylistListView(
        store: Store(
            initialState: PlaylistListFeature.State()
        )            {
                PlaylistListFeature()
                    ._printChanges()
            }
    )

}
