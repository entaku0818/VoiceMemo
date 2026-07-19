//
//  RecordingControlIntents.swift
//  recordActivity
//
//  ライブアクティビティ/Dynamic Islandのボタンから一時停止/再開/停止を操作するIntent（issue #189）。
//
//  Widget Extensionのプロセスで実行されるため、実際の録音を行っているホストアプリの
//  RecordingFeature（TCA Store）には直接アクセスできない。そのためDarwin Notification
//  （プロセス境界をまたいで通知できる軽量な仕組み）でホストアプリに操作を伝える。
//  通知名は `ios/VoiLog/Recording/RecordingControlSignal.swift` の値と一致させること。
//

import AppIntents
import Foundation

enum RecordingControlDarwinNotification {
    static let pause = "com.entaku.VoiLog.liveActivity.pause"
    static let resume = "com.entaku.VoiLog.liveActivity.resume"
    static let stop = "com.entaku.VoiLog.liveActivity.stop"
}

private func postDarwinNotification(_ name: String) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(name as CFString),
        nil,
        nil,
        true
    )
}

struct PauseRecordingLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("一時停止")

    func perform() async throws -> some IntentResult {
        postDarwinNotification(RecordingControlDarwinNotification.pause)
        return .result()
    }
}

struct ResumeRecordingLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("再開")

    func perform() async throws -> some IntentResult {
        postDarwinNotification(RecordingControlDarwinNotification.resume)
        return .result()
    }
}

struct StopRecordingLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("停止")

    func perform() async throws -> some IntentResult {
        postDarwinNotification(RecordingControlDarwinNotification.stop)
        return .result()
    }
}
