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

        // NOTE: GDPR同意管理(UMP)は未導入。メディエーションを導入する際は同意状態の取得と
        // 各ネットワークへの伝達が前提になる（詳細はissue #212 / docs/ad_mediation_plan.md）

        // Initialize Mobile Ads SDK
        // NOTE: RewardedAdControllerのプリロードはここで呼んでいたが、showAd()の呼び出し元が
        // 存在せず、毎起動リクエストだけ投げて1インプレッションも出していなかったため削除した。
        // iOS同等の「リワード視聴で文字起こしアンロック」導線を実装する際に復活させること。
        MobileAds.initialize(this) {
            AppOpenAdController.getInstance(this).loadAd()
        }
    }
}
