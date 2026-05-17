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
    val productDetails: ProductDetails,
    val offerToken: String? = null
)

sealed class BillingState {
    object Loading : BillingState()
    data class Ready(val products: List<PremiumProduct>) : BillingState()
    data class Error(val message: String) : BillingState()
    object Purchasing : BillingState()
}

class BillingRepository private constructor(private val context: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val premiumRepository = PremiumRepository.getInstance(context)

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
        val subsParams = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(BuildConfig.PREMIUM_PRODUCT_ID)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                )
            )
            .build()

        val subsResult = billingClient.queryProductDetails(subsParams)
        if (subsResult.billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
            _billingState.value = BillingState.Error(subsResult.billingResult.debugMessage)
            return
        }

        val products = subsResult.productDetailsList?.mapNotNull { details ->
            val offerDetails = details.subscriptionOfferDetails?.firstOrNull() ?: return@mapNotNull null
            val price = offerDetails.pricingPhases.pricingPhaseList.lastOrNull()?.formattedPrice ?: ""
            PremiumProduct(
                productId = details.productId,
                title = details.title,
                price = price,
                productDetails = details,
                offerToken = offerDetails.offerToken
            )
        } ?: emptyList()
        _billingState.value = BillingState.Ready(products)
    }

    private suspend fun restorePurchases() {
        var hasPremium = false

        // Check active subscriptions
        val subsResult = billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        )
        hasPremium = hasPremium || subsResult.purchasesList.any { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
                purchase.products.contains(BuildConfig.PREMIUM_PRODUCT_ID)
        }

        // Check lifetime purchases
        val inappResult = billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        )
        hasPremium = hasPremium || inappResult.purchasesList.any { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
                purchase.products.contains(BuildConfig.PREMIUM_LIFETIME_PRODUCT_ID)
        }

        premiumRepository.setPremium(hasPremium)
    }

    fun launchPurchaseFlow(activity: Activity, product: PremiumProduct) {
        _billingState.value = BillingState.Purchasing
        val productDetailsParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(product.productDetails)
            .apply { product.offerToken?.let { setOfferToken(it) } }
            .build()
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParams))
            .build()
        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            _billingState.value = BillingState.Error(result.debugMessage)
        }
    }

    fun restorePurchases(onComplete: (Boolean) -> Unit) {
        scope.launch {
            restorePurchases()
            onComplete(premiumRepository.isPremium.value)
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        val isPremium = purchase.products.contains(BuildConfig.PREMIUM_PRODUCT_ID) ||
            purchase.products.contains(BuildConfig.PREMIUM_LIFETIME_PRODUCT_ID)
        if (isPremium) {
            premiumRepository.setPremium(true)
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
        private const val TAG = "BillingRepository"

        @Volatile
        private var instance: BillingRepository? = null

        fun getInstance(context: Context): BillingRepository =
            instance ?: synchronized(this) {
                instance ?: BillingRepository(context.applicationContext).also { instance = it }
            }
    }
}
