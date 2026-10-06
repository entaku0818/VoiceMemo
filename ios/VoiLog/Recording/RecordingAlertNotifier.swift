import Foundation
import UserNotifications

/// 録音が意図せず止まったことを知らせるローカル通知（#226）。
///
/// 割り込みのあと再開できなかったときや、メディアサービスのリセットでレコーダーが使えなくなったとき、
/// アプリはバックグラウンドにいることが多い。画面の表示だけでは気づけず、何時間も録れていないままになるので通知する。
/// 通知の許可がなければ何もしない（ここで許可を求めることはしない）。
enum RecordingAlertNotifier {
    static let identifier = "recording-paused-alert"

    static func notifyRecordingPaused() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "録音が一時停止しています", table: "Recording")
            content.body = String(localized: "録音を続けられませんでした。アプリを開いて再開してください。", table: "Recording")
            content.sound = .default
            // 同じ識別子で出し直すので、何度止まっても通知は1件にまとまる
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }
    }
}
