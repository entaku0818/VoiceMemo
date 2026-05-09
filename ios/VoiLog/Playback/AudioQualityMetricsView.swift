//
//  AudioQualityMetricsView.swift
//  VoiLog
//
//  Extracted from EnhancedVoiceMemoDetailView for Issue #123
//  Contains: DetailSection, InfoRow, SimpleWaveformView, FrequencyChart,
//            StorageUsageChart, QualityIndicatorView, AudioAnalysisData,
//            and Character.isJapanese extension.
//

import SwiftUI
import Charts

// MARK: - Shared Layout Helper

/// Reusable card section with a title and arbitrary content.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
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
}

// MARK: - InfoRow

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

// MARK: - SimpleWaveformView

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

// MARK: - FrequencyChart

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

// MARK: - StorageUsageChart

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

// MARK: - QualityIndicatorView

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

    // MARK: Individual quality helpers

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

    // MARK: Overall quality — score computed once, used by both label and color

    /// Computes a composite quality score from sampling rate, bit depth, and bitrate.
    /// Returns a value in [1.0, 3.0] where higher is better.
    private func overallScore() -> Double {
        let rateScore = memo.samplingFrequency >= 44100 ? 3 : (memo.samplingFrequency >= 22050 ? 2 : 1)
        let depthScore = memo.quantizationBitDepth >= 24 ? 3 : (memo.quantizationBitDepth >= 16 ? 2 : 1)
        let bitrate = Double(memo.fileSize * 8) / memo.duration / 1000
        let bitrateScore = bitrate >= 256 ? 3 : (bitrate >= 128 ? 2 : 1)
        return Double(rateScore + depthScore + bitrateScore) / 3.0
    }

    private func overallQuality() -> String {
        switch overallScore() {
        case 2.5...: return "優秀"
        case 2.0..<2.5: return "良好"
        case 1.5..<2.0: return "標準"
        default: return "改善推奨"
        }
    }

    private func overallColor() -> Color {
        switch overallScore() {
        case 2.5...: return .green
        case 2.0..<2.5: return .blue
        case 1.5..<2.0: return .orange
        default: return .red
        }
    }
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
