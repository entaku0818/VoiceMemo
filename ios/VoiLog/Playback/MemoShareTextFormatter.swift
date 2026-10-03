//
//  MemoShareTextFormatter.swift
//  VoiLog
//
//  共有テキスト・PDF・詳細レポートに書き出す文言を組み立てる（Issue #221）。
//  日付・時間はユーザーのロケールで整形し、見出しはすべて Playback カタログから引く。
//

import Foundation

enum MemoShareTextFormatter {

    // MARK: - Formatting

    /// 例: ja「2026年10月3日(土) 12:34:56」/ en「Sat, Oct 3, 2026, 12:34:56 PM」
    static func detailedDate(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEjmmss")
        return formatter.string(from: date)
    }

    /// 例: ja「2分5秒」/ en「2 minutes, 5 seconds」
    static func detailedDuration(_ duration: TimeInterval, locale: Locale = .current) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropLeading
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: max(0, duration.rounded(.down))) ?? ""
    }

    static func channelConfiguration(_ numberOfChannels: Int) -> String {
        switch numberOfChannels {
        case 1: return String(localized: "モノラル (1ch)", table: "Playback")
        case 2: return String(localized: "ステレオ (2ch)", table: "Playback")
        default: return String(localized: "\(numberOfChannels)チャンネル", table: "Playback")
        }
    }

    // MARK: - Lines

    static func recordedAtLine(_ date: Date) -> String {
        String(localized: "録音日時: \(detailedDate(date))", table: "Playback")
    }

    static func durationLine(_ duration: TimeInterval) -> String {
        String(localized: "再生時間: \(detailedDuration(duration))", table: "Playback")
    }

    /// 文字起こしをテキスト共有するときの先頭部分（末尾に空行を含む）
    static func transcriptHeader(title: String, date: Date, duration: TimeInterval) -> String {
        [
            String(localized: "【\(title)】", table: "Playback"),
            recordedAtLine(date),
            durationLine(duration)
        ].joined(separator: "\n") + "\n\n"
    }

    /// PDF のタイトル下に出すメタ行
    static func pdfMetaLine(date: Date, duration: TimeInterval) -> String {
        String(
            format: String(localized: "録音日時: %1$@  /  再生時間: %2$@", table: "Playback"),
            detailedDate(date),
            detailedDuration(duration)
        )
    }

    /// 詳細画面の「レポートを共有」で書き出すテキスト
    static func detailReport(
        memo: PlaybackFeature.VoiceMemo,
        fileSize: String,
        fileFormat: String
    ) -> String {
        var lines = [
            String(localized: "【音声メモ詳細レポート】", table: "Playback"),
            "",
            String(localized: "タイトル: \(memo.title)", table: "Playback"),
            recordedAtLine(memo.date),
            durationLine(memo.duration),
            String(localized: "ファイルサイズ: \(fileSize)", table: "Playback"),
            String(localized: "形式: \(fileFormat)", table: "Playback"),
            String(localized: "サンプリングレート: \(Int(memo.samplingFrequency)) Hz", table: "Playback"),
            String(localized: "ビット深度: \(memo.quantizationBitDepth) bit", table: "Playback"),
            String(localized: "チャンネル: \(channelConfiguration(memo.numberOfChannels))", table: "Playback")
        ]

        if !memo.text.isEmpty {
            lines += ["", String(localized: "音声認識テキスト:", table: "Playback"), memo.text]
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
