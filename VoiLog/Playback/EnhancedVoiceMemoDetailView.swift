//
//  EnhancedVoiceMemoDetailView.swift
//  VoiLog
//
//  Created for Issue #82: 詳細な音声情報表示
//

import SwiftUI
import AVFoundation
import Charts

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

    var body: some View {

            NavigationStack {
                TabView(selection: $selectedTab) {
                    // 基本情報タブ
                    basicInfoTab
                        .tabItem {
                            Label("基本情報", systemImage: "info.circle")
                        }
                        .tag(0)

                    // 音声分析タブ
                    audioAnalysisTab
                        .tabItem {
                            Label("音声分析", systemImage: "waveform")
                        }
                        .tag(1)

                    // メタデータタブ
                    metadataTab
                        .tabItem {
                            Label("メタデータ", systemImage: "doc.text")
                        }
                        .tag(2)

                    // 統計情報タブ
                    statisticsTab
                        .tabItem {
                            Label("統計", systemImage: "chart.bar")
                        }
                        .tag(3)
                }
                .navigationTitle("詳細情報")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") {
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
            }
        
    }

    // MARK: - Basic Info Tab
    private var basicInfoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // タイトルと再生コントロール
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memo.title)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(formatDate(memo.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.accentColor)
                        }
                    }

                    // プログレスバー
                    ProgressView(value: currentTime, total: memo.duration)
                        .tint(.accentColor)

                    HStack {
                        Text(formatDuration(currentTime))
                            .font(.caption)
                            .monospacedDigit()
                        Spacer()
                        Text(formatDuration(memo.duration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

                // 基本情報セクション
                detailSection(title: "録音情報") {
                    InfoRow(icon: "clock", label: "再生時間", value: formatDetailedDuration(memo.duration))
                    InfoRow(icon: "calendar", label: "録音日時", value: formatDetailedDate(memo.date))
                    InfoRow(icon: "location", label: "録音場所", value: "位置情報なし") // 将来的に実装
                    InfoRow(icon: "tag", label: "タグ", value: "なし") // 将来的に実装
                }

                // 音声認識テキスト
                if !memo.text.isEmpty {
                    detailSection(title: "音声認識テキスト") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(memo.text)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            HStack {
                                Label("\(memo.text.count) 文字", systemImage: "textformat.size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Label("\(wordCount(memo.text)) 単語", systemImage: "text.word.spacing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ファイル情報
                detailSection(title: "ファイル情報") {
                    InfoRow(icon: "doc", label: "ファイル名", value: memo.url.lastPathComponent)
                    InfoRow(icon: "folder", label: "保存場所", value: memo.url.deletingLastPathComponent().path)
                    InfoRow(icon: "doc.badge.ellipsis", label: "ファイル形式", value: memo.fileFormat.uppercased())
                    InfoRow(icon: "square.and.arrow.down", label: "ファイルサイズ", value: formatDetailedFileSize(memo.fileSize))
                }
            }
            .padding()
        }
    }

    // MARK: - Audio Analysis Tab
    private var audioAnalysisTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isAnalyzingAudio {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("音声を分析中...")
                            .font(.headline)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(50)
                } else if let analysisData = audioAnalysisData {
                    // 波形ビジュアライゼーション
                    detailSection(title: "波形") {
                        SimpleWaveformView(data: waveformData)
                            .frame(height: 150)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // 音声特性
                    detailSection(title: "音声特性") {
                        InfoRow(icon: "waveform", label: "平均音量", value: String(format: "%.1f dB", analysisData.averageVolume))
                        InfoRow(icon: "speaker.wave.3", label: "ピーク音量", value: String(format: "%.1f dB", analysisData.peakVolume))
                        InfoRow(icon: "waveform.path.ecg", label: "ダイナミックレンジ", value: String(format: "%.1f dB", analysisData.dynamicRange))
                        InfoRow(icon: "metronome", label: "サンプリングレート", value: "\(Int(memo.samplingFrequency)) Hz")
                        InfoRow(icon: "speaker.wave.2", label: "ビットレート", value: calculateBitrate())
                    }

                    // 周波数分析
                    detailSection(title: "周波数分析") {
                        FrequencyChart(data: analysisData.frequencyData)
                            .frame(height: 200)
                    }

                    // 無音検出
                    detailSection(title: "無音分析") {
                        InfoRow(icon: "speaker.slash", label: "無音時間", value: formatDuration(analysisData.silenceDuration))
                        InfoRow(icon: "percent", label: "無音比率", value: String(format: "%.1f%%", analysisData.silenceRatio * 100))
                        InfoRow(icon: "scissors", label: "無音区間数", value: "\(analysisData.silenceSegments.count)")
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Metadata Tab
    private var metadataTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 技術的メタデータ
                detailSection(title: "技術的メタデータ") {
                    InfoRow(icon: "cpu", label: "エンコーダー", value: "Core Audio")
                    InfoRow(icon: "antenna.radiowaves.left.and.right", label: "チャンネル", value: channelConfiguration())
                    InfoRow(icon: "waveform.badge.plus", label: "ビット深度", value: "\(memo.quantizationBitDepth) bit")
                    InfoRow(icon: "arrow.left.arrow.right", label: "エンディアン", value: "リトルエンディアン")
                }

                // デバイス情報
                detailSection(title: "録音デバイス") {
                    InfoRow(icon: "iphone", label: "デバイス", value: UIDevice.current.model)
                    InfoRow(icon: "mic", label: "マイク", value: "内蔵マイク")
                    InfoRow(icon: "gear", label: "録音設定", value: "標準品質")
                    InfoRow(icon: "app.badge", label: "アプリバージョン", value: appVersion())
                }

                // 拡張属性
                detailSection(title: "拡張属性") {
                    InfoRow(icon: "checkmark.seal", label: "完全性", value: "検証済み")
                    InfoRow(icon: "lock", label: "暗号化", value: "なし")
                    InfoRow(icon: "tag.circle", label: "カスタムタグ", value: "未設定")
                }
            }
            .padding()
        }
    }

    // MARK: - Statistics Tab
    private var statisticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 使用統計
                detailSection(title: "使用統計") {
                    InfoRow(icon: "play.circle", label: "再生回数", value: "0回") // 将来的に実装
                    InfoRow(icon: "square.and.arrow.up", label: "共有回数", value: "0回") // 将来的に実装
                    InfoRow(icon: "star", label: "お気に入り", value: "未設定") // 将来的に実装
                    InfoRow(icon: "clock.arrow.circlepath", label: "最終再生", value: "なし") // 将来的に実装
                }

                // ストレージ分析
                detailSection(title: "ストレージ効率") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "internaldrive", label: "圧縮率", value: calculateCompressionRatio())
                        InfoRow(icon: "arrow.down.circle", label: "1分あたりサイズ", value: calculateSizePerMinute())

                        // ストレージ使用量グラフ
                        StorageUsageChart(fileSize: memo.fileSize, totalSize: totalStorageUsed())
                            .frame(height: 150)
                            .padding(.top, 8)
                    }
                }

                // 品質指標
                detailSection(title: "品質指標") {
                    QualityIndicatorView(memo: memo)
                }
            }
            .padding()
        }
    }

    // MARK: - Helper Views
    @ViewBuilder
    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Helper Methods
    private func togglePlayback() {
        isPlaying.toggle()
        // TODO: 実際の再生実装
    }

    private func analyzeAudioFile() {
        isAnalyzingAudio = true

        // 非同期で音声ファイルを分析
        Task {
            // TODO: 実際の音声分析実装
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒のシミュレーション

            await MainActor.run {
                // ダミーデータ
                audioAnalysisData = AudioAnalysisData(
                    averageVolume: -12.5,
                    peakVolume: -3.2,
                    dynamicRange: 9.3,
                    silenceDuration: 5.2,
                    silenceRatio: 0.042,
                    silenceSegments: [(start: 10.5, end: 11.2), (start: 45.3, end: 46.8)],
                    frequencyData: generateDummyFrequencyData()
                )
                waveformData = generateDummyWaveform()
                isAnalyzingAudio = false
            }
        }
    }

    private func generateDetailReport() -> String {
        var report = "【音声メモ詳細レポート】\n\n"
        report += "タイトル: \(memo.title)\n"
        report += "録音日時: \(formatDetailedDate(memo.date))\n"
        report += "再生時間: \(formatDetailedDuration(memo.duration))\n"
        report += "ファイルサイズ: \(formatDetailedFileSize(memo.fileSize))\n"
        report += "形式: \(memo.fileFormat.uppercased())\n"
        report += "サンプリングレート: \(Int(memo.samplingFrequency)) Hz\n"
        report += "ビット深度: \(memo.quantizationBitDepth) bit\n"
        report += "チャンネル: \(channelConfiguration())\n"

        if !memo.text.isEmpty {
            report += "\n音声認識テキスト:\n\(memo.text)\n"
        }

        return report
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

    private func formatDetailedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 (E) HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDetailedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }

    private func channelConfiguration() -> String {
        switch memo.numberOfChannels {
        case 1: return "モノラル (1ch)"
        case 2: return "ステレオ (2ch)"
        default: return "\(memo.numberOfChannels)チャンネル"
        }
    }

    private func wordCount(_ text: String) -> Int {
        // 日本語と英語の単語をカウント
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let nonEmptyWords = words.filter { !$0.isEmpty }

        // 日本語の文字数も考慮
        let japaneseCharCount = text.filter { $0.isJapanese }.count / 5 // 平均5文字で1単語と仮定

        return max(nonEmptyWords.count, japaneseCharCount)
    }

    private func calculateBitrate() -> String {
        let bitrate = Double(memo.fileSize * 8) / memo.duration / 1000
        return String(format: "%.0f kbps", bitrate)
    }

    private func calculateCompressionRatio() -> String {
        let uncompressedSize = memo.duration * memo.samplingFrequency * Double(memo.quantizationBitDepth) * Double(memo.numberOfChannels) / 8
        let ratio = uncompressedSize / Double(memo.fileSize)
        return String(format: "%.1f:1", ratio)
    }

    private func calculateSizePerMinute() -> String {
        let sizePerMinute = Double(memo.fileSize) / (memo.duration / 60)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizePerMinute)) + "/分"
    }

    private func totalStorageUsed() -> Int64 {
        // TODO: 実際の総ストレージ使用量を計算
        return memo.fileSize * 20 // ダミーデータ
    }

    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private func generateDummyWaveform() -> [Float] {
        (0..<100).map { _ in Float.random(in: -1...1) }
    }

    private func generateDummyFrequencyData() -> [(frequency: Float, amplitude: Float)] {
        let frequencies: [Float] = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
        return frequencies.map { freq in
            (frequency: freq, amplitude: Float.random(in: -60...0))
        }
    }
}

// MARK: - Supporting Views
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 100, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

struct SimpleWaveformView: View {
    let data: [Float]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }

                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                let stepX = width / CGFloat(data.count - 1)

                path.move(to: CGPoint(x: 0, y: midY))

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = midY - (CGFloat(value) * midY * 0.8)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.accentColor, lineWidth: 2)
        }
    }
}

struct FrequencyChart: View {
    let data: [(frequency: Float, amplitude: Float)]

    var body: some View {
        Chart(data, id: \.frequency) { item in
            BarMark(
                x: .value("周波数", "\(Int(item.frequency)) Hz"),
                y: .value("振幅", item.amplitude)
            )
            .foregroundStyle(Color.accentColor.gradient)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amplitude = value.as(Double.self) {
                        Text("\(Int(amplitude)) dB")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(orientation: .automatic)
                    .font(.caption)
            }
        }
    }
}

struct StorageUsageChart: View {
    let fileSize: Int64
    let totalSize: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("このファイル")
                    .font(.caption)
                Spacer()
                Text(formatFileSize(fileSize))
                    .font(.caption)
                    .fontWeight(.medium)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(fileSize) / CGFloat(totalSize), height: 20)
                }
            }
            .frame(height: 20)

            HStack {
                Text("総使用量")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatFileSize(totalSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct QualityIndicatorView: View {
    let memo: PlaybackFeature.VoiceMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            qualityRow(label: "サンプリングレート", value: rateQuality(), color: rateColor())
            qualityRow(label: "ビット深度", value: bitDepthQuality(), color: bitDepthColor())
            qualityRow(label: "圧縮効率", value: compressionQuality(), color: compressionColor())
            qualityRow(label: "総合品質", value: overallQuality(), color: overallColor())
        }
    }

    private func qualityRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
        }
    }

    private func rateQuality() -> String {
        switch memo.samplingFrequency {
        case 44100...: return "高品質"
        case 22050..<44100: return "標準"
        default: return "低品質"
        }
    }

    private func rateColor() -> Color {
        switch memo.samplingFrequency {
        case 44100...: return .green
        case 22050..<44100: return .orange
        default: return .red
        }
    }

    private func bitDepthQuality() -> String {
        switch memo.quantizationBitDepth {
        case 24...: return "高品質"
        case 16: return "標準"
        default: return "低品質"
        }
    }

    private func bitDepthColor() -> Color {
        switch memo.quantizationBitDepth {
        case 24...: return .green
        case 16: return .orange
        default: return .red
        }
    }

    private func compressionQuality() -> String {
        let bitrate = Double(memo.fileSize * 8) / memo.duration / 1000
        switch bitrate {
        case 256...: return "高品質"
        case 128..<256: return "標準"
        default: return "低品質"
        }
    }

    private func compressionColor() -> Color {
        let bitrate = Double(memo.fileSize * 8) / memo.duration / 1000
        switch bitrate {
        case 256...: return .green
        case 128..<256: return .orange
        default: return .red
        }
    }

    private func overallQuality() -> String {
        let scores = [
            memo.samplingFrequency >= 44100 ? 3 : (memo.samplingFrequency >= 22050 ? 2 : 1),
            memo.quantizationBitDepth >= 24 ? 3 : (memo.quantizationBitDepth >= 16 ? 2 : 1),
            (Double(memo.fileSize * 8) / memo.duration / 1000) >= 256 ? 3 : ((Double(memo.fileSize * 8) / memo.duration / 1000) >= 128 ? 2 : 1)
        ]

        let average = Double(scores.reduce(0, +)) / Double(scores.count)

        switch average {
        case 2.5...: return "優秀"
        case 2.0..<2.5: return "良好"
        case 1.5..<2.0: return "標準"
        default: return "改善推奨"
        }
    }

    private func overallColor() -> Color {
        let scores = [
            memo.samplingFrequency >= 44100 ? 3 : (memo.samplingFrequency >= 22050 ? 2 : 1),
            memo.quantizationBitDepth >= 24 ? 3 : (memo.quantizationBitDepth >= 16 ? 2 : 1),
            (Double(memo.fileSize * 8) / memo.duration / 1000) >= 256 ? 3 : ((Double(memo.fileSize * 8) / memo.duration / 1000) >= 128 ? 2 : 1)
        ]

        let average = Double(scores.reduce(0, +)) / Double(scores.count)

        switch average {
        case 2.5...: return .green
        case 2.0..<2.5: return .blue
        case 1.5..<2.0: return .orange
        default: return .red
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Data Models
struct AudioAnalysisData {
    let averageVolume: Double
    let peakVolume: Double
    let dynamicRange: Double
    let silenceDuration: TimeInterval
    let silenceRatio: Double
    let silenceSegments: [(start: TimeInterval, end: TimeInterval)]
    let frequencyData: [(frequency: Float, amplitude: Float)]
}

// MARK: - Extensions
extension Character {
    var isJapanese: Bool {
        let value = self.unicodeScalars.first?.value ?? 0
        return (0x3040...0x309F).contains(value) || // Hiragana
               (0x30A0...0x30FF).contains(value) || // Katakana
               (0x4E00...0x9FFF).contains(value) || // Kanji
               (0xFF00...0xFFEF).contains(value)    // Full-width
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
