//
//  ModernPlaylistListView.swift
//  VoiLog
//
//  Modern TCA implementation for playlist functionality
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct ModernPlaylistListView: View {
    @Perception.Bindable var store: StoreOf<PlaylistListFeature>

    var body: some View {
        VStack {
            List {
                ForEach(store.playlists, id: \.id) { playlist in
                    NavigationLink {
                        EnhancedPlaylistDetailView(
                            store: Store(
                                initialState: EnhancedPlaylistFeature.State(
                                    id: playlist.id,
                                    name: playlist.name,
                                    voices: [],
                                    createdAt: playlist.createdAt,
                                    updatedAt: playlist.updatedAt
                                )
                            ) {
                                EnhancedPlaylistFeature()
                            }
                        )
                    } label: {
                        PlaylistRowContent(playlist: playlist)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.send(.view(.deletePlaylist(playlist.id)))
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("プレイリスト")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.view(.createPlaylistButtonTapped))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $store.isShowingCreateSheet) {
            CreatePlaylistSheet(store: store)
        }
        .sheet(isPresented: $store.isShowingPaywall) {
            // PaywallView implementation would go here
            Text("Premium機能が必要です")
        }
        .alert("エラー", isPresented: .constant(store.error != nil)) {
            Button("OK") { }
        } message: {
            if let error = store.error {
                Text(error)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .overlay {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
}

struct PlaylistRowContent: View {
    let playlist: Playlist

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)

                Text(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PlaylistRowView: View {
    let playlist: Playlist
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)

                Text(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .swipeActions {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

struct CreatePlaylistSheet: View {
    @Perception.Bindable var store: StoreOf<PlaylistListFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("プレイリスト名", text: $store.newPlaylistName)
                }
            }
            .navigationTitle("新規プレイリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.send(.view(.createPlaylistSheetDismissed))
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        store.send(.view(.createPlaylistSubmitted))
                    }
                    .disabled(store.newPlaylistName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ModernPlaylistListView(
        store: Store(initialState: PlaylistListFeature.State()) {
            PlaylistListFeature()
        }
    )
}
