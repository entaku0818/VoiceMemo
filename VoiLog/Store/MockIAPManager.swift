//
//  MockIAPManager.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/04/14.
//

import Foundation
class MockPurchaseManager: PurchaseManagerProtocol {

    var productName: String
    var productPrice: String
    var shouldThrowError: Bool

    init(productName: String = "Premium Plan",
         productPrice: String = "¥1200",
         shouldThrowError: Bool = false) {
        self.productName = productName
        self.productPrice = productPrice
        self.shouldThrowError = shouldThrowError
    }

    func fetchProductNameAndPrice(productIdentifier: String) async throws -> (name: String, price: String) {
        if shouldThrowError {
            throw PurchaseError.productNotFound
        }
        return (name: productName, price: productPrice)
    }

    func startPurchase(productID: String) async throws {
        if shouldThrowError {
            throw PurchaseError.purchaseFailed
        }
    }

    func restorePurchases() async throws {
        if shouldThrowError {
            throw PurchaseError.noEntitlements
        }
    }
    func startOneTimePurchase() async throws {
        
    }

}

// カスタムエラーの定義を追加
extension MockPurchaseManager {
    enum PurchaseError: Error {
        case productNotFound
        case purchaseFailed
        case noEntitlements
    }
}
