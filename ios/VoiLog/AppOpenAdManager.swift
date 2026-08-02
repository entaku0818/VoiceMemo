//
//  AppOpenAdManager.swift
//  VoiLog
//
//  Created by Claude on 2026.
//

import GoogleMobileAds
import UIKit
import Dependencies

final class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    @Dependency(\.userDefaults) var userDefaults

    private var appOpenAd: AppOpenAd?
    private var isLoading = false
    private var loadTime: Date?
    private var onDismiss: (() -> Void)?
    private var onAdLoaded: ((Bool) -> Void)?

    /// 広告を表示する間隔（何回に1回表示するか）
    /// SplashView側も必ずこの値を参照すること（別々の値を持つと二重ゲートで表示が握りつぶされる）
    let displayInterval = 5

    /// 広告の有効期限（4時間）
    private let adExpirationHours: TimeInterval = 4

    /// 広告がロード済みかどうか
    var isAdReady: Bool {
        appOpenAd != nil && !isAdExpired
    }

    /// 広告を全画面表示中かどうか（スプラッシュ側のタイムアウト判定に使う）
    private(set) var isPresentingAd = false

    /// 広告が期限切れかどうか
    private var isAdExpired: Bool {
        guard let loadTime = loadTime else { return true }
        let now = Date()
        let timeIntervalBetweenNowAndLoadTime = now.timeIntervalSince(loadTime)
        return timeIntervalBetweenNowAndLoadTime > (adExpirationHours * 3600)
    }

    override private init() {
        super.init()
    }

    /// 広告をプリロードする
    /// - Parameter completion: ロード完了時に呼ばれるクロージャ（成功時true、失敗時false）
    func preloadAd(completion: ((Bool) -> Void)? = nil) {
        // プレミアムユーザーには広告を表示しないので、リクエスト自体を投げない
        guard !userDefaults.hasPurchasedProduct() else {
            completion?(false)
            return
        }

        guard !isLoading && appOpenAd == nil else {
            if appOpenAd != nil {
                completion?(true)
            }
            return
        }
        isLoading = true
        onAdLoaded = completion

        #if DEBUG
        let adUnitID = "ca-app-pub-3940256099942544/5575463023" // テスト用App Open広告ID
        #else
        let adUnitID = Bundle.main.object(forInfoDictionaryKey: "INTERSTITIAL_ADMOB_KEY") as? String ?? ""
        #endif

        AppOpenAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            self?.isLoading = false

            if error != nil {
                self?.onAdLoaded?(false)
                self?.onAdLoaded = nil
                return
            }

            self?.appOpenAd = ad
            self?.appOpenAd?.fullScreenContentDelegate = self
            self?.loadTime = Date()
            self?.onAdLoaded?(true)
            self?.onAdLoaded = nil
        }
    }

    /// 起動時に広告を表示するかどうかを判定し、表示する
    /// - Parameters:
    ///   - onDismiss: 広告が閉じられた時に呼ばれるクロージャ
    /// - Returns: 広告が表示された場合はtrue
    @discardableResult
    func showAdIfNeeded(onDismiss: (() -> Void)? = nil) -> Bool {
        let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")
        let isPremium = userDefaults.hasPurchasedProduct()

        // プレミアムユーザーは広告を表示しない
        guard !isPremium else {
            return false
        }

        // displayInterval回に1回表示（5, 10, 15, 20...回目の起動時）
        guard appUsageCount > 0 && appUsageCount % displayInterval == 0 else {
            // 次回のために広告をプリロード
            preloadAd()
            return false
        }

        // 期限切れの広告はリロード
        if isAdExpired {
            appOpenAd = nil
            loadTime = nil
            preloadAd()
            return false
        }

        // 広告を表示
        guard let ad = appOpenAd else {
            preloadAd()
            return false
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return false
        }

        self.onDismiss = onDismiss
        isPresentingAd = true
        ad.present(from: rootViewController)
        return true
    }
}

// MARK: - FullScreenContentDelegate
extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresentingAd = false
        appOpenAd = nil
        loadTime = nil
        // 次回のために新しい広告をプリロード
        preloadAd()
        // クロージャを呼び出し
        onDismiss?()
        onDismiss = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        isPresentingAd = false
        appOpenAd = nil
        loadTime = nil
        preloadAd()
        // 失敗時もクロージャを呼び出し
        onDismiss?()
        onDismiss = nil
    }
}
