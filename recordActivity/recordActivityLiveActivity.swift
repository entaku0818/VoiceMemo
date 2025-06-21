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
        // Dynamic stateful properties about your activity go here!
        var emoji: String
        var recordingTime: TimeInterval // 録音時間を追加
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct RecordActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                HStack {
                    Spacer().frame(width: 16)
                    Text("録音中") // 録音時間を表示
                        .foregroundColor(.white)
                    Text("\(formatTimeInterval(context.state.recordingTime))") // 録音時間を表示
                        .font(.largeTitle) // フォントサイズを大きく設定
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.red)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("録音中")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.emoji)")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        HStack {
                            Text(formatTimeInterval(context.state.recordingTime))
                                .font(.largeTitle) // フォントサイズを大きく設定
                            Spacer()
                        }
                    }
                }
            } compactLeading: {
                Text("録音中")
            } compactTrailing: {
                Text("\(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
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
        RecordActivityAttributes.ContentState(emoji: "🔴", recordingTime: 0)
    }
}
