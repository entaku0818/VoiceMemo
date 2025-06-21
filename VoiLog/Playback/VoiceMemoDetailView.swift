import SwiftUI
import Perception

struct VoiceMemoDetailView: View {
  let memo: PlaybackFeature.VoiceMemo
  let onDismiss: () -> Void

  var body: some View {
    WithPerceptionTracking {
      NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // 基本情報セクション
          detailSection(title: "基本情報") {
            detailRow(label: "タイトル", value: memo.title)
            detailRow(label: "録音日時", value: DateFormatter.dateTimeFormatter.string(from: memo.date))
            detailRow(label: "再生時間", value: formatDuration(memo.duration))
            if !memo.text.isEmpty {
              VStack(alignment: .leading, spacing: 4) {
                Text("音声認識テキスト")
                  .font(.subheadline)
                  .fontWeight(.medium)
                  .foregroundColor(.secondary)
                Text(memo.text)
                  .font(.body)
                  .padding(12)
                  .background(Color(.systemGray6))
                  .cornerRadius(8)
              }
            }
          }

          // ファイル情報セクション
          detailSection(title: "ファイル情報") {
            detailRow(label: "ファイルサイズ", value: formatFileSize(memo.fileSize))
            detailRow(label: "ファイル形式", value: memo.fileFormat.isEmpty ? "m4a" : memo.fileFormat)
            detailRow(label: "ファイルパス", value: memo.url.lastPathComponent)
          }

          // 音質設定セクション
          detailSection(title: "音質設定") {
            detailRow(label: "サンプリング周波数", value: "\(Int(memo.samplingFrequency)) Hz")
            detailRow(label: "ビット深度", value: "\(memo.quantizationBitDepth) bit")
            detailRow(label: "チャンネル数", value: memo.numberOfChannels == 1 ? "モノラル" : "ステレオ")
          }
        }
        .padding()
      }
      .navigationTitle("詳細情報")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("閉じる") {
            onDismiss()
          }
        }
      }
      }
    }
  }

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
      .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
  }

  private func detailRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
        .frame(width: 120, alignment: .leading)

      Text(value)
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

extension DateFormatter {
  static let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter
  }()
}

#Preview {
  VoiceMemoDetailView(
    memo: PlaybackFeature.VoiceMemo(
      title: "テスト録音",
      date: Date(),
      duration: 123.45,
      url: URL(fileURLWithPath: "/test.m4a"),
      text: "これはテスト用の音声認識テキストです。",
      fileFormat: "m4a",
      samplingFrequency: 44100.0,
      quantizationBitDepth: 16,
      numberOfChannels: 2,
      fileSize: 1024576
    ),
    onDismiss: {}
  )
}