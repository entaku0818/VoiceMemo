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
struct PlaylistListView: View {
   let store: StoreOf<PlaylistListFeature>
    let admobUnitId: String

   var body: some View {
       WithViewStore(store, observe: { $0 }) { viewStore in
           VStack {
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
                               }, admobUnitId: admobUnitId
                           )
                       ) {
                           PlaylistRow(playlist: playlist)
                       }
                       .swipeActions {
                           Button(role: .destructive) {
                               viewStore.send(.view(.deletePlaylist(playlist.id)))
                           } label: {
                               Label("削除", systemImage: "trash")
                           }
                       }
                   }
               }

               if !viewStore.hasPurchasedPremium {
                   AdmobBannerView(unitId: admobUnitId)
                       .frame(height: 50)
               }
           }
           .navigationTitle("プレイリスト")
           .toolbar {
               ToolbarItem(placement: .navigationBarTrailing) {
                   Button {
                       viewStore.send(.view(.createPlaylistButtonTapped))
                   } label: {
                       Image(systemName: "plus")
                   }
               }
           }
           .sheet(
               isPresented: viewStore.binding(
                   get: \.isShowingCreateSheet,
                   send: { $0 ? .view(.createPlaylistButtonTapped) : .view(.createPlaylistSheetDismissed) }
               )
           ) {
               CreatePlaylistView(store: store)
           }
           .sheet(isPresented: viewStore.binding(
               get: \.isShowingPaywall,
               send: PlaylistListFeature.Action.view(.paywallDismissed)
           )) {
               PaywallView(purchaseManager: PurchaseManager.shared)
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
                            send: { PlaylistListFeature.Action.view(.updateNewPlaylistName($0)) }
                        ))
                    }
                }
                .navigationTitle("新規プレイリスト")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            viewStore.send(.view(.createPlaylistSheetDismissed))
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("作成") {
                            viewStore.send(.view(.createPlaylistSubmitted))
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
        ) {
                PlaylistListFeature()
                    ._printChanges()
        }, admobUnitId: ""
    )

}
