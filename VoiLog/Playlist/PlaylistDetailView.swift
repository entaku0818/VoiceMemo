//
//  PlaylistDetailView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation
import SwiftUI
import ComposableArchitecture
// MARK: - PlaylistNameSection
struct PlaylistNameSection: View {
    let detail: PlaylistDetail
    let viewStore: ViewStore<PlaylistDetailFeature.State, PlaylistDetailFeature.Action>

    var body: some View {
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
    }
}

// MARK: - AddVoiceSection
struct AddVoiceSection: View {
    let viewStore: ViewStore<PlaylistDetailFeature.State, PlaylistDetailFeature.Action>

    var body: some View {
        Section {
            Button {
                viewStore.send(.showVoiceSelectionSheet)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("音声を追加")
                }
            }
        }
    }
}

// MARK: - VoiceListSection
struct VoiceListSection: View {
    let detail: PlaylistDetail
    let viewStore: ViewStore<PlaylistDetailFeature.State, PlaylistDetailFeature.Action>

    var body: some View {
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
                        Button {
                            if let index = detail.voices.firstIndex(where: { $0.id == voice.id }) {
                                viewStore.send(.playButtonTapped(at: index))
                            }
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
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
}

// MARK: - VoiceSelectionSheet
struct VoiceSelectionSheet: View {
    let detail: PlaylistDetail
    let viewStore: ViewStore<PlaylistDetailFeature.State, PlaylistDetailFeature.Action>

    var body: some View {
        NavigationView {
            List {
                ForEach(viewStore.voiceMemos, id: \.uuid) { voice in // Changed from id to uuid
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(voice.title)
                                .font(.headline)

                            HStack(spacing: 8) {
                                Label(
                                    String(format: "%.1f秒", voice.duration),
                                    systemImage: "clock"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)

                                Text("録音日: \(voice.date.formatted(date: .abbreviated, time: .shortened))") // Changed from createdAt to date
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if !detail.voices.contains(where: { $0.id == voice.uuid }) { // Changed from id to uuid
                            Button {
                                viewStore.send(.addVoiceToPlaylist(voice.uuid))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("音声を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        viewStore.send(.hideVoiceSelectionSheet)
                    }
                }
            }
        }
    }
}
struct CurrentPlayingSection: View {
    let store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                if let currentIndex = viewStore.currentPlayingIndex,
                   let detail = viewStore.playlistDetail,
                   currentIndex < detail.voices.count {
                    let currentVoice = detail.voices[currentIndex]
                    ForEachStore(
                        store.scope(
                            state: \.voiceMemos,
                            action: PlaylistDetailFeature.Action.voiceMemos
                        )
                    ) { memoStore in
                        if memoStore.withState({ $0.uuid == currentVoice.id }) {
                            PlayerView(store: memoStore)
                        }
                    }
                } else {
                    HStack {
                        Text("再生していません")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - PlaylistDetailView
struct PlaylistDetailView: View {
    let store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack(alignment: .bottom) {
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
                            PlaylistNameSection(detail: detail, viewStore: viewStore)
                            AddVoiceSection(viewStore: viewStore)
                            VoiceListSection(detail: detail, viewStore: viewStore)
                        }
                        .listStyle(InsetGroupedListStyle())
                        .sheet(
                            isPresented: viewStore.binding(
                                get: \.isShowingVoiceSelection,
                                send: PlaylistDetailFeature.Action.hideVoiceSelectionSheet
                            )
                        ) {
                            VoiceSelectionSheet(detail: detail, viewStore: viewStore)
                        }
                    } else {
                        Text("プレイリストが見つかりません")
                            .foregroundColor(.secondary)
                    }
                }

                CurrentPlayingSection(store: store)
                    .background(Color(.systemBackground))
                    .shadow(radius: 5)

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
        )
    )        {
            PlaylistDetailFeature()
                ._printChanges()
        }

    return PlaylistDetailView(store: store)

}

#Preview("プレイリスト詳細 - 再生中") {
    let store = Store(
        initialState: PlaylistDetailFeature.State(
            id: UUID(),
            playlistDetail: PlaylistDetail(
                id: UUID(),
                name: "テストプレイリスト",
                voices: [
                    .init(
                        title: "テスト音声1",
                        url: URL(string: "file://test1.m4a")!,
                        id: UUID(),
                        text: "テストテキスト1",
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
            ),
            voiceMemos: IdentifiedArrayOf(uniqueElements: [
                .init(
                    uuid: UUID(),
                    date: Date(),
                    duration: 60.0,
                    time: 30.0,
                    mode: .playing(progress: 0.5),
                    title: "テスト音声1",
                    url: URL(string: "file://test1.m4a")!,
                    text: "テストテキスト1",
                    fileFormat: "m4a",
                    samplingFrequency: 44100,
                    quantizationBitDepth: 16,
                    numberOfChannels: 1,
                    hasPurchasedPremium: false
                )
            ]),
            isPlaying: true,
            currentPlayingIndex: 0,
            currentTime: 30.0
        )
    ) {
        PlaylistDetailFeature()
            .forEach(\.voiceMemos, action: /PlaylistDetailFeature.Action.voiceMemos) {
                VoiceMemoReducer()
            }
            ._printChanges()
    }

    return PlaylistDetailView(store: store)
}


#Preview {
    let urlId = UUID()
    let url = URL(string: "file://test1.m4a")!
    let store = Store(
        initialState: PlaylistDetailFeature.State(
            id: UUID(),
            playlistDetail: PlaylistDetail(
                id: UUID(),
                name: "テストプレイリスト",
                voices: [
                    .init(
                        title: "テスト音声1",
                        url: url,
                        id: urlId,
                        text: "テストテキスト1",
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
            ),
            voiceMemos: IdentifiedArrayOf(uniqueElements: [
                .init(
                    uuid: urlId,
                    date: Date(),
                    duration: 60.0,
                    time: 30.0,
                    mode: .playing(progress: 0.5),
                    title: "テスト音声1",
                    url: url,
                    text: "テストテキスト1",
                    fileFormat: "m4a",
                    samplingFrequency: 44100,
                    quantizationBitDepth: 16,
                    numberOfChannels: 1,
                    hasPurchasedPremium: false
                )
            ]),
            isPlaying: true,
            currentPlayingIndex: 0,
            currentTime: 30.0
        )
    ) {
        PlaylistDetailFeature()
            .forEach(\.voiceMemos, action: /PlaylistDetailFeature.Action.voiceMemos) {
                VoiceMemoReducer()
            }
    }

    return CurrentPlayingSection(store: store)
}
