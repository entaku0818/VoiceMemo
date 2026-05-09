//
//  TranscriptionTabView.swift
//  VoiLog
//
//  Extracted from EnhancedVoiceMemoDetailView for Issue #123
//

import SwiftUI

struct TranscriptionTabView: View {
    let memo: PlaybackFeature.VoiceMemo
    let timestampedTranscription: TimestampedTranscription?
    let onSeekTo: (TimeInterval) -> Void

    @State private var showTranscriptionExport = false
    @State private var exportItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let transcription = timestampedTranscription {
                    // エクスポートボタン
                    HStack {
                        Spacer()
                        Menu {
                            Button {
                                exportAsText(transcription)
                            } label: {
                                Label("テキスト (.txt)", systemImage: "doc.text")
                            }
                            Button {
                                exportAsPDF(transcription)
                            } label: {
                                Label("PDF (.pdf)", systemImage: "doc.richtext")
                            }
                        } label: {
                            Label("エクスポート", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    // タイムスタンプ付きセグメント
                    DetailSection(title: String(localized: "タイムスタンプ付き文字起こし", table: "Playback")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(transcription.segments) { segment in
                                Button {
                                    onSeekTo(segment.timestamp)
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(segment.formattedTimestamp)
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(.accentColor)
                                            .frame(width: 60, alignment: .leading)

                                        Text(segment.text)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                if segment.id != transcription.segments.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    // 全文テキスト
                    if !transcription.fullText.isEmpty {
                        DetailSection(title: String(localized: "全文", table: "Playback")) {
                            Text(transcription.fullText)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(String(localized: "文字起こしデータがありません", table: "Playback"))
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("この録音には文字起こしデータが含まれていません。\n新しい録音を行うと自動的に生成されます。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showTranscriptionExport) {
            ShareSheet(items: exportItems)
        }
    }

    // MARK: - Export Helpers

    private func exportAsText(_ transcription: TimestampedTranscription) {
        let content = "【\(memo.title)】\n録音日時: \(formatDetailedDate(memo.date))\n再生時間: \(formatDetailedDuration(memo.duration))\n\n" + transcription.formattedText
        let fileName = "\(memo.title)_transcript.txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)
        exportItems = [tempURL]
        showTranscriptionExport = true
    }

    private func exportAsPDF(_ transcription: TimestampedTranscription) {
        let pdfData = generatePDF(transcription: transcription)
        let fileName = "\(memo.title)_transcript.pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? pdfData.write(to: tempURL)
        exportItems = [tempURL]
        showTranscriptionExport = true
    }

    private func generatePDF(transcription: TimestampedTranscription) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            // タイトル
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            let title = memo.title as NSString
            title.draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttributes)

            // メタデータ
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.gray
            ]
            let meta = "録音日時: \(formatDetailedDate(memo.date))  /  再生時間: \(formatDetailedDuration(memo.duration))" as NSString
            meta.draw(at: CGPoint(x: 40, y: 68), withAttributes: metaAttributes)

            // 区切り線
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(0.5)
            cgContext.move(to: CGPoint(x: 40, y: 88))
            cgContext.addLine(to: CGPoint(x: pageRect.width - 40, y: 88))
            cgContext.strokePath()

            // セグメント
            let segmentAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            let timestampAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.systemBlue
            ]

            var yOffset: CGFloat = 100
            let maxY = pageRect.height - 60
            let leftMargin: CGFloat = 40
            let timestampWidth: CGFloat = 60
            let textWidth = pageRect.width - leftMargin - timestampWidth - 40

            for segment in transcription.segments {
                if yOffset > maxY {
                    context.beginPage()
                    yOffset = 40
                }

                let ts = segment.formattedTimestamp as NSString
                ts.draw(at: CGPoint(x: leftMargin, y: yOffset), withAttributes: timestampAttributes)

                let textRect = CGRect(x: leftMargin + timestampWidth, y: yOffset, width: textWidth, height: 200)
                let textHeight = (segment.text as NSString).boundingRect(
                    with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: segmentAttributes,
                    context: nil
                ).height
                (segment.text as NSString).draw(in: textRect, withAttributes: segmentAttributes)

                yOffset += max(textHeight, 20) + 8
            }
        }
    }

    // MARK: - Formatting Helpers

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
}
