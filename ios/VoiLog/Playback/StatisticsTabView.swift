//
//  StatisticsTabView.swift
//  VoiLog
//
//  Extracted from EnhancedVoiceMemoDetailView for Issue #123
//

import SwiftUI

struct StatisticsTabView: View {
    let memo: PlaybackFeature.VoiceMemo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 使用統計
                DetailSection(title: String(localized: "使用統計", table: "Playback")) {
                    InfoRow(icon: "play.circle", label: "再生回数", value: "0回")
                    InfoRow(icon: "square.and.arrow.up", label: "共有回数", value: "0回")
                    InfoRow(icon: "star", label: "お気に入り", value: "未設定")
                    InfoRow(icon: "clock.arrow.circlepath", label: "最終再生", value: "なし")
                }

                // ストレージ分析
                DetailSection(title: String(localized: "ストレージ効率", table: "Playback")) {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "internaldrive", label: "圧縮率", value: calculateCompressionRatio())
                        InfoRow(icon: "arrow.down.circle", label: "1分あたりサイズ", value: calculateSizePerMinute())

                        StorageUsageChart(fileSize: memo.fileSize, totalSize: totalStorageUsed())
                            .frame(height: 150)
                            .padding(.top, 8)
                    }
                }

                // 品質指標
                DetailSection(title: String(localized: "品質指標", table: "Playback")) {
                    QualityIndicatorView(memo: memo)
                }
            }
            .padding()
        }
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
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )

            var totalSize: Int64 = 0
            for fileURL in fileURLs {
                let fileExtension = fileURL.pathExtension.lowercased()
                if fileExtension == "m4a" || fileExtension == "wav" {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }

            return totalSize
        } catch {
            print("Failed to calculate total storage: \(error)")
            return memo.fileSize
        }
    }
}
