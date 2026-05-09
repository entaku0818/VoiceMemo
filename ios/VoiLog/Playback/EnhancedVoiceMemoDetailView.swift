//
//  EnhancedVoiceMemoDetailView.swift
//  VoiLog
//
//  Created for Issue #82: 詳細な音声情報表示
//  Refactored for Issue #123: split tabs into separate files
//

import SwiftUI
import AVFoundation

struct EnhancedVoiceMemoDetailView: View {
    let memo: PlaybackFeature.VoiceMemo
    let onDismiss: () -> Void

    @State private var selectedTab = 0
    @State private var isAnalyzingAudio = false
    @State private var audioAnalysisData: AudioAnalysisData?
    @State private var waveformData: [Float] = []
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var showShareSheet = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackTimer: Timer?

    private var timestampedTranscription: TimestampedTranscription? {
        guard let json = memo.timestampedText else { return nil }
        return TimestampedTranscription.fromJSON(json)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                BasicInfoTabView(
                    memo: memo,
                    isPlaying: isPlaying,
                    currentTime: currentTime,
                    onTogglePlayback: togglePlayback
                )
                .tabItem {
                    Label(String(localized: "基本情報", table: "Playback"), systemImage: "info.circle")
                }
                .tag(0)

                AudioAnalysisTabView(
                    memo: memo,
                    isAnalyzingAudio: isAnalyzingAudio,
                    audioAnalysisData: audioAnalysisData,
                    waveformData: waveformData
                )
                .tabItem {
                    Label(String(localized: "音声分析", table: "Playback"), systemImage: "waveform")
                }
                .tag(1)

                MetadataTabView(memo: memo)
                    .tabItem {
                        Label(String(localized: "メタデータ", table: "Playback"), systemImage: "doc.text")
                    }
                    .tag(2)

                TranscriptionTabView(
                    memo: memo,
                    timestampedTranscription: timestampedTranscription,
                    onSeekTo: seekTo
                )
                .tabItem {
                    Label(String(localized: "文字起こし"), systemImage: "text.bubble")
                }
                .tag(3)

                StatisticsTabView(memo: memo)
                    .tabItem {
                        Label(String(localized: "統計", table: "Playback"), systemImage: "chart.bar")
                    }
                    .tag(4)
            }
            .navigationTitle(String(localized: "詳細情報", table: "Playback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる")) {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [generateDetailReport()])
            }
            .onAppear {
                analyzeAudioFile()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            playbackTimer?.invalidate()
            playbackTimer = nil
            isPlaying = false
        } else {
            if audioPlayer == nil {
                setupAudioPlayer()
            }
            audioPlayer?.play()
            startPlaybackTimer()
            isPlaying = true
        }
    }

    private func setupAudioPlayer() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: memo.url)
            audioPlayer?.currentTime = currentTime
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            if let player = audioPlayer {
                currentTime = player.currentTime
                if !player.isPlaying && isPlaying {
                    isPlaying = false
                    currentTime = 0
                    playbackTimer?.invalidate()
                    playbackTimer = nil
                }
            }
        }
    }

    private func seekTo(_ time: TimeInterval) {
        if audioPlayer == nil { setupAudioPlayer() }
        audioPlayer?.currentTime = time
        currentTime = time
        if !isPlaying {
            audioPlayer?.play()
            startPlaybackTimer()
            isPlaying = true
        }
    }

    private func cleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
    }

    // MARK: - Audio Analysis

    private func analyzeAudioFile() {
        isAnalyzingAudio = true

        Task {
            do {
                let audioFile = try AVAudioFile(forReading: memo.url)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)

                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    throw NSError(domain: "AudioAnalysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
                }

                try audioFile.read(into: buffer)

                let waveform = AudioAnalyzer.generateWaveform(from: buffer)
                let (avgVolume, peakVolume) = AudioAnalyzer.analyzeVolume(buffer: buffer)
                let dynamicRange = peakVolume - avgVolume
                let silenceSegments = AudioAnalyzer.detectSilence(buffer: buffer, threshold: -40.0)
                let silenceDuration = silenceSegments.reduce(0.0) { $0 + ($1.end - $1.start) }
                let silenceRatio = silenceDuration / memo.duration
                let frequencyData = AudioAnalyzer.analyzeFrequency(buffer: buffer)

                await MainActor.run {
                    audioAnalysisData = AudioAnalysisData(
                        averageVolume: avgVolume,
                        peakVolume: peakVolume,
                        dynamicRange: dynamicRange,
                        silenceDuration: silenceDuration,
                        silenceRatio: silenceRatio,
                        silenceSegments: silenceSegments,
                        frequencyData: frequencyData
                    )
                    waveformData = waveform
                    isAnalyzingAudio = false
                }
            } catch {
                print("Failed to analyze audio: \(error)")
                await MainActor.run {
                    audioAnalysisData = AudioAnalysisData(
                        averageVolume: -12.5,
                        peakVolume: -3.2,
                        dynamicRange: 9.3,
                        silenceDuration: 5.2,
                        silenceRatio: 0.042,
                        silenceSegments: [(start: 10.5, end: 11.2), (start: 45.3, end: 46.8)],
                        frequencyData: AudioAnalyzer.generateDummyFrequencyData()
                    )
                    waveformData = AudioAnalyzer.generateDummyWaveform()
                    isAnalyzingAudio = false
                }
            }
        }
    }

    // MARK: - Share Report

    private func generateDetailReport() -> String {
        var report = "【音声メモ詳細レポート】\n\n"
        report += "タイトル: \(memo.title)\n"
        report += "録音日時: \(formatDetailedDate(memo.date))\n"
        report += "再生時間: \(formatDetailedDuration(memo.duration))\n"
        report += "ファイルサイズ: \(formatDetailedFileSize(memo.fileSize))\n"
        report += "形式: \(formatFileFormat(memo.fileFormat))\n"
        report += "サンプリングレート: \(Int(memo.samplingFrequency)) Hz\n"
        report += "ビット深度: \(memo.quantizationBitDepth) bit\n"
        report += "チャンネル: \(channelConfiguration())\n"

        if !memo.text.isEmpty {
            report += "\n音声認識テキスト:\n\(memo.text)\n"
        }

        return report
    }

    // MARK: - Formatting Helpers (used only by generateDetailReport)

    private func formatDetailedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 (E) HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatDetailedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d時間 %d分 %d秒", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d分 %d秒", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }

    private func formatDetailedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }

    private func formatFileFormat(_ format: String) -> String {
        switch format.lowercased() {
        case "m4a", "aac", "mpeg4aac":
            return "AAC"
        case "wav", "linearpcm":
            return "WAV"
        case "":
            return "AAC"
        default:
            return format.uppercased()
        }
    }

    private func channelConfiguration() -> String {
        switch memo.numberOfChannels {
        case 1: return "モノラル (1ch)"
        case 2: return "ステレオ (2ch)"
        default: return "\(memo.numberOfChannels)チャンネル"
        }
    }
}

#Preview {
    EnhancedVoiceMemoDetailView(
        memo: PlaybackFeature.VoiceMemo(
            title: "テスト録音",
            date: Date(),
            duration: 123.45,
            url: URL(fileURLWithPath: "/test.m4a"),
            text: "これはテスト用の音声認識テキストです。詳細な音声情報表示機能のデモンストレーションです。",
            fileFormat: "m4a",
            samplingFrequency: 44100.0,
            quantizationBitDepth: 16,
            numberOfChannels: 2,
            fileSize: 1024576
        ),
        onDismiss: {}
    )
}
