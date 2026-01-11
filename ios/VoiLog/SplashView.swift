//
//  SplashView.swift
//  VoiLog
//
//  Created by Claude on 2026.
//

import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // アプリアイコン
                    Image(.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                        .shadow(radius: 10)

                    // アプリ名
                    Text("シンプル録音")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            checkAndShowAd()
        }
    }

    private func checkAndShowAd() {
        let isPremium = UserDefaultsManager.shared.hasPurchasedProduct
        let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")

        // プレミアムユーザーはスキップ
        guard !isPremium else {
            completeAfterDelay(delay: 0.5)
            return
        }

        // 5回に1回広告表示
        let shouldShowAd = appUsageCount > 0 && appUsageCount % 5 == 0

        if shouldShowAd {
            loadAndShowAd()
        } else {
            completeAfterDelay(delay: 1.0)
        }
    }

    private func loadAndShowAd() {
        // 既に広告がロード済みの場合
        if AppOpenAdManager.shared.isAdReady {
            showAdAndComplete()
            return
        }

        // 広告をプリロード（ロード完了を待つ）
        AppOpenAdManager.shared.preloadAd { [self] success in
            if success {
                showAdAndComplete()
            } else {
                completeAfterDelay(delay: 0.5)
            }
        }

        // タイムアウト（5秒後に広告ロードを諦める）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [self] in
            if !AppOpenAdManager.shared.isAdReady {
                completeAfterDelay(delay: 0.0)
            }
        }
    }

    private func showAdAndComplete() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let adShown = AppOpenAdManager.shared.showAdIfNeeded {
                onComplete()
            }
            if !adShown {
                completeAfterDelay(delay: 0.5)
            }
        }
    }

    private func completeAfterDelay(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onComplete()
        }
    }
}

#Preview {
    SplashView {
    }
}
