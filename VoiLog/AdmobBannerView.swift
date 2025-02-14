//
//  AdmobBannerView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 9.6.2023.
//

import GoogleMobileAds
import UIKit
import SwiftUI

struct AdmobBannerView: UIViewRepresentable {

    private let unitId: String
    init(unitId: String) {
        self.unitId = unitId
    }

    func makeUIView(context: Context) -> GADBannerView {
        let adSize = GADAdSizeFromCGSize(CGSize(width: 300, height: 50))
        let view = GADBannerView(adSize: adSize)

        #if DEBUG
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        view.adUnitID = unitId
        #endif
        view.rootViewController = UIApplication.shared.windows.first?.rootViewController
        view.delegate = context.coordinator
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
    }

    // Adding the Coordinator for delegate handling
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, GADBannerViewDelegate {

        // 広告受信時
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("AdmobBannerView adUnitID: \(bannerView.adUnitID)")
            print("AdmobBannerView Ad received successfully.")

        }

        // 広告受信失敗時
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("AdmobBannerView  Failed to load ad with error: \(error.localizedDescription)")
            print("AdmobBannerView adUnitID: \(bannerView.adUnitID)")

        }

        // インプレッションが記録された時
        func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
            print("AdmobBannerView Impression has been recorded for the ad.")
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
            print("AdmobBannerView Ad was clicked.")
        }
        func bannerViewWillPresentScreen(_: GADBannerView) {
            print("AdmobBannerView \(#function) called")
        }

        func bannerViewWillDismissScreen(_: GADBannerView) {
            print("AdmobBannerView \(#function) called")
        }

        func bannerViewDidDismissScreen(_: GADBannerView) {
            print("AdmobBannerView \(#function) called")
        }
    }
}
