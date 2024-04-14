import StoreKit


protocol IAPManagerProtocol {
    func fetchProductNameAndPrice(productIdentifier: String) async throws -> (name: String, price: String)
    func startPurchase(productID: String) async throws
}


class IAPManager: NSObject, IAPManagerProtocol, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    static let shared = IAPManager()

    private var currentContinuation: CheckedContinuation<SKProduct, Error>?

    enum IAPError: Error {
        case cannotMakePayments
        case productNotFound
        case canceled
    }
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
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

     // ... existing methods ...

     private func buyProduct(_ product: SKProduct) {
         let payment = SKPayment(product: product)
         SKPaymentQueue.default().add(payment)
     }

     // ... SKProductsRequestDelegate methods ...

     func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
         for transaction in transactions {
             switch transaction.transactionState {
             case .purchased:
                 completeTransaction(transaction)
             case .failed:
                 failTransaction(transaction)
             default:
                 break
             }
         }
     }

     private func completeTransaction(_ transaction: SKPaymentTransaction) {
         // トランザクションが成功したときの処理
         SKPaymentQueue.default().finishTransaction(transaction)
         purchaseContinuation?.resume(returning: ()) // Resume the continuation
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
