package com.entaku.simpleRecord

import android.app.Activity
import android.content.Context
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.appopen.AppOpenAd
import java.util.Date

class AppOpenAdManager private constructor(private val context: Context) {

    private var appOpenAd: AppOpenAd? = null
    private var isLoadingAd = false
    private var loadTime: Long = 0

    companion object {
        // Ad unit ID from BuildConfig (set via admob.properties)
        private val AD_UNIT_ID = BuildConfig.APP_OPEN_AD_UNIT_ID

        // Display interval (show ad every 5 launches)
        private const val DISPLAY_INTERVAL = 5

        // Ad expiration time (4 hours)
        private const val AD_EXPIRATION_HOURS = 4L

        private const val PREF_NAME = "app_open_ad_prefs"
        private const val KEY_LAUNCH_COUNT = "launch_count"

        @Volatile
        private var instance: AppOpenAdManager? = null

        fun getInstance(context: Context): AppOpenAdManager {
            return instance ?: synchronized(this) {
                instance ?: AppOpenAdManager(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    val isAdAvailable: Boolean
        get() = appOpenAd != null && !isAdExpired

    private val isAdExpired: Boolean
        get() {
            val dateDifference = Date().time - loadTime
            val numMilliSecondsPerHour = 3600000L
            return dateDifference > numMilliSecondsPerHour * AD_EXPIRATION_HOURS
        }

    fun loadAd(onAdLoaded: ((Boolean) -> Unit)? = null) {
        if (isLoadingAd || isAdAvailable) {
            onAdLoaded?.invoke(isAdAvailable)
            return
        }

        isLoadingAd = true

        val request = AdRequest.Builder().build()
        AppOpenAd.load(
            context,
            AD_UNIT_ID,
            request,
            object : AppOpenAd.AppOpenAdLoadCallback() {
                override fun onAdLoaded(ad: AppOpenAd) {
                    appOpenAd = ad
                    isLoadingAd = false
                    loadTime = Date().time
                    onAdLoaded?.invoke(true)
                }

                override fun onAdFailedToLoad(loadAdError: LoadAdError) {
                    isLoadingAd = false
                    onAdLoaded?.invoke(false)
                }
            }
        )
    }

    fun showAdIfNeeded(activity: Activity, onAdDismissed: () -> Unit) {
        val launchCount = getLaunchCount()

        // Show ad every 5 launches (5, 10, 15...)
        if (launchCount <= 0 || launchCount % DISPLAY_INTERVAL != 0) {
            // Preload for next time
            loadAd()
            onAdDismissed()
            return
        }

        if (!isAdAvailable) {
            loadAd()
            onAdDismissed()
            return
        }

        appOpenAd?.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                appOpenAd = null
                loadAd()
                onAdDismissed()
            }

            override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                appOpenAd = null
                loadAd()
                onAdDismissed()
            }

            override fun onAdShowedFullScreenContent() {
                // Ad shown
            }
        }

        appOpenAd?.show(activity)
    }

    fun incrementLaunchCount() {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val currentCount = prefs.getInt(KEY_LAUNCH_COUNT, 0)
        prefs.edit().putInt(KEY_LAUNCH_COUNT, currentCount + 1).apply()
    }

    fun getLaunchCount(): Int {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(KEY_LAUNCH_COUNT, 0)
    }
}
