//
//  MockIAPManager.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/04/14.
//

import Foundation
import Dependencies
class MockPurchaseManager: PurchaseManagerProtocol {
    @Dependency(\.userDefaults) var userDefaults
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

    func fetchProPlan() async throws -> (name: String, price: String) {
        if shouldThrowError {
            throw PurchaseError.productNotFound
        }
        return (name: productName, price: productPrice)
    }

    func fetchAnnualPlan() async throws -> (name: String, price: String) {
        if shouldThrowError {
            throw PurchaseError.productNotFound
        }
        return (name: productName, price: "¥9,000")
    }

    func purchasePro() async throws {
        if shouldThrowError {
            throw PurchaseError.purchaseFailed
        }
        userDefaults.setHasPurchasedProduct(true)
    }

    func purchaseAnnual() async throws {
        if shouldThrowError {
            throw PurchaseError.purchaseFailed
        }
        userDefaults.setHasPurchasedProduct(true)
    }

    func startOneTimePurchase() async throws {
        if shouldThrowError {
            throw PurchaseError.purchaseFailed
        }
        userDefaults.setHasSupportedDeveloper(true)
    }

    func restorePurchases() async throws {
        if shouldThrowError {
            throw PurchaseError.noEntitlements
        }
        userDefaults.setHasPurchasedProduct(true)
    }
}

// テスト用の便利なファクトリメソッド
extension MockPurchaseManager {
    static var succeeding: MockPurchaseManager {
        MockPurchaseManager(shouldThrowError: false)
    }

    static var failing: MockPurchaseManager {
        MockPurchaseManager(shouldThrowError: true)
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
