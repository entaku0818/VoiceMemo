import XCTest
import Dependencies
@testable import VoiLog

final class PurchaseManagerTests: XCTestCase {
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
}
