//
//  MetadataTabView.swift
//  VoiLog
//
//  Extracted from EnhancedVoiceMemoDetailView for Issue #123
//

import SwiftUI

struct MetadataTabView: View {
    let memo: PlaybackFeature.VoiceMemo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 技術的メタデータ
                DetailSection(title: String(localized: "技術的メタデータ", table: "Playback")) {
                    InfoRow(icon: "cpu", label: "エンコーダー", value: "Core Audio")
                    InfoRow(icon: "antenna.radiowaves.left.and.right", label: "チャンネル", value: channelConfiguration())
                    InfoRow(icon: "waveform.badge.plus", label: "ビット深度", value: "\(memo.quantizationBitDepth) bit")
                    InfoRow(icon: "arrow.left.arrow.right", label: "エンディアン", value: "リトルエンディアン")
                }

                // デバイス情報
                DetailSection(title: String(localized: "録音デバイス", table: "Playback")) {
                    InfoRow(icon: "iphone", label: "デバイス", value: UIDevice.current.model)
                    InfoRow(icon: "mic", label: "マイク", value: "内蔵マイク")
                    InfoRow(icon: "gear", label: "録音設定", value: "標準品質")
                    InfoRow(icon: "app.badge", label: "アプリバージョン", value: appVersion())
                }

                // 拡張属性
                DetailSection(title: String(localized: "拡張属性", table: "Playback")) {
                    InfoRow(icon: "checkmark.seal", label: "完全性", value: "検証済み")
                    InfoRow(icon: "lock", label: "暗号化", value: "なし")
                    InfoRow(icon: "tag.circle", label: "カスタムタグ", value: "未設定")
                }
            }
            .padding()
        }
    }

    private func channelConfiguration() -> String {
        switch memo.numberOfChannels {
        case 1: return "モノラル (1ch)"
        case 2: return "ステレオ (2ch)"
        default: return "\(memo.numberOfChannels)チャンネル"
        }
    }

    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
