//
//  recordActivityLiveActivity.swift
//  recordActivity
//
//  Created by 遠藤拓弥 on 2024/07/20.
//

import ActivityKit
import WidgetKit
import SwiftUI
import ActivityKit
import WidgetKit
import SwiftUI

struct recordActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
        var recordingTime: TimeInterval // 録音時間を追加
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct recordActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: recordActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("🔴 \(formatTimeInterval(context.state.recordingTime))") // 録音時間を表示
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

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
                        Text(formatTimeInterval(context.state.recordingTime))
                    }
                }
            } compactLeading: {
                Text("Rec")
            } compactTrailing: {
                Text("\(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension recordActivityAttributes {
    fileprivate static var preview: recordActivityAttributes {
        recordActivityAttributes(name: "World")
    }
}

extension recordActivityAttributes.ContentState {
    fileprivate static var recording: recordActivityAttributes.ContentState {
        recordActivityAttributes.ContentState(emoji: "🔴", recordingTime: 0)
    }
}
