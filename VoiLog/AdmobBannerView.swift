//
//  AdmobBannerView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 9.6.2023.
//

import UIKit
import SwiftUI

import GoogleMobileAds


struct AdmobBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let adSize = GADAdSizeFromCGSize(CGSize(width: 300, height: 50))
        let view = GADBannerView(adSize: adSize)
        if let variableValue = EnvironmentProcess.getEnvironmentVariable("ADMOB_UNIT_ID") {
            view.adUnitID = variableValue
        }
        view.rootViewController = UIApplication.shared.windows.first?.rootViewController
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
    }
}
