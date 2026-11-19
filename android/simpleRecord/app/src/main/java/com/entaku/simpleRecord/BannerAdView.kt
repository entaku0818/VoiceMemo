package com.entaku.simpleRecord

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.entaku.simpleRecord.store.PremiumRepository
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView

@Composable
fun BannerAdView(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val premiumManager = remember(context) { PremiumRepository.getInstance(context) }
    val consentManager = remember(context) { AdConsentManager.getInstance(context) }
    val isPremium by premiumManager.isPremium.collectAsState()
    val canRequestAds by consentManager.canRequestAds.collectAsState()
    val adRevision by consentManager.adRevision.collectAsState()

    if (!isPremium && canRequestAds) {
        BoxWithConstraints(modifier = modifier, contentAlignment = Alignment.Center) {
            // Use the actual available width, including multi-window and parent padding.
            val adWidth = maxWidth.value.toInt()
            val orientation = LocalConfiguration.current.orientation
            if (adWidth > 0) {
                key(adWidth, orientation, adRevision) {
                    val lifecycleOwner = LocalLifecycleOwner.current
                    val adView = remember(context, adWidth, orientation, lifecycleOwner) {
                        AdView(context).apply {
                            setAdSize(AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(context, adWidth))
                            adUnitId = BuildConfig.BANNER_AD_UNIT_ID
                        }
                    }
                    DisposableEffect(adView, lifecycleOwner) {
                        var hasRequestedAd = false
                        fun resumeIfEligible() {
                            if (consentManager.areAdsAllowed && !premiumManager.isPremium.value) {
                                adView.resume()
                                if (!hasRequestedAd) {
                                    hasRequestedAd = true
                                    adView.loadAd(AdRequest.Builder().build())
                                }
                            }
                        }

                        val observer = LifecycleEventObserver { _, event ->
                            when (event) {
                                Lifecycle.Event.ON_RESUME -> resumeIfEligible()
                                Lifecycle.Event.ON_PAUSE -> adView.pause()
                                else -> Unit
                            }
                        }
                        lifecycleOwner.lifecycle.addObserver(observer)
                        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                            resumeIfEligible()
                        }
                        onDispose {
                            lifecycleOwner.lifecycle.removeObserver(observer)
                            adView.pause()
                            adView.destroy()
                        }
                    }
                    AndroidView(
                        modifier = Modifier.fillMaxWidth(),
                        factory = { adView }
                    )
                }
            }
        }
    }
}
