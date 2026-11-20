package com.entaku.simpleRecord.store

import android.app.Activity
import android.content.Context
import android.util.Log
import com.entaku.simpleRecord.BuildConfig
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.interfaces.PurchaseCallback
import com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback
import com.revenuecat.purchases.models.StoreTransaction
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class PlanType {
    MONTHLY,
    ANNUAL,
    OTHER
}

data class PremiumProduct(
    val productId: String,
    val title: String,
    val price: String,
    val planType: PlanType,
    val rcPackage: Package
)

sealed class BillingState {
    object Loading : BillingState()
    data class Ready(val products: List<PremiumProduct>) : BillingState()
    data class Error(val message: String) : BillingState()
    object Purchasing : BillingState()
}

class BillingRepository internal constructor(
    private val context: Context,
    private val purchasesClient: PurchasesClient = RealPurchasesClient
) {

    private val premiumRepository = PremiumRepository.getInstance(context)

    private val _billingState = MutableStateFlow<BillingState>(BillingState.Loading)
    val billingState: StateFlow<BillingState> = _billingState.asStateFlow()

    @Volatile private var connected = false
    private var refreshingPremium = false
    private var premiumRevision = 0L
    private val premiumRefreshWaiters = mutableListOf<(Boolean) -> Unit>()

    fun connect() {
        connected = true
        fetchOfferings()
        refreshPremiumStatus()
    }

    fun disconnect() {
        connected = false
        _billingState.value = BillingState.Loading
    }

    private fun fetchOfferings() {
        purchasesClient.getOfferings(object : ReceiveOfferingsCallback {
            override fun onReceived(offerings: Offerings) {
                if (!connected) return
                val packages = offerings.current?.availablePackages ?: emptyList()
                val products = packages.map { pkg ->
                    PremiumProduct(
                        productId = pkg.product.id,
                        title = pkg.product.title,
                        price = pkg.product.price.formatted,
                        planType = when (pkg.packageType) {
                            PackageType.MONTHLY -> PlanType.MONTHLY
                            PackageType.ANNUAL -> PlanType.ANNUAL
                            else -> PlanType.OTHER
                        },
                        rcPackage = pkg
                    )
                }
                _billingState.value = BillingState.Ready(products)
            }

            override fun onError(error: PurchasesError) {
                if (!connected) return
                if (BuildConfig.DEBUG) Log.e(TAG, "Failed to fetch offerings: ${error.message}")
                _billingState.value = BillingState.Error(error.message)
            }
        })
    }

    /** Refresh independently of the paywall; retain the saved entitlement if the request fails. */
    fun refreshPremiumStatus(completion: (Boolean) -> Unit = {}) {
        premiumRefreshWaiters.add(completion)
        if (refreshingPremium) return
        refreshingPremium = true
        val revisionAtStart = premiumRevision
        purchasesClient.getCustomerInfo(object : ReceiveCustomerInfoCallback {
            override fun onReceived(customerInfo: CustomerInfo) {
                // A purchase, restore, or SDK listener may already have supplied newer information.
                if (revisionAtStart == premiumRevision) updatePremiumStatus(customerInfo)
                finishPremiumRefresh(success = true)
            }

            override fun onError(error: PurchasesError) {
                Log.w(TAG, "Could not fetch customer info: ${error.message}")
                finishPremiumRefresh(success = false)
            }
        })
    }

    private fun finishPremiumRefresh(success: Boolean) {
        refreshingPremium = false
        val waiters = premiumRefreshWaiters.toList()
        premiumRefreshWaiters.clear()
        waiters.forEach { it(success) }
    }

    fun launchPurchaseFlow(activity: Activity, product: PremiumProduct) {
        _billingState.value = BillingState.Purchasing
        purchasesClient.purchase(
            activity = activity,
            pkg = product.rcPackage,
            callback = object : PurchaseCallback {
                override fun onCompleted(storeTransaction: StoreTransaction, customerInfo: CustomerInfo) {
                    updatePremiumStatus(customerInfo)
                    fetchOfferings()
                }

                override fun onError(error: PurchasesError, userCancelled: Boolean) {
                    if (!userCancelled) {
                        if (BuildConfig.DEBUG) Log.e(TAG, "Purchase failed: ${error.message}")
                        _billingState.value = BillingState.Error(error.message)
                    } else {
                        fetchOfferings()
                    }
                }
            }
        )
    }

    fun restorePurchases(onComplete: (Boolean) -> Unit) {
        purchasesClient.restorePurchases(object : ReceiveCustomerInfoCallback {
            override fun onReceived(customerInfo: CustomerInfo) {
                updatePremiumStatus(customerInfo)
                onComplete(customerInfo.entitlements[PREMIUM_ENTITLEMENT_KEY]?.isActive == true)
            }

            override fun onError(error: PurchasesError) {
                if (BuildConfig.DEBUG) Log.e(TAG, "Restore failed: ${error.message}")
                onComplete(false)
            }
        })
    }

    internal fun updatePremiumStatus(customerInfo: CustomerInfo) {
        premiumRevision++
        val isPremium = customerInfo.entitlements[PREMIUM_ENTITLEMENT_KEY]?.isActive == true
        premiumRepository.setPremium(isPremium)
    }

    companion object {
        private const val TAG = "BillingRepository"
        internal const val PREMIUM_ENTITLEMENT_KEY = "premium"

        @Volatile
        private var instance: BillingRepository? = null

        fun getInstance(context: Context): BillingRepository =
            instance ?: synchronized(this) {
                instance ?: BillingRepository(context.applicationContext).also { instance = it }
            }
    }
}
