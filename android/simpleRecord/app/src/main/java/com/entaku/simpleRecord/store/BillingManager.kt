package com.entaku.simpleRecord.store

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.entaku.simpleRecord.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class PremiumProduct(
    val productId: String,
    val title: String,
    val price: String,
    val productDetails: ProductDetails
)

sealed class BillingState {
    object Loading : BillingState()
    data class Ready(val products: List<PremiumProduct>) : BillingState()
    data class Error(val message: String) : BillingState()
    object Purchasing : BillingState()
}

class BillingManager private constructor(private val context: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val premiumManager = PremiumManager.getInstance(context)

    private val _billingState = MutableStateFlow<BillingState>(BillingState.Loading)
    val billingState: StateFlow<BillingState> = _billingState.asStateFlow()

    private val purchasesUpdatedListener = PurchasesUpdatedListener { result, purchases ->
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            purchases.forEach { handlePurchase(it) }
        } else if (result.responseCode != BillingClient.BillingResponseCode.USER_CANCELED) {
            Log.e(TAG, "Purchase failed: ${result.debugMessage}")
            _billingState.value = BillingState.Error(result.debugMessage)
        }
    }

    private val billingClient = BillingClient.newBuilder(context)
        .setListener(purchasesUpdatedListener)
        .enablePendingPurchases()
        .build()

    fun connect() {
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    scope.launch { queryProducts() }
                    scope.launch { restorePurchases() }
                } else {
                    _billingState.value = BillingState.Error(result.debugMessage)
                }
            }

            override fun onBillingServiceDisconnected() {
                Log.w(TAG, "Billing service disconnected")
            }
        })
    }

    private suspend fun queryProducts() {
        val productIds = listOf(
            BuildConfig.PREMIUM_PRODUCT_ID,
            BuildConfig.PREMIUM_LIFETIME_PRODUCT_ID
        )
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                productIds.map { id ->
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(id)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                }
            )
            .build()

        val result = billingClient.queryProductDetails(params)
        if (result.billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            val products = result.productDetailsList?.map { details ->
                PremiumProduct(
                    productId = details.productId,
                    title = details.title,
                    price = details.oneTimePurchaseOfferDetails?.formattedPrice ?: "",
                    productDetails = details
                )
            } ?: emptyList()
            _billingState.value = BillingState.Ready(products)
        } else {
            _billingState.value = BillingState.Error(result.billingResult.debugMessage)
        }
    }

    private suspend fun restorePurchases() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        val result = billingClient.queryPurchasesAsync(params)
        val hasPremium = result.purchasesList.any { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
                (purchase.products.contains(BuildConfig.PREMIUM_PRODUCT_ID) ||
                    purchase.products.contains(BuildConfig.PREMIUM_LIFETIME_PRODUCT_ID))
        }
        premiumManager.setPremium(hasPremium)
    }

    fun launchPurchaseFlow(activity: Activity, product: PremiumProduct) {
        _billingState.value = BillingState.Purchasing
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(product.productDetails)
                        .build()
                )
            )
            .build()
        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            _billingState.value = BillingState.Error(result.debugMessage)
        }
    }

    fun restorePurchases(onComplete: (Boolean) -> Unit) {
        scope.launch {
            restorePurchases()
            onComplete(premiumManager.isPremium.value)
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        val isPremium = purchase.products.any { id ->
            id == BuildConfig.PREMIUM_PRODUCT_ID || id == BuildConfig.PREMIUM_LIFETIME_PRODUCT_ID
        }
        if (isPremium) {
            premiumManager.setPremium(true)
            if (!purchase.isAcknowledged) {
                val params = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                billingClient.acknowledgePurchase(params) { result ->
                    Log.d(TAG, "Acknowledge result: ${result.responseCode}")
                }
            }
        }
    }

    companion object {
        private const val TAG = "BillingManager"

        @Volatile
        private var instance: BillingManager? = null

        fun getInstance(context: Context): BillingManager =
            instance ?: synchronized(this) {
                instance ?: BillingManager(context.applicationContext).also { instance = it }
            }
    }
}
