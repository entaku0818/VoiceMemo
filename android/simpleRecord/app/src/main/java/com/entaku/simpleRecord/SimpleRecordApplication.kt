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

        // NOTE: com.facebook.ads.AdSettings.setAdvertiserTrackingEnabled(Boolean) はiOS版FBAudienceNetwork
        // (Objective-C/Swift) のAPIであり、Android版audience-network-sdk 6.21.0には存在しない
        // (App Tracking TransparencyはApple固有の仕組みのため)。そのためAndroidでは何も呼び出していない。
        // GDPR同意管理(UMP)も未導入のため、Meta側の同意関連設定(AdSettings.setDataProcessingOptions等)は
        // 未実装のまま。導入時は実際の同意状態を渡すこと（詳細はissue #212）

        // Initialize Mobile Ads SDK
        // NOTE: RewardedAdControllerのプリロードはここで呼んでいたが、showAd()の呼び出し元が
        // 存在せず、毎起動リクエストだけ投げて1インプレッションも出していなかったため削除した。
        // iOS同等の「リワード視聴で文字起こしアンロック」導線を実装する際に復活させること。
        MobileAds.initialize(this) {
            AppOpenAdController.getInstance(this).loadAd()
        }
    }
}
