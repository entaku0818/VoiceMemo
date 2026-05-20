package com.entaku.simpleRecord

import android.app.Application
import com.entaku.simpleRecord.analytics.FirebaseHelper
import com.entaku.simpleRecord.notification.ReminderScheduler
import com.google.android.gms.ads.MobileAds
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration

class SimpleRecordApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        FirebaseHelper.initialize()

        ReminderScheduler.createNotificationChannel(this)
        ReminderScheduler.scheduleIfNeeded(this)

        // Initialize RevenueCat
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        Purchases.configure(
            PurchasesConfiguration.Builder(this, BuildConfig.REVENUECAT_API_KEY).build()
        )

        // Initialize Mobile Ads SDK
        MobileAds.initialize(this) {
            AppOpenAdController.getInstance(this).loadAd()
            RewardedAdController.getInstance(this).loadAd()
        }
    }
}
