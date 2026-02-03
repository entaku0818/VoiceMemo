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
                           destination: EnhancedPlaylistDetailView(
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
                       ) {
                           PlaylistRow(playlist: playlist)
                       }
                       .swipeActions {
                           Button {
                               viewStore.send(.view(.addVoiceToPlaylist(playlist)))
                           } label: {
                               Label("音声追加", systemImage: "plus")
                           }
                           .tint(.blue)

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
           .sheet(isPresented: viewStore.binding(
               get: \.isShowingVoiceSelection,
               send: PlaylistListFeature.Action.view(.hideVoiceSelection)
           )) {
               if let playlist = viewStore.selectedPlaylistForVoiceAddition {
                   PlaylistVoiceSelectionView(
                       playlistName: playlist.name,
                       onVoiceSelected: { voiceId in
                           viewStore.send(.view(.addVoiceToSelectedPlaylist(voiceId)))
                       },
                       onCancel: {
                           viewStore.send(.view(.hideVoiceSelection))
                       }
                   )
               }
           }
           .onAppear { viewStore.send(.onAppear) }
       }
   }
}

struct PlaylistRow: View {
    let playlist: Playlist
    let onTap: (() -> Void)?

    init(playlist: Playlist, onTap: (() -> Void)? = nil) {
        self.playlist = playlist
        self.onTap = onTap
    }

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
                        Menu {
                            Button("作成のみ") {
                                viewStore.send(.view(.createPlaylistSubmitted))
                            }

                            Button("作成して音声追加") {
                                viewStore.send(.view(.createPlaylistSubmitted))
                                // 作成後に音声選択を表示するために少し遅延
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let newPlaylist = viewStore.playlists.first {
                                        viewStore.send(.view(.addVoiceToPlaylist(newPlaylist)))
                                    }
                                }
                            }
                        } label: {
                            Text("作成")
                        }
                        .disabled(viewStore.newPlaylistName.isEmpty)
                    }
                }
            }
        }
    }
}

struct PlaylistVoiceSelectionView: View {
    let playlistName: String
    let onVoiceSelected: (UUID) -> Void
    let onCancel: () -> Void

    @State private var availableVoices: [VoiceMemoRepository.Voice] = []
    @State private var searchQuery = ""
    @State private var isLoading = true
    @Dependency(\.voiceMemoCoredataAccessor) var voiceMemoAccessor

    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                searchBar

                // Voice List
                voiceList
            }
            .navigationTitle("「\(playlistName)」に追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル", action: onCancel)
                }
            }
            .onAppear {
                loadVoices()
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("録音を検索...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal)
    }

    private var voiceList: some View {
        List {
            ForEach(filteredVoices, id: \.id) { voice in
                VoiceSelectionRowForPlaylist(voice: voice) {
                    onVoiceSelected(voice.id)
                    onCancel()
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            } else if filteredVoices.isEmpty {
                Text("録音ファイルがありません")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private var filteredVoices: [VoiceMemoRepository.Voice] {
        if searchQuery.isEmpty {
            return availableVoices
        } else {
            return availableVoices.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.text.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    private func loadVoices() {
        Task {
            let voices = voiceMemoAccessor.selectAllData()
            await MainActor.run {
                self.availableVoices = voices
                self.isLoading = false
            }
        }
    }
}

struct VoiceSelectionRowForPlaylist: View {
    let voice: VoiceMemoRepository.Voice
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.title.isEmpty ? "無題の録音" : voice.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    HStack {
                        Text(formatDate(voice.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(formatDuration(voice.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    if !voice.text.isEmpty {
                        Text(voice.text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
