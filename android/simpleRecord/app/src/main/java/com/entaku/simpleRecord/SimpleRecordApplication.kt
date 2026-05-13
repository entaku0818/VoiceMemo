package com.entaku.simpleRecord

import android.app.Application
import com.entaku.simpleRecord.analytics.FirebaseHelper
import com.entaku.simpleRecord.notification.ReminderScheduler
import com.google.android.gms.ads.MobileAds

class SimpleRecordApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        FirebaseHelper.initialize()

        ReminderScheduler.createNotificationChannel(this)
        ReminderScheduler.scheduleIfNeeded(this)

        // Initialize Mobile Ads SDK
        MobileAds.initialize(this) {
            // Preload app open ad after initialization
            AppOpenAdManager.getInstance(this).loadAd()
        }
    }
}
