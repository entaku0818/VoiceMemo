//
//  recordActivityLiveActivity.swift
//  recordActivity
//
//  Created by 遠藤拓弥 on 2024/07/20.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RecordActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
        var recordingTime: TimeInterval
        var isPaused: Bool

        init(emoji: String = "🔴", recordingTime: TimeInterval = 0, isPaused: Bool = false) {
            self.emoji = emoji
            self.recordingTime = recordingTime
            self.isPaused = isPaused
        }
    }

    var name: String
}

struct RecordActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordActivityAttributes.self) { context in
            // Lock Screen / Banner UI
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
                    Text(context.state.isPaused ? "一時停止中" : "録音中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTimeInterval(context.state.recordingTime))
                        .font(.title2.monospacedDigit().bold())
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("シンプル録音")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                        Text(context.state.isPaused ? "一時停止" : "録音中")
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
                    Text("シンプル録音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
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
