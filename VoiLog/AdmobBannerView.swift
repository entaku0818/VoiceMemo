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
    func makeUIView(context: Context) -> GADBannerView {
        let adSize = GADAdSizeFromCGSize(CGSize(width: 300, height: 50))
        let view = GADBannerView(adSize: adSize)
        #if DEBUG
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        view.adUnitID = ""
        #endif
        view.rootViewController = UIApplication.shared.windows.first?.rootViewController
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
    }
}
