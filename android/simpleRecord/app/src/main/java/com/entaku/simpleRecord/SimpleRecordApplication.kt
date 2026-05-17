package com.entaku.simpleRecord

import android.app.Application
import com.entaku.simpleRecord.analytics.FirebaseHelper
import com.entaku.simpleRecord.notification.ReminderScheduler
import com.entaku.simpleRecord.store.BillingRepository
import com.google.android.gms.ads.MobileAds

class SimpleRecordApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        FirebaseHelper.initialize()

        ReminderScheduler.createNotificationChannel(this)
        ReminderScheduler.scheduleIfNeeded(this)

        // Initialize Mobile Ads SDK
        MobileAds.initialize(this) {
            AppOpenAdManager.getInstance(this).loadAd()
            RewardedAdManager.getInstance(this).loadAd()
        }

        // Restore billing state on launch
        BillingRepository.getInstance(this).connect()
    }
}
