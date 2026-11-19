package com.entaku.simpleRecord

import android.app.Activity
import android.content.Context
import com.entaku.simpleRecord.store.PremiumRepository
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback

class RewardedAdController private constructor(private val context: Context) {

    private var rewardedAd: RewardedAd? = null
    private var isLoadingAd = false
    private var requestGeneration = 0

    companion object {
        private val AD_UNIT_ID = BuildConfig.REWARDED_AD_UNIT_ID

        @Volatile
        private var instance: RewardedAdController? = null

        fun getInstance(context: Context): RewardedAdController {
            return instance ?: synchronized(this) {
                instance ?: RewardedAdController(context.applicationContext).also { instance = it }
            }
        }
    }

    val isAdAvailable: Boolean get() = rewardedAd != null

    fun loadAd(onAdLoaded: ((Boolean) -> Unit)? = null) {
        if (!AdConsentManager.getInstance(context).areAdsAllowed ||
            PremiumRepository.getInstance(context).isPremium.value) {
            onAdLoaded?.invoke(false)
            return
        }
        if (isLoadingAd || isAdAvailable) {
            onAdLoaded?.invoke(isAdAvailable)
            return
        }
        isLoadingAd = true
        val generation = requestGeneration
        val request = AdRequest.Builder().build()
        RewardedAd.load(context, AD_UNIT_ID, request, object : RewardedAdLoadCallback() {
            override fun onAdLoaded(ad: RewardedAd) {
                if (generation != requestGeneration) return
                val allowed = AdConsentManager.getInstance(context).areAdsAllowed &&
                    !PremiumRepository.getInstance(context).isPremium.value
                rewardedAd = if (allowed) ad else null
                isLoadingAd = false
                onAdLoaded?.invoke(allowed)
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                if (generation != requestGeneration) return
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
        if (!AdConsentManager.getInstance(context).areAdsAllowed ||
            PremiumRepository.getInstance(context).isPremium.value || activity.isFinishing || activity.isDestroyed) {
            clearAd()
            onAdDismissed()
            return
        }
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

    fun clearAd() {
        requestGeneration++
        rewardedAd = null
        isLoadingAd = false
    }
}
