import XCTest
import Dependencies
import RevenueCat
@testable import VoiLog

final class PurchaseManagerTests: XCTestCase {
    @MainActor
    func testPurchasesConfigurationCompletesSynchronously() {
        var configuredKeys: [String] = []

        VoiceMemoApp.configurePurchasesBeforeUI(apiKey: "test_api_key") { configuredKeys.append($0) }

        // No sleep or queue draining: the SDK must be ready before UI tasks can run.
        XCTAssertEqual(configuredKeys, ["test_api_key"])
    }

    // MARK: - fetchProPlan

    func testFetchProPlanReturnsProductInfo() async throws {
        let sut = MockPurchaseManager(productName: "月額プレミアム", productPrice: "¥1200")
        let result = try await sut.fetchProPlan()
        XCTAssertEqual(result.name, "月額プレミアム")
        XCTAssertEqual(result.price, "¥1200")
    }

    func testFetchProPlanThrowsWhenShouldThrowError() async {
        let sut = MockPurchaseManager.failing
        do {
            _ = try await sut.fetchProPlan()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - fetchAnnualPlan

    func testFetchAnnualPlanReturnsPrice() async throws {
        let sut = MockPurchaseManager.succeeding
        let result = try await sut.fetchAnnualPlan()
        XCTAssertFalse(result.price.isEmpty)
        XCTAssertEqual(result.price, "¥9,000")
    }

    func testFetchAnnualPlanThrowsWhenShouldThrowError() async {
        let sut = MockPurchaseManager.failing
        do {
            _ = try await sut.fetchAnnualPlan()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - purchasePro

    func testPurchaseProSetsHasPurchasedProduct() async throws {
        var persisted: Bool?
        try await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { persisted = $0 }
        } operation: {
            let sut = MockPurchaseManager.succeeding
            try await sut.purchasePro()
        }
        XCTAssertEqual(persisted, true)
    }

    func testPurchaseProThrowsWhenShouldThrowError() async {
        let sut = MockPurchaseManager.failing
        do {
            try await sut.purchasePro()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - purchaseAnnual

    func testPurchaseAnnualSetsHasPurchasedProduct() async throws {
        var persisted: Bool?
        try await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { persisted = $0 }
        } operation: {
            let sut = MockPurchaseManager.succeeding
            try await sut.purchaseAnnual()
        }
        XCTAssertEqual(persisted, true)
    }

    func testPurchaseAnnualThrowsWhenShouldThrowError() async {
        let sut = MockPurchaseManager.failing
        do {
            try await sut.purchaseAnnual()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - restorePurchases

    func testRestorePurchasesSetsHasPurchasedProduct() async throws {
        var persisted: Bool?
        try await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { persisted = $0 }
        } operation: {
            let sut = MockPurchaseManager.succeeding
            try await sut.restorePurchases()
        }
        XCTAssertEqual(persisted, true)
    }

    func testRestorePurchasesThrowsWhenShouldThrowError() async {
        let sut = MockPurchaseManager.failing
        do {
            try await sut.restorePurchases()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - isCancellation（issue #230: キャンセルを「購入失敗」と表示していた）

    func testIsCancellation_trueForRevenueCatCancelledError() {
        XCTAssertTrue(PurchaseManager.isCancellation(ErrorCode.purchaseCancelledError))
    }

    func testIsCancellation_trueForBridgedNSError() {
        // SDK は ErrorCode.errorDomain の NSError として投げてくる
        let error = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.purchaseCancelledError.rawValue)
        XCTAssertTrue(PurchaseManager.isCancellation(error))
    }

    func testIsCancellation_trueForOwnCancelledError() {
        XCTAssertTrue(PurchaseManager.isCancellation(PurchaseManager.PurchaseError.cancelled))
    }

    func testIsCancellation_falseForOtherErrors() {
        XCTAssertFalse(PurchaseManager.isCancellation(ErrorCode.networkError))
        XCTAssertFalse(PurchaseManager.isCancellation(PurchaseManager.PurchaseError.purchaseFailed))
        XCTAssertFalse(PurchaseManager.isCancellation(
            NSError(domain: "OtherDomain", code: ErrorCode.purchaseCancelledError.rawValue)
        ))
    }
    func testAnalyticsErrorCodeSeparatesNoEntitlementsAndFailures() {
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(PurchaseManager.PurchaseError.noEntitlements), "no_entitlements")
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(PurchaseManager.PurchaseError.productNotFound), "product_not_found")
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(PurchaseManager.PurchaseError.purchaseFailed), "purchase_failed")
    }

    func testAnalyticsErrorCodeRecognizesSDKAndURLNetworkErrors() {
        let sdkError = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.networkError.rawValue)
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(sdkError), "network_error")
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(URLError(.notConnectedToInternet)), "network_error")
    }

    func testAnalyticsErrorCodeDoesNotLeakDescriptionsOrConfuseDomains() {
        let error = NSError(domain: "OtherDomain", code: ErrorCode.networkError.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: "sensitive details"])
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(error), "unknown")
        let sdkError = NSError(domain: ErrorCode.errorDomain, code: 999)
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(sdkError), "revenuecat_999")
    }

    func testAnalyticsErrorCodeRecognizesCancellation() {
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(PurchaseManager.PurchaseError.cancelled), "cancelled")
        let error = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.purchaseCancelledError.rawValue)
        XCTAssertEqual(PurchaseManager.analyticsErrorCode(error), "cancelled")
    }

}
