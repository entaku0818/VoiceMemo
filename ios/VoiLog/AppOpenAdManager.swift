//
//  InterstitialAdManager.swift
//  VoiLog
//
//  Created by Claude on 2026.
//

import GoogleMobileAds
import UIKit
import os.log

final class InterstitialAdManager: NSObject {
    static let shared = InterstitialAdManager()

    private var interstitialAd: GADInterstitialAd?
    private var isLoading = false
    private var onDismiss: (() -> Void)?
    private var onAdLoaded: ((Bool) -> Void)?

    /// 広告を表示する間隔（何回に1回表示するか）
    private let displayInterval = 5

    /// 広告がロード済みかどうか
    var isAdReady: Bool {
        return interstitialAd != nil
    }

    override private init() {
        super.init()
    }

    /// 広告をプリロードする
    /// - Parameter completion: ロード完了時に呼ばれるクロージャ（成功時true、失敗時false）
    func preloadAd(completion: ((Bool) -> Void)? = nil) {
        guard !isLoading && interstitialAd == nil else {
            print("[InterstitialAdManager] preloadAd skipped - isLoading: \(isLoading), hasAd: \(interstitialAd != nil)")
            if interstitialAd != nil {
                completion?(true)
            }
            return
        }
        isLoading = true
        onAdLoaded = completion
        print("[InterstitialAdManager] preloadAd started")

        #if DEBUG
        let adUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用インタースティシャル広告ID
        #else
        let adUnitID = Bundle.main.object(forInfoDictionaryKey: "INTERSTITIAL_ADMOB_KEY") as? String ?? ""
        #endif

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            self?.isLoading = false

            if let error = error {
                print("[InterstitialAdManager] Failed to load ad: \(error.localizedDescription)")
                self?.onAdLoaded?(false)
                self?.onAdLoaded = nil
                return
            }

            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            print("[InterstitialAdManager] Ad loaded successfully")
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
        let isPremium = UserDefaultsManager.shared.hasPurchasedProduct
        let hasAd = interstitialAd != nil

        print("[InterstitialAdManager] showAdIfNeeded - count: \(appUsageCount), isPremium: \(isPremium), hasAd: \(hasAd)")

        // プレミアムユーザーは広告を表示しない
        guard !isPremium else {
            print("[InterstitialAdManager] Skipped - premium user")
            return false
        }

        // 5回に1回表示（5, 10, 15, 20...回目の起動時）
        guard appUsageCount > 0 && appUsageCount % displayInterval == 0 else {
            print("[InterstitialAdManager] Skipped - not display turn (count: \(appUsageCount) % \(displayInterval) = \(appUsageCount % displayInterval))")
            // 次回のために広告をプリロード
            preloadAd()
            return false
        }

        // 広告を表示
        guard let ad = interstitialAd else {
            print("[InterstitialAdManager] No ad available, loading...")
            preloadAd()
            return false
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("[InterstitialAdManager] No root view controller")
            return false
        }

        self.onDismiss = onDismiss
        ad.present(fromRootViewController: rootViewController)
        print("[InterstitialAdManager] Ad presented at launch count: \(appUsageCount)")
        return true
    }
}

// MARK: - GADFullScreenContentDelegate
extension InterstitialAdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("[InterstitialAdManager] Ad dismissed")
        interstitialAd = nil
        // 次回のために新しい広告をプリロード
        preloadAd()
        // クロージャを呼び出し
        onDismiss?()
        onDismiss = nil
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[InterstitialAdManager] Failed to present: \(error.localizedDescription)")
        interstitialAd = nil
        preloadAd()
        // 失敗時もクロージャを呼び出し
        onDismiss?()
        onDismiss = nil
    }

    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        print("[InterstitialAdManager] Impression recorded")
    }

    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        print("[InterstitialAdManager] Ad clicked")
    }
}
