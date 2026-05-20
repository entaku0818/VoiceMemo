package com.entaku.simpleRecord.store

import android.app.Activity
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.interfaces.PurchaseCallback
import com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback

interface PurchasesClient {
    fun getOfferings(callback: ReceiveOfferingsCallback)
    fun getCustomerInfo(callback: ReceiveCustomerInfoCallback)
    fun purchase(activity: Activity, pkg: Package, callback: PurchaseCallback)
    fun restorePurchases(callback: ReceiveCustomerInfoCallback)
}

object RealPurchasesClient : PurchasesClient {
    override fun getOfferings(callback: ReceiveOfferingsCallback) =
        Purchases.sharedInstance.getOfferings(callback)

    override fun getCustomerInfo(callback: ReceiveCustomerInfoCallback) =
        Purchases.sharedInstance.getCustomerInfo(callback)

    override fun purchase(activity: Activity, pkg: Package, callback: PurchaseCallback) =
        Purchases.sharedInstance.purchase(
            PurchaseParams.Builder(activity, pkg).build(),
            callback
        )

    override fun restorePurchases(callback: ReceiveCustomerInfoCallback) =
        Purchases.sharedInstance.restorePurchases(callback)
}
