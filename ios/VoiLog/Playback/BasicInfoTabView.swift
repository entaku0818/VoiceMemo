//
//  BasicInfoTabView.swift
//  VoiLog
//
//  Extracted from EnhancedVoiceMemoDetailView for Issue #123
//

import SwiftUI
import AVFoundation

struct BasicInfoTabView: View {
    let memo: PlaybackFeature.VoiceMemo
    let isPlaying: Bool
    let currentTime: TimeInterval
    let onTogglePlayback: () -> Void

    var body: some View {
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

                        Button(action: onTogglePlayback) {
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
                DetailSection(title: String(localized: "録音情報", table: "Playback")) {
                    InfoRow(icon: "clock", label: String(localized: "再生時間", table: "Playback"), value: formatDetailedDuration(memo.duration))
                    InfoRow(icon: "calendar", label: String(localized: "録音日時", table: "Playback"), value: formatDetailedDate(memo.date))
                    InfoRow(icon: "location", label: "録音場所", value: "位置情報なし")
                    InfoRow(icon: "tag", label: "タグ", value: "なし")
                }

                // 音声認識テキスト
                if !memo.text.isEmpty {
                    DetailSection(title: String(localized: "音声認識テキスト", table: "Playback")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(memo.text)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            HStack {
                                Label(String(format: String(localized: "%lld 文字", table: "Playback"), memo.text.count), systemImage: "textformat.size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Label(String(format: String(localized: "%lld 単語", table: "Playback"), wordCount(memo.text)), systemImage: "text.word.spacing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ファイル情報
                DetailSection(title: String(localized: "ファイル情報", table: "Playback")) {
                    InfoRow(icon: "doc", label: String(localized: "ファイル名", table: "Playback"), value: memo.url.lastPathComponent)
                    InfoRow(icon: "folder", label: String(localized: "保存場所", table: "Playback"), value: memo.url.deletingLastPathComponent().path)
                    InfoRow(icon: "doc.badge.ellipsis", label: String(localized: "ファイル形式"), value: formatFileFormat(memo.fileFormat))
                    InfoRow(icon: "square.and.arrow.down", label: String(localized: "ファイルサイズ", table: "Playback"), value: formatDetailedFileSize(memo.fileSize))
                }
            }
            .padding()
        }
    }

    // MARK: - Private Helpers

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

    private func wordCount(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let nonEmptyWords = words.filter { !$0.isEmpty }
        let japaneseCharCount = text.filter { $0.isJapanese }.count / 5
        return max(nonEmptyWords.count, japaneseCharCount)
    }
}
