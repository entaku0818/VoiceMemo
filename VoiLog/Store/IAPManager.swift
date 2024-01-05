import StoreKit

class IAPManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    static let shared = IAPManager()

    private var currentContinuation: CheckedContinuation<SKProduct, Error>?

    enum IAPError: Error {
        case cannotMakePayments
        case productNotFound
        case canceled
    }
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    func startPurchase(productID: String) async throws {
        guard SKPaymentQueue.canMakePayments() else {
            // ユーザーが購入を行えない場合の処理
            throw IAPError.cannotMakePayments
        }

        let product = try await fetchProduct(productIdentifier: productID)
        buyProduct(product)
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

    private func buyProduct(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

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
    }

    private func failTransaction(_ transaction: SKPaymentTransaction) {
        // トランザクションが失敗したときの処理
        if let error = transaction.error as? SKError {
            currentContinuation?.resume(throwing: error)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }


}
