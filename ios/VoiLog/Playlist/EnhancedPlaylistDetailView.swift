//
//  EnhancedPlaylistDetailView.swift
//  VoiLog
//
//  Created for Issue #81: プレイリスト機能の実装
//

import SwiftUI
import ComposableArchitecture

struct EnhancedPlaylistDetailView: View {
    @Perception.Bindable var store: StoreOf<EnhancedPlaylistFeature>

    private func send(_ action: EnhancedPlaylistFeature.Action.View) {
        store.send(.view(action))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Playback Controls
                if !store.voiceMemos.isEmpty {
                    enhancedPlaybackControlsView
                    Divider()
                }

                // Voice Memos List
                voiceMemosListView
            }
            .navigationTitle(store.isEditingName ? "プレイリスト編集" : store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    editButton
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    addVoiceButton
                }
            }
            .onAppear {
                send(.onAppear)
            }
            .alert("エラー", isPresented: .constant(store.error != nil)) {
                Button("OK") {
                    // Clear error
                }
            } message: {
                if let error = store.error {
                    Text(error)
                }
            }
            .sheet(isPresented: $store.isShowingVoiceSelection) {
                EnhancedVoiceSelectionView { voiceId in
                    send(.addVoiceToPlaylist(voiceId))
                    send(.hideVoiceSelectionSheet)
                } onCancel: {
                    send(.hideVoiceSelectionSheet)
                }
            }
            .sheet(isPresented: $store.showingPlaybackModeSelection) {
                playbackModeSelectionView
            }
            .sheet(isPresented: $store.showingRepeatModeSelection) {
                repeatModeSelectionView
            }
        }
    }

    // MARK: - Edit Button
    @ViewBuilder
    private var editButton: some View {
        if store.isEditingName {
            HStack {
                Button("キャンセル") {
                    send(.cancelEditButtonTapped)
                }

                Button("保存") {
                    send(.saveNameButtonTapped)
                }
                .fontWeight(.semibold)
            }
        } else {
            Button("編集") {
                send(.editButtonTapped)
            }
        }
    }

    // MARK: - Add Voice Button
    private var addVoiceButton: some View {
        Button {
            send(.showVoiceSelectionSheet)
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - Enhanced Playback Controls
    private var enhancedPlaybackControlsView: some View {
        VStack(spacing: 16) {
            // Currently Playing Info
            if let currentMemo = store.currentPlayingMemo {
                currentlyPlayingInfoView(memo: currentMemo)
            }

            // Playback Mode and Repeat Controls
            playbackModeControlsView

            // Main Playback Controls
            mainPlaybackControlsView

            // Progress and Time
            if let currentMemo = store.currentPlayingMemo {
                progressView(memo: currentMemo)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private func currentlyPlayingInfoView(memo: EnhancedPlaylistFeature.EnhancedVoiceMemoState) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.title.isEmpty ? "無題の録音" : memo.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(formatDate(memo.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                send(.stopButtonTapped)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var playbackModeControlsView: some View {
        HStack {
            // Playback Mode
            Button {
                send(.showPlaybackModeSelection)
            } label: {
                Label(store.playbackMode.rawValue, systemImage: store.playbackMode.icon)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }

            Spacer()

            // Repeat Mode
            Button {
                send(.showRepeatModeSelection)
            } label: {
                Label(store.repeatMode.rawValue, systemImage: store.repeatMode.icon)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.repeatMode == .off ? Color(.systemGray5) : Color.green.opacity(0.1))
                    .foregroundColor(store.repeatMode == .off ? .secondary : .green)
                    .cornerRadius(8)
            }
        }
    }

    private var mainPlaybackControlsView: some View {
        HStack(spacing: 32) {
            // Previous Track
            Button {
                send(.previousTrackTapped)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .disabled(store.voiceMemos.isEmpty)

            // Play/Pause
            Button {
                send(.playButtonTapped)
            } label: {
                Image(systemName: store.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
            }
            .disabled(store.voiceMemos.isEmpty)

            // Next Track
            Button {
                send(.nextTrackTapped)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .disabled(store.voiceMemos.isEmpty)
        }
    }

    private func progressView(memo: EnhancedPlaylistFeature.EnhancedVoiceMemoState) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { store.currentTime },
                    set: { send(.seekTo($0)) }
                ),
                in: 0...memo.duration
            )

            HStack {
                Text(formatDuration(store.currentTime))
                    .font(.caption)
                    .monospacedDigit()

                Spacer()

                Text(formatDuration(memo.duration))
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Voice Memos List
    private var voiceMemosListView: some View {
        List {
            if store.isEditingName {
                nameEditingSection
            }

            voiceMemosSection
        }
        .listStyle(.plain)
        .overlay {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }

    private var nameEditingSection: some View {
        Section("プレイリスト名") {
            TextField("プレイリスト名", text: $store.editingName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    send(.saveNameButtonTapped)
                }
        }
    }

    private var voiceMemosSection: some View {
        Section("録音ファイル (\(store.voiceMemos.count)件)") {
            if store.voiceMemos.isEmpty {
                Text("録音ファイルがありません")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(store.voiceMemos.enumerated()), id: \.element.id) { index, memo in
                    EnhancedVoiceMemoRow(
                        memo: memo,
                        index: index,
                        isCurrentlyPlaying: store.currentPlayingIndex == index,
                        isPlaying: store.isPlaying && store.currentPlayingIndex == index,
                        onTap: {
                            send(.playMemoAtIndex(index))
                        },
                        onRemove: {
                            send(.removeVoice(memo.id))
                        }
                    )
                }
            }
        }
    }

    // MARK: - Selection Views
    private var playbackModeSelectionView: some View {
        NavigationStack {
            List {
                ForEach(EnhancedPlaylistFeature.PlaybackMode.allCases, id: \.self) { mode in
                    Button {
                        send(.setPlaybackMode(mode))
                    } label: {
                        HStack {
                            Label(mode.rawValue, systemImage: mode.icon)
                                .foregroundColor(.primary)

                            Spacer()

                            if store.playbackMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("再生モード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        send(.hidePlaybackModeSelection)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var repeatModeSelectionView: some View {
        NavigationStack {
            List {
                ForEach(EnhancedPlaylistFeature.RepeatMode.allCases, id: \.self) { mode in
                    Button {
                        send(.setRepeatMode(mode))
                    } label: {
                        HStack {
                            Label(mode.rawValue, systemImage: mode.icon)
                                .foregroundColor(.primary)

                            Spacer()

                            if store.repeatMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("リピートモード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        send(.hideRepeatModeSelection)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Enhanced Voice Memo Row
struct EnhancedVoiceMemoRow: View {
    let memo: EnhancedPlaylistFeature.EnhancedVoiceMemoState
    let index: Int
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Track Number
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

            // Play Indicator
            Button(action: onTap) {
                Image(systemName: playButtonIcon)
                    .font(.title2)
                    .foregroundColor(isCurrentlyPlaying ? .accentColor : .secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            // Memo Info
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.title.isEmpty ? "無題の録音" : memo.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(isCurrentlyPlaying ? .accentColor : .primary)

                HStack {
                    Text(formatDate(memo.date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatDuration(memo.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                if !memo.text.isEmpty {
                    Text(memo.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Progress Bar (if currently playing)
                if isCurrentlyPlaying && memo.duration > 0 {
                    ProgressView(value: memo.currentTime, total: memo.duration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                }
            }

            Spacer()

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var playButtonIcon: String {
        if isCurrentlyPlaying {
            return isPlaying ? "pause.circle.fill" : "play.circle.fill"
        } else {
            return "play.circle"
        }
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

// MARK: - Enhanced Voice Selection View
struct EnhancedVoiceSelectionView: View {
    let onSelect: (UUID) -> Void
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
            .navigationTitle("録音ファイルを追加")
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
                VoiceSelectionRow(voice: voice) {
                    onSelect(voice.id)
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

// MARK: - Voice Selection Row
struct VoiceSelectionRow: View {
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
    EnhancedPlaylistDetailView(
        store: Store(initialState: EnhancedPlaylistFeature.State(
            id: UUID(),
            name: "Sample Playlist",
            voices: [],
            createdAt: Date(),
            updatedAt: Date()
        )) {
            EnhancedPlaylistFeature()
        }
    )
}
