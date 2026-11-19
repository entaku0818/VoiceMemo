import XCTest
import Dependencies
import ComposableArchitecture
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

    // MARK: - refreshPremiumStatus

    func testRefreshPremiumStatusPersistsActiveEntitlement() async {
        var persisted = false
        let result = await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { persisted = $0 }
        } operation: {
            await PurchaseManager(fetchPremiumStatus: { true }).refreshPremiumStatus()
        }

        XCTAssertEqual(result, true)
        XCTAssertTrue(persisted)
    }

    func testRefreshPremiumStatusClearsExpiredEntitlement() async {
        var persisted = true
        let result = await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { persisted = $0 }
        } operation: {
            await PurchaseManager(fetchPremiumStatus: { false }).refreshPremiumStatus()
        }

        XCTAssertEqual(result, false)
        XCTAssertFalse(persisted)
    }

    func testRefreshPremiumStatusKeepsSavedEntitlementOnNetworkFailure() async {
        var persisted = true
        let result = await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { persisted = $0 }
        } operation: {
            await PurchaseManager(fetchPremiumStatus: {
                throw URLError(.notConnectedToInternet)
            }).refreshPremiumStatus()
        }

        XCTAssertNil(result)
        XCTAssertTrue(persisted)
    }

    @MainActor
    func testOlderRefreshCannotOverwriteNewerEntitlementResponse() async {
        let firstStarted = expectation(description: "First refresh starts")
        let secondStarted = expectation(description: "Second refresh starts")
        let responses = LockIsolated<[CheckedContinuation<Bool, Never>]>([])
        let persisted = LockIsolated<[Bool]>([])

        await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { value in persisted.withValue { $0.append(value) } }
        } operation: {
            let manager = PurchaseManager(fetchPremiumStatus: {
                await withCheckedContinuation { continuation in
                    let count = responses.withValue {
                        $0.append(continuation)
                        return $0.count
                    }
                    if count == 1 { firstStarted.fulfill() } else { secondStarted.fulfill() }
                }
            })
            let firstRefresh = Task { await manager.refreshPremiumStatus() }
            await fulfillment(of: [firstStarted], timeout: 1)
            let secondRefresh = Task { await manager.refreshPremiumStatus() }
            await fulfillment(of: [secondStarted], timeout: 1)

            responses.value[1].resume(returning: true)
            let secondResult = await secondRefresh.value
            responses.value[0].resume(returning: false)
            let firstResult = await firstRefresh.value

            XCTAssertEqual(secondResult, true)
            XCTAssertNil(firstResult, "An outdated response must not be sent to the UI")
            XCTAssertEqual(persisted.value, [true])
        }
    }

    @MainActor
    func testPurchaseOrRestoreInvalidatesEarlierFalseRefreshResponse() async {
        let refreshStarted = expectation(description: "Refresh starts before purchase succeeds")
        let response = LockIsolated<CheckedContinuation<Bool, Never>?>(nil)
        let persisted = LockIsolated<[Bool]>([])

        await withDependencies {
            $0.userDefaults.setHasPurchasedProduct = { value in persisted.withValue { $0.append(value) } }
        } operation: {
            let manager = PurchaseManager(fetchPremiumStatus: {
                await withCheckedContinuation { continuation in
                    response.setValue(continuation)
                    refreshStarted.fulfill()
                }
            })
            let refresh = Task { await manager.refreshPremiumStatus() }
            await fulfillment(of: [refreshStarted], timeout: 1)

            // This is the shared success path used by monthly/annual purchases and restore.
            await manager.recordActivePremiumEntitlement()
            response.value?.resume(returning: false)
            let result = await refresh.value

            XCTAssertNil(result, "A pre-purchase response must not revoke the new entitlement")
            XCTAssertEqual(persisted.value, [true])
        }
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
