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

    /// 広告を表示する間隔（何回に1回表示するか）
    private let displayInterval = 5

    override private init() {
        super.init()
    }

    /// 広告をプリロードする
    func preloadAd() {
        guard !isLoading && interstitialAd == nil else { return }
        isLoading = true

        #if DEBUG
        let adUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用インタースティシャル広告ID
        #else
        let adUnitID = Bundle.main.object(forInfoDictionaryKey: "INTERSTITIAL_ADMOB_KEY") as? String ?? ""
        #endif

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            self?.isLoading = false

            if let error = error {
                AppLogger.ui.error("InterstitialAdManager failed to load ad: \(error.localizedDescription)")
                return
            }

            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            AppLogger.ui.debug("InterstitialAdManager ad loaded successfully")
        }
    }

    /// 起動時に広告を表示するかどうかを判定し、表示する
    /// - Returns: 広告が表示された場合はtrue
    @discardableResult
    func showAdIfNeeded() -> Bool {
        // プレミアムユーザーは広告を表示しない
        guard !UserDefaultsManager.shared.hasPurchasedProduct else {
            AppLogger.ui.debug("InterstitialAdManager skipped - premium user")
            return false
        }

        let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")

        // 5回に1回表示（5, 10, 15, 20...回目の起動時）
        guard appUsageCount > 0 && appUsageCount % displayInterval == 0 else {
            AppLogger.ui.debug("InterstitialAdManager skipped - count: \(appUsageCount), interval: \(self.displayInterval)")
            // 次回のために広告をプリロード
            preloadAd()
            return false
        }

        // 広告を表示
        guard let ad = interstitialAd else {
            AppLogger.ui.debug("InterstitialAdManager no ad available, loading...")
            preloadAd()
            return false
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            AppLogger.ui.error("InterstitialAdManager no root view controller")
            return false
        }

        ad.present(fromRootViewController: rootViewController)
        AppLogger.ui.debug("InterstitialAdManager ad presented at launch count: \(appUsageCount)")
        return true
    }
}

// MARK: - GADFullScreenContentDelegate
extension InterstitialAdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        AppLogger.ui.debug("InterstitialAdManager ad dismissed")
        interstitialAd = nil
        // 次回のために新しい広告をプリロード
        preloadAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AppLogger.ui.error("InterstitialAdManager failed to present: \(error.localizedDescription)")
        interstitialAd = nil
        preloadAd()
    }

    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        AppLogger.ui.debug("InterstitialAdManager impression recorded")
    }

    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        AppLogger.ui.debug("InterstitialAdManager ad clicked")
    }
}
