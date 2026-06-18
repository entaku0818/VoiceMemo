import XCTest
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
        XCTAssertEqual(result.price, "¥9800")
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
        UserDefaultsManager.shared.hasPurchasedProduct = false
        let sut = MockPurchaseManager.succeeding
        try await sut.purchasePro()
        XCTAssertTrue(UserDefaultsManager.shared.hasPurchasedProduct)
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
        UserDefaultsManager.shared.hasPurchasedProduct = false
        let sut = MockPurchaseManager.succeeding
        try await sut.purchaseAnnual()
        XCTAssertTrue(UserDefaultsManager.shared.hasPurchasedProduct)
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
        UserDefaultsManager.shared.hasPurchasedProduct = false
        let sut = MockPurchaseManager.succeeding
        try await sut.restorePurchases()
        XCTAssertTrue(UserDefaultsManager.shared.hasPurchasedProduct)
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
