//
//  AdmobBannerView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 9.6.2023.
//

import GoogleMobileAds
import UIKit
import SwiftUI
import os.log

struct AdmobBannerView: UIViewRepresentable {

    private let unitId: String
    init(unitId: String) {
        self.unitId = unitId
    }

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)

        #if DEBUG
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        view.adUnitID = unitId
        #endif
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            view.rootViewController = windowScene.windows.first?.rootViewController
        }
        view.delegate = context.coordinator
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
    }

    // Adding the Coordinator for delegate handling
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewDelegate {

        // 広告受信時
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            AppLogger.ui.debug("AdmobBannerView ad received - adUnitID: \(bannerView.adUnitID ?? "nil")")
        }

        // 広告受信失敗時
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            AppLogger.ui.error("AdmobBannerView failed to load ad - adUnitID: \(bannerView.adUnitID ?? "nil"), error: \(error.localizedDescription)")
        }

        // インプレッションが記録された時
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            AppLogger.ui.debug("AdmobBannerView impression recorded")
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            AppLogger.ui.debug("AdmobBannerView ad clicked")
        }
        func bannerViewWillPresentScreen(_: BannerView) {
            AppLogger.ui.debug("AdmobBannerView bannerViewWillPresentScreen")
        }

        func bannerViewWillDismissScreen(_: BannerView) {
            AppLogger.ui.debug("AdmobBannerView bannerViewWillDismissScreen")
        }

        func bannerViewDidDismissScreen(_: BannerView) {
            AppLogger.ui.debug("AdmobBannerView bannerViewDidDismissScreen")
        }
    }
}
