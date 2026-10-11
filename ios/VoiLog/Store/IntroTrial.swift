import Foundation

/// 課金画面に出す「無料トライアル」の情報。issue #232
///
/// 日数や有無は文言に埋め込まず、StoreKit の introductory offer と、
/// RevenueCat の適格判定（過去に使っていないか）から決める。
enum IntroTrial: Equatable {
    /// N日間無料（StoreKit の週単位は日数に直す）
    case days(Int)
    /// 月・年単位の無料期間。日数に直すと不正確になるので、期間を出さずに「無料で試す」とだけ表示する
    case unspecifiedLength

    enum PeriodUnit: Equatable {
        case day, week, month, year
    }

    enum Eligibility: Equatable {
        case eligible
        case ineligible
        case unknown
        case noIntroOfferExists
    }

    /// 表示するトライアルを決める。表示しないなら nil。
    /// - 無料トライアル（freeTrial）以外のお試し価格は対象外
    /// - 適格と確定した人だけに出す。「対象外」「判定できない」人に出すと、
    ///   無料のつもりで購入して即課金になるおそれがあるため
    static func make(
        isFreeTrial: Bool,
        unit: PeriodUnit?,
        value: Int,
        eligibility: Eligibility
    ) -> IntroTrial? {
        guard isFreeTrial, eligibility == .eligible, let unit, value > 0 else { return nil }
        switch unit {
        case .day: return .days(value)
        case .week: return .days(value * 7)
        case .month, .year: return .unspecifiedLength
        }
    }
}

/// 課金画面の文言（トライアルの有無で切り替える部分）
enum PaywallCopy {
    /// 購入ボタンの1行目
    static func ctaTitle(isAnnual: Bool, trial: IntroTrial?) -> String {
        switch trial {
        case let .days(days):
            return String(localized: "\(days)日間無料で試す", table: "Premium")
        case .unspecifiedLength:
            return String(localized: "無料で試す", table: "Premium")
        case nil:
            return isAnnual
                ? String(localized: "年額プランを始める", table: "Premium")
                : String(localized: "月額プランを始める", table: "Premium")
        }
    }

    /// プランカードやヘッダーに出す「N日間無料」。トライアルが無ければ nil
    static func trialBadge(_ trial: IntroTrial?) -> String? {
        switch trial {
        case let .days(days):
            return String(localized: "\(days)日間無料", table: "Premium")
        case .unspecifiedLength:
            return String(localized: "無料で試す", table: "Premium")
        case nil:
            return nil
        }
    }

    /// 「¥9,000 / 年」のような価格＋期間の表記
    static func pricePerPeriod(price: String, isAnnual: Bool) -> String {
        price + (isAnnual
            ? String(localized: "/ 年", table: "Premium")
            : String(localized: "/ 月", table: "Premium"))
    }

    /// 購入ボタン下の自動更新の説明（Guideline 3.1.2）
    static func disclosure(price: String, isAnnual: Bool, trial: IntroTrial?) -> String {
        let displayPrice = price.isEmpty ? String(localized: "サブスクリプション料金", table: "Premium") : price
        let perPeriod = pricePerPeriod(price: displayPrice, isAnnual: isAnnual)
        if trial != nil {
            return String(localized: "無料トライアル終了後、\(perPeriod)で自動的に課金されます。更新日の24時間前までにAppleのサブスクリプション設定からいつでもキャンセルできます。", table: "Premium")
        }
        return isAnnual
            ? String(localized: "\(displayPrice)/年で自動的に課金されます。更新日の24時間前までにAppleのサブスクリプション設定からいつでもキャンセルできます。", table: "Premium")
            : String(localized: "\(perPeriod)で自動的に課金されます。更新日の24時間前までにAppleのサブスクリプション設定からいつでもキャンセルできます。", table: "Premium")
    }
}
