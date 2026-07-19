//
//  RecordActivityWidgetView.swift
//  recordActivity
//
//  録音中ステータスのライブアクティビティ/Dynamic Island UI（issue #189）。
//  `RecordActivityAttributes` は `recordActivityLiveActivity.swift`（VoiLog本体にも
//  含まれる共有ファイル）で定義している。このファイルはWidget Extension専用。
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RecordActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Recording indicator
                    ZStack {
                        Circle()
                            .fill(context.state.isPaused ? Color.orange : Color.red)
                            .frame(width: 40, height: 40)
                        Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.isPaused ? String(localized: "一時停止中") : String(localized: "録音中"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTimeInterval(context.state.recordingTime))
                            .font(.title2.monospacedDigit().bold())
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Text(String(localized: "シンプル録音"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                RecordingControlButtons(isPaused: context.state.isPaused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.red)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(context.state.isPaused ? Color.orange : Color.red)
                                .frame(width: 32, height: 32)
                            Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        Text(context.state.isPaused ? String(localized: "一時停止") : String(localized: "録音中"))
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTimeInterval(context.state.recordingTime))
                        .font(.title3.monospacedDigit().bold())
                        .foregroundColor(context.state.isPaused ? .orange : .red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RecordingControlButtons(isPaused: context.state.isPaused)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(context.state.isPaused ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                        .foregroundColor(context.state.isPaused ? .orange : .red)
                }
            } compactTrailing: {
                Text(formatTimeInterval(context.state.recordingTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(context.state.isPaused ? .orange : .red)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "mic.circle.fill")
                    .foregroundColor(context.state.isPaused ? .orange : .red)
            }
            .keylineTint(Color.red)
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// ライブアクティビティ/Dynamic Island（展開時）から一時停止/再開・停止を操作するボタン。
/// `LiveActivityIntent`はWidget Extensionのプロセスで実行され、Darwin Notification経由で
/// ホストアプリ（VoiLog）に操作を伝える（`RecordingControlIntents.swift`参照）。
struct RecordingControlButtons: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isPaused {
                Button(intent: ResumeRecordingLiveActivityIntent()) {
                    Label(String(localized: "再開"), systemImage: "play.fill")
                }
            } else {
                Button(intent: PauseRecordingLiveActivityIntent()) {
                    Label(String(localized: "一時停止"), systemImage: "pause.fill")
                }
            }

            Button(intent: StopRecordingLiveActivityIntent()) {
                Label(String(localized: "停止"), systemImage: "stop.fill")
            }
            .tint(.red)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
    }
}

extension RecordActivityAttributes {
    fileprivate static var preview: RecordActivityAttributes {
        RecordActivityAttributes(name: "World")
    }
}

extension RecordActivityAttributes.ContentState {
    fileprivate static var recording: RecordActivityAttributes.ContentState {
        RecordActivityAttributes.ContentState(emoji: "🔴", recordingTime: 65, isPaused: false)
    }

    fileprivate static var paused: RecordActivityAttributes.ContentState {
        RecordActivityAttributes.ContentState(emoji: "⏸️", recordingTime: 65, isPaused: true)
    }
}
