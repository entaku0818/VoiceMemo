package com.entaku.simpleRecord.store

import android.app.Activity
import android.content.Context
import android.util.Log
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.interfaces.PurchaseCallback
import com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback
import com.revenuecat.purchases.models.StoreTransaction
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class PremiumProduct(
    val productId: String,
    val title: String,
    val price: String,
    val rcPackage: Package
)

sealed class BillingState {
    object Loading : BillingState()
    data class Ready(val products: List<PremiumProduct>) : BillingState()
    data class Error(val message: String) : BillingState()
    object Purchasing : BillingState()
}

class BillingRepository private constructor(private val context: Context) {

    private val premiumRepository = PremiumRepository.getInstance(context)

    private val _billingState = MutableStateFlow<BillingState>(BillingState.Loading)
    val billingState: StateFlow<BillingState> = _billingState.asStateFlow()

    fun connect() {
        fetchOfferings()
        restoreCustomerInfo()
    }

    private fun fetchOfferings() {
        Purchases.sharedInstance.getOfferings(object : ReceiveOfferingsCallback {
            override fun onReceived(offerings: Offerings) {
                val packages = offerings.current?.availablePackages ?: emptyList()
                val products = packages.map { pkg ->
                    PremiumProduct(
                        productId = pkg.product.id,
                        title = pkg.product.title,
                        price = pkg.product.price.formatted,
                        rcPackage = pkg
                    )
                }
                _billingState.value = BillingState.Ready(products)
            }

            override fun onError(error: PurchasesError) {
                Log.e(TAG, "Failed to fetch offerings: ${error.message}")
                _billingState.value = BillingState.Error(error.message)
            }
        })
    }

    private fun restoreCustomerInfo() {
        Purchases.sharedInstance.getCustomerInfo(object : ReceiveCustomerInfoCallback {
            override fun onReceived(customerInfo: CustomerInfo) {
                val isPremium = customerInfo.entitlements["premium"]?.isActive == true
                premiumRepository.setPremium(isPremium)
            }

            override fun onError(error: PurchasesError) {
                Log.w(TAG, "Could not fetch customer info: ${error.message}")
            }
        })
    }

    fun launchPurchaseFlow(activity: Activity, product: PremiumProduct) {
        _billingState.value = BillingState.Purchasing
        Purchases.sharedInstance.purchase(
            purchaseParams = com.revenuecat.purchases.PurchaseParams.Builder(activity, product.rcPackage).build(),
            callback = object : PurchaseCallback {
                override fun onCompleted(storeTransaction: StoreTransaction, customerInfo: CustomerInfo) {
                    val isPremium = customerInfo.entitlements["premium"]?.isActive == true
                    premiumRepository.setPremium(isPremium)
                    fetchOfferings()
                }

                override fun onError(error: PurchasesError, userCancelled: Boolean) {
                    if (!userCancelled) {
                        Log.e(TAG, "Purchase failed: ${error.message}")
                        _billingState.value = BillingState.Error(error.message)
                    } else {
                        fetchOfferings()
                    }
                }
            }
        )
    }

    fun restorePurchases(onComplete: (Boolean) -> Unit) {
        Purchases.sharedInstance.restorePurchases(object : ReceiveCustomerInfoCallback {
            override fun onReceived(customerInfo: CustomerInfo) {
                val isPremium = customerInfo.entitlements["premium"]?.isActive == true
                premiumRepository.setPremium(isPremium)
                onComplete(isPremium)
            }

            override fun onError(error: PurchasesError) {
                Log.e(TAG, "Restore failed: ${error.message}")
                onComplete(false)
            }
        })
    }

    companion object {
        private const val TAG = "BillingRepository"

        @Volatile
        private var instance: BillingRepository? = null

        fun getInstance(context: Context): BillingRepository =
            instance ?: synchronized(this) {
                instance ?: BillingRepository(context.applicationContext).also { instance = it }
            }
    }
}
