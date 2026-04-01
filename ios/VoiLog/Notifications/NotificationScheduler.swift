import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private init() {}

    // D1: インストール翌日（24時間後）— 未録音の場合のみ有効
    func scheduleD1Notification() {
        let content = UNMutableNotificationContent()
        content.title = "VoiLog"
        content.body = NSLocalizedString("今日のひとこと、声で残しませんか？30秒でOK 🎙", comment: "D1 notification body: no recordings yet")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "voilog_d1", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // D3: インストール3日後 — 長期未起動ユーザー向け
    func scheduleD3Notification() {
        let content = UNMutableNotificationContent()
        content.title = "VoiLog"
        content.body = NSLocalizedString("この3日間の気づき、まだ間に合います 🎙", comment: "D3 notification body: long absence")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "voilog_d3", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // 録音完了時に D1/D3 キャンセル
    func cancelRetentionNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["voilog_d1", "voilog_d3"]
        )
    }

    // 毎日リマインダー（ユーザー設定時刻）
    func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "VoiLog"
        content.body = NSLocalizedString("今日どんな1日でしたか？声で残す時間です 🎙", comment: "Daily reminder notification body")
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "voilog_daily", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["voilog_daily"]
        )
    }
}
