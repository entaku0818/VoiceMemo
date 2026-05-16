package com.entaku.simpleRecord

import android.app.Activity
import android.content.Context
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback

class RewardedAdManager private constructor(private val context: Context) {

    private var rewardedAd: RewardedAd? = null
    private var isLoadingAd = false

    companion object {
        private val AD_UNIT_ID = BuildConfig.REWARDED_AD_UNIT_ID

        @Volatile
        private var instance: RewardedAdManager? = null

        fun getInstance(context: Context): RewardedAdManager {
            return instance ?: synchronized(this) {
                instance ?: RewardedAdManager(context.applicationContext).also { instance = it }
            }
        }
    }

    val isAdAvailable: Boolean get() = rewardedAd != null

    fun loadAd(onAdLoaded: ((Boolean) -> Unit)? = null) {
        if (isLoadingAd || isAdAvailable) {
            onAdLoaded?.invoke(isAdAvailable)
            return
        }

        isLoadingAd = true
        val request = AdRequest.Builder().build()
        RewardedAd.load(context, AD_UNIT_ID, request, object : RewardedAdLoadCallback() {
            override fun onAdLoaded(ad: RewardedAd) {
                rewardedAd = ad
                isLoadingAd = false
                onAdLoaded?.invoke(true)
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                rewardedAd = null
                isLoadingAd = false
                onAdLoaded?.invoke(false)
            }
        })
    }

    fun showAd(
        activity: Activity,
        onUserEarnedReward: () -> Unit,
        onAdDismissed: () -> Unit
    ) {
        val ad = rewardedAd ?: run {
            loadAd()
            onAdDismissed()
            return
        }

        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                rewardedAd = null
                loadAd()
                onAdDismissed()
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                rewardedAd = null
                loadAd()
                onAdDismissed()
            }
        }

        ad.show(activity) { _ -> onUserEarnedReward() }
    }
}
