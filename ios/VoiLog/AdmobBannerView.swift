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

@MainActor
struct AdmobBannerView: View {

    private let unitId: String
    init(unitId: String) {
        self.unitId = unitId
    }

    var body: some View {
        GeometryReader { geometry in
            if AdConsentManager.shared.canLoadAds, geometry.size.width > 0 {
                ConsentGatedBannerView(unitId: unitId, width: geometry.size.width)
                    .frame(width: geometry.size.width,
                           height: currentOrientationAnchoredAdaptiveBanner(width: geometry.size.width).size.height)
                    .id(geometry.size.width)
                    .id(AdConsentManager.shared.adsRevision)
            }
        }
    }

    private static func adaptiveAdSize() -> AdSize {
        let width = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.bounds.width ?? UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }

    static var adaptiveHeight: CGFloat {
        CGFloat(adaptiveAdSize().size.height)
    }
}

@MainActor
private struct ConsentGatedBannerView: UIViewRepresentable {
    let unitId: String
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))

        #if DEBUG
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        view.adUnitID = unitId
        #endif
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            view.rootViewController = windowScene.windows.first?.rootViewController
        }
        view.delegate = context.coordinator
        if AdConsentManager.shared.canLoadAds {
            view.load(Request())
        }
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
    }

    static func dismantleUIView(_ uiView: BannerView, coordinator: Coordinator) {
        uiView.delegate = nil
        uiView.rootViewController = nil
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
