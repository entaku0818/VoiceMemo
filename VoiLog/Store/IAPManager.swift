import StoreKit

class IAPManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    static let shared = IAPManager()

    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    // TODO: async/awaitにする
    func startPurchase(productID: String) {
        if SKPaymentQueue.canMakePayments() {
            let request = SKProductsRequest(productIdentifiers: Set([productID]))
            request.delegate = self
            request.start()
        } else {
            // ユーザーが購入を行えない場合の処理
        }
    }

    // TODO: async/awaitにする
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let product = response.products.first {
            buyProduct(product)
        } else {
            // 商品が見つからない場合の処理
        }
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
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}
