//
//  recordActivityLiveActivity.swift
//  recordActivity
//
//  Created by 遠藤拓弥 on 2024/07/20.
//
//  `RecordActivityAttributes` はホストアプリ（VoiLog）側の `LiveActivityClient` からも
//  参照される（Activity.request/update/end の型引数）ため、このファイルはVoiLog本体
//  ターゲットにも含まれる（project.pbxprojのmembershipExceptions参照）。
//  実際のWidget UI（ボタン等を含む）は `RecordActivityWidgetView.swift`
//  （recordActivityExtensionターゲット専用）に分離している。
//

import ActivityKit
import Foundation

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
