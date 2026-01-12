package com.entaku.simpleRecord

import android.app.Application
import com.google.android.gms.ads.MobileAds

class SimpleRecordApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Initialize Mobile Ads SDK
        MobileAds.initialize(this) {
            // Preload app open ad after initialization
            AppOpenAdManager.getInstance(this).loadAd()
        }
    }
}
