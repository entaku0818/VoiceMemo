import Foundation

/// 非課金ユーザーに月1回（30日に1回）だけ課金案内を自動表示するかの判定。issue #228
///
/// 判定だけを持つ純粋なロジックにして、表示タイミング（起動時・録音保存直後）の
/// 都合は `VoiceAppFeature` 側で `isBusy` / `hasCompetingPrompt` として渡す。
enum MonthlyPaywallPolicy {
  /// 自動の課金案内（この月1案内と、10回目録音時のトライアル訴求）の最短間隔
  static let interval: TimeInterval = 30 * 24 * 60 * 60
  /// 初めて使い始めてから案内を出さない期間
  static let gracePeriod: TimeInterval = 3 * 24 * 60 * 60

  enum Trigger: String, Equatable {
    case launch
    case afterRecording = "after_recording"
  }

  /// - Parameters:
  ///   - firstSeenAt: このアプリを初めて使った日時。未記録なら出さない
  ///   - lastShownAt: 前回、自動で課金案内を出した日時
  ///   - isBusy: 録音中・一時停止中・エンコード中・再生中
  ///   - hasCompetingPrompt: 同じタイミングで別のモーダル（チュートリアル、初回録音のお祝い、
  ///     トライアル訴求、App Open 広告）が出る
  static func shouldShow(
    now: Date,
    isPremium: Bool,
    firstSeenAt: Date?,
    lastShownAt: Date?,
    isBusy: Bool,
    hasCompetingPrompt: Bool
  ) -> Bool {
    guard !isPremium, !isBusy, !hasCompetingPrompt else { return false }
    guard let firstSeenAt, now.timeIntervalSince(firstSeenAt) >= gracePeriod else { return false }
    if let lastShownAt, now.timeIntervalSince(lastShownAt) < interval {
      return false
    }
    return true
  }

  /// この起動で App Open 広告が出る回か（`AppOpenAdManager.showAdIfNeeded` と同じ条件）
  static func isAppOpenAdLaunch(appUsageCount: Int, displayInterval: Int) -> Bool {
    appUsageCount > 0 && displayInterval > 0 && appUsageCount % displayInterval == 0
  }
}

/// ペイウォールを開いたきっかけ。paywall_* イベントの `source` パラメータ（購入の集計キー）
enum PaywallSource: String, Equatable {
  /// 有料機能（同期・編集・文字起こし）に触れて出たもの
  case featureGate = "feature_gate"
  case trialPromotion = "trial_promotion"
  case monthlyLaunch = "monthly_launch"
  case monthlyAfterRecording = "monthly_after_recording"
  case settings
  case appIcon = "app_icon"
  case playlistLimit = "playlist_limit"
  /// AI議事録のロック画面（issue #231）
  case minutesLock = "minutes_lock"
}
