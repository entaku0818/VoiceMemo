//
//  recordActivityLiveActivity.swift
//  recordActivity
//
//  Created by 遠藤拓弥 on 2024/07/20.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct recordActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct recordActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: recordActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Recording Status: 録音中")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Recording Status: 録音中")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.emoji)")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Recording Status: 録音中")
                    // more content
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
}

extension recordActivityAttributes {
    fileprivate static var preview: recordActivityAttributes {
        recordActivityAttributes(name: "World")
    }
}

extension recordActivityAttributes.ContentState {
    fileprivate static var recording: recordActivityAttributes.ContentState {
        recordActivityAttributes.ContentState(emoji: "🔴")
    }
}
