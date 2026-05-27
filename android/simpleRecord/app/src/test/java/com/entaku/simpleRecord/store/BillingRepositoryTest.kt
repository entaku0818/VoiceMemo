package com.entaku.simpleRecord.store

import android.app.Activity
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.EntitlementInfo
import com.revenuecat.purchases.EntitlementInfos
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.interfaces.PurchaseCallback
import com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback
import com.revenuecat.purchases.models.StoreTransaction
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class BillingRepositoryTest {

    private lateinit var context: Context
    private lateinit var fakePurchasesClient: FakePurchasesClient
    private lateinit var repository: BillingRepository

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        fakePurchasesClient = FakePurchasesClient()
        repository = BillingRepository(context, fakePurchasesClient)
    }

    @Test
    fun `initial state is Loading`() = runTest {
        assertEquals(BillingState.Loading, repository.billingState.first())
    }

    @Test
    fun `disconnect resets state to Loading`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        repository.connect()
        assertEquals(BillingState.Ready(emptyList()), repository.billingState.value)

        repository.disconnect()

        assertEquals(BillingState.Loading, repository.billingState.value)
    }

    @Test
    fun `fetchOfferings success transitions to Ready state`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        repository.connect()
        assertEquals(BillingState.Ready(emptyList()), repository.billingState.value)
    }

    @Test
    fun `fetchOfferings failure transitions to Error state`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Failure("Network error")
        repository.connect()
        assertTrue(repository.billingState.value is BillingState.Error)
    }

    @Test
    fun `connect with premium entitlement sets isPremium true`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        fakePurchasesClient.customerInfoResult = CustomerInfoResult.Premium
        repository.connect()
        val premiumRepo = PremiumRepository.getInstance(context)
        assertTrue(premiumRepo.isPremium.value)
    }

    @Test
    fun `connect without premium entitlement keeps isPremium false`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        fakePurchasesClient.customerInfoResult = CustomerInfoResult.NotPremium
        repository.connect()
        val premiumRepo = PremiumRepository.getInstance(context)
        assertFalse(premiumRepo.isPremium.value)
    }

    @Test
    fun `restorePurchases success with premium calls onComplete with true`() = runTest {
        fakePurchasesClient.restoreResult = CustomerInfoResult.Premium
        var result: Boolean? = null
        repository.restorePurchases { result = it }
        assertTrue(result == true)
    }

    @Test
    fun `restorePurchases success without premium calls onComplete with false`() = runTest {
        fakePurchasesClient.restoreResult = CustomerInfoResult.NotPremium
        var result: Boolean? = null
        repository.restorePurchases { result = it }
        assertFalse(result == true)
    }

    @Test
    fun `restorePurchases failure calls onComplete with false`() = runTest {
        fakePurchasesClient.restoreResult = CustomerInfoResult.Failure("error")
        var result: Boolean? = null
        repository.restorePurchases { result = it }
        assertFalse(result == true)
    }

    @Test
    fun `PREMIUM_ENTITLEMENT_KEY constant equals premium`() {
        assertEquals("premium", BillingRepository.PREMIUM_ENTITLEMENT_KEY)
    }

    // --- launchPurchaseFlow tests (#143) ---

    @Test
    fun `launchPurchaseFlow sets state to Purchasing immediately`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        fakePurchasesClient.purchaseResult = PurchaseResult.Pending
        repository.connect()

        val activity = mockk<Activity>()
        val product = PremiumProduct("id", "title", "$9.99", mockk())
        repository.launchPurchaseFlow(activity, product)

        assertEquals(BillingState.Purchasing, repository.billingState.value)
    }

    @Test
    fun `launchPurchaseFlow success updates premium status and transitions to Ready`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        fakePurchasesClient.purchaseResult = PurchaseResult.Success
        repository.connect()

        val activity = mockk<Activity>()
        val product = PremiumProduct("id", "title", "$9.99", mockk())
        repository.launchPurchaseFlow(activity, product)

        val premiumRepo = PremiumRepository.getInstance(context)
        assertTrue(premiumRepo.isPremium.value)
        assertTrue(repository.billingState.value is BillingState.Ready)
    }

    @Test
    fun `launchPurchaseFlow error transitions to Error state`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        fakePurchasesClient.purchaseResult = PurchaseResult.Error("Payment declined", userCancelled = false)
        repository.connect()

        val activity = mockk<Activity>()
        val product = PremiumProduct("id", "title", "$9.99", mockk())
        repository.launchPurchaseFlow(activity, product)

        // PurchasesError.message は PurchasesErrorCode が返す固定メッセージになるため
        // メッセージ内容ではなく状態種別のみ検証する
        assertTrue(repository.billingState.value is BillingState.Error)
    }

    @Test
    fun `launchPurchaseFlow user cancellation reverts to Ready state`() = runTest {
        fakePurchasesClient.offeringsResult = OfferingsResult.Success(emptyList())
        fakePurchasesClient.purchaseResult = PurchaseResult.Error("Cancelled", userCancelled = true)
        repository.connect()

        val activity = mockk<Activity>()
        val product = PremiumProduct("id", "title", "$9.99", mockk())
        repository.launchPurchaseFlow(activity, product)

        assertTrue(repository.billingState.value is BillingState.Ready)
    }
}

// --- Sealed result types for fake ---

sealed class OfferingsResult {
    data class Success(val packages: List<Package>) : OfferingsResult()
    data class Failure(val message: String) : OfferingsResult()
}

sealed class CustomerInfoResult {
    object Premium : CustomerInfoResult()
    object NotPremium : CustomerInfoResult()
    data class Failure(val message: String) : CustomerInfoResult()
}

sealed class PurchaseResult {
    /** Purchase completes successfully with premium entitlement */
    object Success : PurchaseResult()
    /** Purchase callback not invoked yet (for testing Purchasing state) */
    object Pending : PurchaseResult()
    /** Purchase fails or user cancels */
    data class Error(val message: String, val userCancelled: Boolean = false) : PurchaseResult()
}

// --- Fake PurchasesClient ---

class FakePurchasesClient : PurchasesClient {
    var offeringsResult: OfferingsResult = OfferingsResult.Success(emptyList())
    var customerInfoResult: CustomerInfoResult = CustomerInfoResult.NotPremium
    var restoreResult: CustomerInfoResult = CustomerInfoResult.NotPremium
    var purchaseResult: PurchaseResult = PurchaseResult.Pending

    override fun getOfferings(callback: ReceiveOfferingsCallback) {
        when (val result = offeringsResult) {
            is OfferingsResult.Success -> {
                val offerings = mockk<Offerings>()
                every { offerings.current } returns null
                callback.onReceived(offerings)
            }
            is OfferingsResult.Failure ->
                callback.onError(PurchasesError(PurchasesErrorCode.UnknownError, result.message))
        }
    }

    override fun getCustomerInfo(callback: ReceiveCustomerInfoCallback) {
        when (val result = customerInfoResult) {
            is CustomerInfoResult.Premium -> callback.onReceived(fakePremiumCustomerInfo())
            is CustomerInfoResult.NotPremium -> callback.onReceived(fakeNonPremiumCustomerInfo())
            is CustomerInfoResult.Failure ->
                callback.onError(PurchasesError(PurchasesErrorCode.UnknownError, result.message))
        }
    }

    override fun purchase(activity: Activity, pkg: Package, callback: PurchaseCallback) {
        when (val result = purchaseResult) {
            is PurchaseResult.Success -> {
                val transaction = mockk<StoreTransaction>()
                callback.onCompleted(transaction, fakePremiumCustomerInfo())
            }
            is PurchaseResult.Pending -> {
                // Do not invoke callback — simulates in-flight purchase (Purchasing state)
            }
            is PurchaseResult.Error ->
                callback.onError(
                    PurchasesError(PurchasesErrorCode.UnknownError, result.message),
                    result.userCancelled
                )
        }
    }

    override fun restorePurchases(callback: ReceiveCustomerInfoCallback) {
        when (val result = restoreResult) {
            is CustomerInfoResult.Premium -> callback.onReceived(fakePremiumCustomerInfo())
            is CustomerInfoResult.NotPremium -> callback.onReceived(fakeNonPremiumCustomerInfo())
            is CustomerInfoResult.Failure ->
                callback.onError(PurchasesError(PurchasesErrorCode.UnknownError, result.message))
        }
    }

    private fun fakePremiumCustomerInfo(): CustomerInfo {
        val entitlement = mockk<EntitlementInfo>()
        every { entitlement.isActive } returns true
        val entitlements = mockk<EntitlementInfos>()
        every { entitlements[BillingRepository.PREMIUM_ENTITLEMENT_KEY] } returns entitlement
        val info = mockk<CustomerInfo>()
        every { info.entitlements } returns entitlements
        return info
    }

    private fun fakeNonPremiumCustomerInfo(): CustomerInfo {
        val entitlements = mockk<EntitlementInfos>()
        every { entitlements[BillingRepository.PREMIUM_ENTITLEMENT_KEY] } returns null
        val info = mockk<CustomerInfo>()
        every { info.entitlements } returns entitlements
        return info
    }
}
