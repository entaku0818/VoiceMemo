//
//  PlaylistDetailView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation
import SwiftUI
import ComposableArchitecture
// MARK: - View
struct PlaylistDetailView: View {
    let store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if viewStore.isLoading {
                    ProgressView()
                } else if let error = viewStore.error {
                    VStack {
                        Text("エラーが発生しました")
                        Text(error)
                            .foregroundColor(.red)
                    }
                } else if let detail = viewStore.playlistDetail {
                    List {
                        // Playlist Name Section
                        Section {
                            if viewStore.isEditingName {
                                HStack {
                                    TextField("プレイリスト名", text: viewStore.binding(
                                        get: \.editingName,
                                        send: PlaylistDetailFeature.Action.updateName
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                    Button("保存") {
                                        viewStore.send(.saveNameButtonTapped)
                                    }
                                    .buttonStyle(.bordered)

                                    Button("キャンセル") {
                                        viewStore.send(.cancelEditButtonTapped)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                HStack {
                                    Text(detail.name)
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Button {
                                        viewStore.send(.editButtonTapped)
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                }
                            }

                            Text("作成日: \(detail.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Voices Section
                        Section("音声リスト") {
                            if detail.voices.isEmpty {
                                Text("音声が追加されていません")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(detail.voices, id: \.id) { voice in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(voice.title)
                                            .font(.headline)

                                        Text("録音日: \(voice.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            viewStore.send(.removeVoice(voice.id))
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else {
                    Text("プレイリストが見つかりません")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("プレイリストの詳細")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

// MARK: - Preview
#Preview("プレイリスト詳細") {
    let store = Store(
        initialState: PlaylistDetailFeature.State(
            id: UUID(),
            playlistDetail: PlaylistDetail(
                id: UUID(),
                name: "テストプレイリスト",
                voices: [
                    VoiceMemoRepository.Voice(
                        title: "テスト音声1",
                        url: URL(string: "file://test.m4a")!,
                        id: UUID(),
                        text: "テストテキスト",
                        createdAt: Date(),
                        updatedAt: Date(),
                        duration: 60.0,
                        fileFormat: "m4a",
                        samplingFrequency: 44100,
                        quantizationBitDepth: 16,
                        numberOfChannels: 1,
                        isCloud: false
                    )
                ],
                createdAt: Date(),
                updatedAt: Date()
            )
        ),
        reducer: {
            PlaylistDetailFeature()
                ._printChanges()
        }
    )

    return PlaylistDetailView(store: store)

}
