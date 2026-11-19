package com.entaku.simpleRecord

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.ads.MobileAds
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

internal interface AdsConsentClient {
    val canRequestAds: Boolean
    val isPrivacyOptionsRequired: Boolean
    fun update(activity: Activity, completion: (String?) -> Unit)
    fun loadForm(completion: (AdsConsentForm?, String?) -> Unit)
    fun showPrivacyOptions(activity: Activity, completion: (String?) -> Unit)
}

internal fun interface AdsConsentForm {
    fun show(activity: Activity, completion: (String?) -> Unit)
}

private class UmpConsentClient(private val context: Context) : AdsConsentClient {
    private val information = UserMessagingPlatform.getConsentInformation(context)
    override val canRequestAds: Boolean get() = information.canRequestAds()
    override val isPrivacyOptionsRequired: Boolean
        get() = information.privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

    override fun update(activity: Activity, completion: (String?) -> Unit) {
        information.requestConsentInfoUpdate(
            activity,
            ConsentRequestParameters.Builder().build(),
            { completion(null) },
            { completion(it.message) }
        )
    }

    override fun loadForm(completion: (AdsConsentForm?, String?) -> Unit) {
        if (information.consentStatus != ConsentInformation.ConsentStatus.REQUIRED ||
            !information.isConsentFormAvailable) {
            completion(null, null)
            return
        }
        // Separate load and show so a late network response cannot interrupt the recording screen.
        UserMessagingPlatform.loadConsentForm(context, { form ->
            completion(AdsConsentForm { activity, dismissed ->
                form.show(activity) { dismissed(it?.message) }
            }, null)
        }, { completion(null, it.message) })
    }

    override fun showPrivacyOptions(activity: Activity, completion: (String?) -> Unit) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { completion(it?.message) }
    }
}

/** Every ad request and presentation uses this gate, including after privacy choices change. */
class AdConsentManager internal constructor(
    private val consentClient: AdsConsentClient,
    private val initializeAds: (() -> Unit) -> Unit,
    private val clearCachedAds: () -> Unit = {},
    private val scheduleTimeout: (Long, () -> Unit) -> (() -> Unit) = { delay, block ->
        val handler = Handler(Looper.getMainLooper())
        val runnable = Runnable { block() }
        handler.postDelayed(runnable, delay)
        val cancel: () -> Unit = { handler.removeCallbacks(runnable) }
        cancel
    }
) {
    private val _canRequestAds = MutableStateFlow(false)
    val canRequestAds: StateFlow<Boolean> = _canRequestAds.asStateFlow()
    val areAdsAllowed: Boolean get() = _canRequestAds.value && consentClient.canRequestAds

    private val _privacyOptionsRequired = MutableStateFlow(false)
    val privacyOptionsRequired: StateFlow<Boolean> = _privacyOptionsRequired.asStateFlow()
    private val _adRevision = MutableStateFlow(0)
    val adRevision: StateFlow<Int> = _adRevision.asStateFlow()

    private var isInitializingAds = false
    private var adsInitialized = false
    private var isPrivacyFormShowing = false
    var isPresentingConsentForm = false
        private set
    private var consentGeneration = 0
    private val initializationWaiters = mutableListOf<() -> Unit>()

    fun gatherConsent(
        activity: Activity,
        showFormIfRequired: Boolean = true,
        canPresentForm: () -> Boolean = { true },
        completion: () -> Unit = {}
    ) {
        val generation = ++consentGeneration
        var settled = false
        var timedOut = false
        var cancelDeadline: () -> Unit = {}
        fun settle() {
            if (settled) return
            settled = true
            cancelDeadline()
            completion()
        }
        fun armDeadline() {
            cancelDeadline()
            cancelDeadline = scheduleTimeout(STARTUP_TIMEOUT_MS) {
                if (settled) return@scheduleTimeout
                if (generation != consentGeneration) {
                    settle()
                    return@scheduleTimeout
                }
                timedOut = true
                disableAds()
                settle()
            }
        }
        armDeadline()
        // UMP requires a fresh update each launch; on errors it may use the previous session's choice.
        consentClient.update(activity) { error ->
            if (generation != consentGeneration) {
                settle()
                return@update
            }
            _privacyOptionsRequired.value = consentClient.isPrivacyOptionsRequired
            if (timedOut) return@update
            if (error != null) {
                Log.w(TAG, "Consent update failed: $error")
                updateAdPermission(::settle, mayEnableAds = { !timedOut && generation == consentGeneration })
            } else if (showFormIfRequired && canPresentForm() && !activity.isFinishing && !activity.isDestroyed) {
                consentClient.loadForm { form, formError ->
                    if (generation != consentGeneration) {
                        settle()
                        return@loadForm
                    }
                    if (timedOut) return@loadForm
                    if (formError != null) Log.w(TAG, "Consent form failed: $formError")
                    if (form != null && canPresentForm() && !activity.isFinishing && !activity.isDestroyed) {
                        cancelDeadline()
                        isPresentingConsentForm = true
                        form.show(activity) { showError ->
                            isPresentingConsentForm = false
                            if (showError != null) Log.w(TAG, "Consent form failed: $showError")
                            // Never time out the user's answer. Only bound network and SDK work.
                            if (generation != consentGeneration) {
                                settle()
                            } else {
                                armDeadline()
                                updateAdPermission(::settle, mayEnableAds = { !timedOut && generation == consentGeneration })
                            }
                        }
                    } else {
                        updateAdPermission(::settle, mayEnableAds = { !timedOut && generation == consentGeneration })
                    }
                }
            } else {
                updateAdPermission(::settle, mayEnableAds = { !timedOut && generation == consentGeneration })
            }
        }
    }

    fun showPrivacyOptions(activity: Activity, completion: (String?) -> Unit = {}) {
        consentGeneration++
        isPrivacyFormShowing = true
        disableAds()
        consentClient.showPrivacyOptions(activity) { error ->
            isPrivacyFormShowing = false
            updateAdPermission(completion = { completion(error) })
        }
    }

    private fun disableAds() {
        _canRequestAds.value = false
        _adRevision.value++
        clearCachedAds()
    }

    private fun updateAdPermission(completion: () -> Unit, mayEnableAds: () -> Boolean = { true }) {
        _privacyOptionsRequired.value = consentClient.isPrivacyOptionsRequired
        if (!mayEnableAds()) {
            completion()
            return
        }
        if (!consentClient.canRequestAds || isPrivacyFormShowing) {
            disableAds()
            completion()
            return
        }
        if (adsInitialized) {
            _canRequestAds.value = true
            completion()
            return
        }
        initializationWaiters.add { updateAdPermission(completion, mayEnableAds) }
        if (isInitializingAds) return
        isInitializingAds = true
        initializeAds {
            adsInitialized = true
            isInitializingAds = false
            val waiters = initializationWaiters.toList()
            initializationWaiters.clear()
            waiters.forEach { it() }
        }
    }

    companion object {
        private const val TAG = "AdConsentManager"
        private const val STARTUP_TIMEOUT_MS = 3000L
        @Volatile private var instance: AdConsentManager? = null

        fun getInstance(context: Context): AdConsentManager = instance ?: synchronized(this) {
            instance ?: context.applicationContext.let { appContext ->
                AdConsentManager(
                    consentClient = UmpConsentClient(appContext),
                    initializeAds = { completion ->
                        MobileAds.initialize(appContext) {
                            Handler(Looper.getMainLooper()).post { completion() }
                        }
                    },
                    clearCachedAds = {
                        AppOpenAdController.getInstance(appContext).clearAd()
                        RewardedAdController.getInstance(appContext).clearAd()
                    }
                ).also { instance = it }
            }
        }
    }
}
