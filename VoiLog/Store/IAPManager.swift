import StoreKit


protocol IAPManagerProtocol {
    func fetchProductNameAndPrice(productIdentifier: String) async throws -> (name: String, price: String)
    func startPurchase(productID: String) async throws
    func restorePurchases() async throws
}


class IAPManager: NSObject, IAPManagerProtocol, SKProductsRequestDelegate, SKPaymentTransactionObserver {

    
    static let shared = IAPManager()

    private var currentContinuation: CheckedContinuation<SKProduct, Error>?

    private var restoreContinuation: CheckedContinuation<Void, Error>?


    enum IAPError: Error {
        case cannotMakePayments
        case productNotFound
        case canceled
        case noRestorablePurchases
    }

    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    func restorePurchases() async throws {
        guard restoreContinuation == nil else {
            return
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.restoreContinuation = continuation
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }



    private func fetchProduct(productIdentifier: String) async throws -> SKProduct {
        return try await withCheckedThrowingContinuation { continuation in
            let request = SKProductsRequest(productIdentifiers: Set([productIdentifier]))
            request.delegate = self
            self.currentContinuation = continuation
            request.start()
        }
    }

    // SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let product = response.products.first {
            currentContinuation?.resume(returning: product)
        } else {
            currentContinuation?.resume(throwing: IAPError.productNotFound)
        }
        currentContinuation = nil
    }

    private var purchaseContinuation: CheckedContinuation<Void, Error>?


     private func buyProduct(_ product: SKProduct) {
         let payment = SKPayment(product: product)
         SKPaymentQueue.default().add(payment)
     }


    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                completeTransaction(transaction)
            case .restored:
                completeTransaction(transaction)
            case .failed:
                failTransaction(transaction)
            default:
                break
            }
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if queue.transactions.isEmpty {
            restoreContinuation?.resume(throwing: IAPError.noRestorablePurchases)
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
         restoreContinuation?.resume(throwing: error)
     }

    private func completeTransaction(_ transaction: SKPaymentTransaction) {
        // Transaction completion process for both purchase and restore
        SKPaymentQueue.default().finishTransaction(transaction)
        UserDefaultsManager.shared.hasPurchasedProduct = true
        switch transaction.transactionState {
        case .purchased:
            purchaseContinuation?.resume(returning: ())
            purchaseContinuation = nil
        case .restored:
            restoreContinuation?.resume(returning: ())
            restoreContinuation = nil
        default:
            break
        }
    }

     private func failTransaction(_ transaction: SKPaymentTransaction) {
         // トランザクションが失敗したときの処理
         if let error = transaction.error {
             purchaseContinuation?.resume(throwing: error) // Resume the continuation with error
         }
         SKPaymentQueue.default().finishTransaction(transaction)
     }

     func startPurchase(productID: String) async throws {
         guard SKPaymentQueue.canMakePayments() else {
             throw IAPError.cannotMakePayments
         }

         let product = try await fetchProduct(productIdentifier: productID)

         return try await withCheckedThrowingContinuation { continuation in
             self.purchaseContinuation = continuation
             buyProduct(product)
         }
     }


    func fetchProductNameAndPrice(productIdentifier: String) async throws -> (name: String, price: String) {
        let product = try await fetchProduct(productIdentifier: productIdentifier)
        guard let localizedPrice = product.localizedPrice else {
            throw IAPError.productNotFound
        }
        return (name: product.localizedTitle, price: localizedPrice)
    }

}


extension SKProduct {
    var localizedPrice: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        return numberFormatter.string(from: price)
    }
}
