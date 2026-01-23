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
    let name: String
    @Perception.Bindable var store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        Section {
            if store.isEditingName {
                HStack {
                    TextField("プレイリスト名", text: $store.editingName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("保存") {
                        store.send(.view(.saveNameButtonTapped))
                    }
                    .buttonStyle(.bordered)

                    Button("キャンセル") {
                        store.send(.view(.cancelEditButtonTapped))
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack {
                    Text(name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        store.send(.view(.editButtonTapped))
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }

            Text("作成日: \(store.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - AddVoiceSection
struct AddVoiceSection: View {
    let store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        Section {
            Button {
                store.send(.view(.showVoiceSelectionSheet))
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
    let voices: [VoiceMemoRepository.Voice]
    let store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        Section("音声リスト") {
            if voices.isEmpty {
                Text("音声が追加されていません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(voices, id: \.id) { voice in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(voice.title)
                            .font(.headline)

                        Text("録音日: \(voice.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            store.send(.view(.playButtonTapped(voice.id)))
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.send(.view(.removeVoice(voice.id)))
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
    let voices: [VoiceMemoRepository.Voice]
    let store: StoreOf<PlaylistDetailFeature>

    var body: some View {
        NavigationView {
            List {
                ForEach(store.voiceMemos) { voice in
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

                                Text("録音日: \(voice.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if !voices.contains(where: { $0.id == voice.id }) {
                            Button {
                                store.send(.view(.addVoiceToPlaylist(voice.id)))
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
                        store.send(.view(.hideVoiceSelectionSheet))
                    }
                }
            }
        }
    }
}

// MARK: - CurrentPlayingSection
struct CurrentPlayingSection: View {
    let store: StoreOf<PlaylistDetailFeature>

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            if let currentId = store.currentPlayingId,
               let currentVoice = store.voices.first(where: { $0.url == currentId }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentVoice.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(currentVoice.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        store.send(.view(.stopButtonTapped))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    ProgressView(value: store.currentTime, total: currentVoice.duration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))

                    HStack {
                        Text(formatDuration(store.currentTime))
                            .font(.caption)
                            .monospacedDigit()

                        Spacer()

                        Text(formatDuration(currentVoice.duration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                HStack(spacing: 32) {
                    Button {
                        store.send(.view(.playButtonTapped(currentVoice.id)))
                    } label: {
                        Image(systemName: store.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.bottom, 8)
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

// MARK: - PlaylistDetailView
struct PlaylistDetailView: View {
    @Perception.Bindable var store: StoreOf<PlaylistDetailFeature>
    var admobUnitId: String

    private func send(_ action: PlaylistDetailFeature.Action.View) {
        store.send(.view(action))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if store.isLoading {
                    ProgressView()
                } else if let error = store.error {
                    VStack {
                        Text("エラーが発生しました")
                        Text(error)
                            .foregroundColor(.red)
                    }
                } else {
                    List {
                        PlaylistNameSection(
                            name: store.name,
                            store: store
                        )
                        AddVoiceSection(store: store)
                        VoiceListSection(
                            voices: store.voices,
                            store: store
                        )
                    }
                    .listStyle(InsetGroupedListStyle())
                    .sheet(
                        isPresented: $store.isShowingVoiceSelection
                    ) {
                        VoiceSelectionSheet(
                            voices: store.voices,
                            store: store
                        )
                    }
                }
            }

            VStack(spacing: 0) {
                // プレーヤーセクション
                CurrentPlayingSection(store: store)
                    .background(Color(.systemBackground))
                    .shadow(radius: 5)

                // AdMobバナー（必要なスペースを確保）
                if !store.hasPurchasedPremium {
                    AdmobBannerView(unitId: admobUnitId)
                        .frame(height: 50)
                }
            }
            .padding(.bottom, 0)
        }
        .navigationTitle("プレイリストの詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            send(.onAppear)
            send(.loadVoiceMemos)
        }
    }
}

// MARK: - Preview
#Preview("プレイリスト詳細") {
    let store = Store(
        initialState: PlaylistDetailFeature.State(
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
    ) {
        PlaylistDetailFeature()
            ._printChanges()
    }

    return PlaylistDetailView(store: store, admobUnitId: "")
}

#Preview("プレイリスト詳細 - 再生中") {
    let voiceId = UUID()
    let url = URL(string: "file://test1.m4a")!
    let store = Store(
        initialState: PlaylistDetailFeature.State(
            id: UUID(),
            name: "テストプレイリスト",
            voices: [
                .init(
                    title: "テスト音声1",
                    url: url,
                    id: voiceId,
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
            updatedAt: Date(),
            voiceMemos: IdentifiedArrayOf(uniqueElements: [
                PlaylistDetailFeature.VoiceMemo(
                    id: voiceId,
                    title: "テスト音声1",
                    date: Date(),
                    duration: 60.0,
                    url: url,
                    text: "テストテキスト1",
                    fileFormat: "m4a",
                    samplingFrequency: 44100,
                    quantizationBitDepth: 16,
                    numberOfChannels: 1
                )
            ]),
            playbackState: .playing,
            currentPlayingId: url,
            currentTime: 30.0
        )
    ) {
        PlaylistDetailFeature()
            ._printChanges()
    }

    return PlaylistDetailView(store: store, admobUnitId: "")
}

#Preview("現在再生中セクション") {
    let urlId = UUID()
    let url = URL(string: "file://test1.m4a")!
    let store = Store(
        initialState: PlaylistDetailFeature.State(
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
            updatedAt: Date(),
            voiceMemos: IdentifiedArrayOf(uniqueElements: [
                PlaylistDetailFeature.VoiceMemo(
                    id: urlId,
                    title: "テスト音声1",
                    date: Date(),
                    duration: 60.0,
                    url: url,
                    text: "テストテキスト1",
                    fileFormat: "m4a",
                    samplingFrequency: 44100,
                    quantizationBitDepth: 16,
                    numberOfChannels: 1
                )
            ]),
            playbackState: .playing,
            currentPlayingId: url,
            currentTime: 30.0
        )
    ) {
        PlaylistDetailFeature()
    }

    return CurrentPlayingSection(store: store)
}
