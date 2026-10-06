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
        /// 録音中なら「経過時間が 0 だった時刻」。ウィジェットはここから時間を数えるので、
        /// アプリが毎秒更新しなくても表示が進む（#225）。一時停止中や旧バージョンからの状態では nil
        var timerStartDate: Date?

        init(emoji: String = "🔴", recordingTime: TimeInterval = 0, isPaused: Bool = false, timerStartDate: Date? = nil) {
            self.emoji = emoji
            self.recordingTime = recordingTime
            self.isPaused = isPaused
            self.timerStartDate = timerStartDate
        }
    }

    var name: String
}
