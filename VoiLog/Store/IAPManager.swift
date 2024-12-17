import StoreKit
import RevenueCat
import os.log

protocol PurchaseManagerProtocol {
    func fetchProductNameAndPrice(productIdentifier: String) async throws -> (name: String, price: String)
    func startPurchase(productID: String) async throws
    func restorePurchases() async throws
    func startOneTimePurchase() async throws

}

class PurchaseManager: PurchaseManagerProtocol {
    private let logger = OSLog(subsystem: "com.entaku.VoiLog", category: "Purchase")


    static let shared = PurchaseManager()

    private init() {}

    enum PurchaseError: Error {
        case productNotFound
        case purchaseFailed
        case noEntitlements
    }

    func fetchProductNameAndPrice(productIdentifier: String) async throws -> (name: String, price: String) {
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current,
              let package = offering.package(identifier: productIdentifier) else {
            throw PurchaseError.productNotFound
        }

        return (name: package.storeProduct.localizedTitle,
                price: package.localizedPriceString)
    }

    func startPurchase(productID: String) async throws {
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current,
              let package = offering.availablePackages.first(where: { $0.identifier == "$rc_annual" }) else {
            throw PurchaseError.productNotFound
        }

        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)

            if customerInfo.entitlements["premium"]?.isActive == true {
                UserDefaultsManager.shared.hasPurchasedProduct = true
            } else {
                throw PurchaseError.purchaseFailed
            }
        } catch {
            throw PurchaseError.purchaseFailed
        }
    }

    func restorePurchases() async throws {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            if customerInfo.entitlements["premium"]?.isActive == true {
                UserDefaultsManager.shared.hasPurchasedProduct = true
            } else {
                throw PurchaseError.noEntitlements
            }
        } catch {
            throw error
        }
    }

    func startOneTimePurchase() async throws {
        let offerings = try await Purchases.shared.offerings()

        os_log("=== Purchase Flow Start ===", log: logger, type: .debug)
        os_log("Offerings: %{public}@", log: logger, type: .debug, offerings.all.keys.description)
        os_log("Current Offering ID: %{public}@", log: logger, type: .debug, offerings.current?.identifier ?? "nil")

        if let current = offerings.current {
            os_log("Packages in current offering:", log: logger, type: .debug)
            current.availablePackages.forEach { package in
                os_log("- ID: %{public}@", log: logger, type: .debug, package.identifier)
                os_log("  Product: %{public}@", log: logger, type: .debug, package.storeProduct.productIdentifier)
            }
        } else {
            os_log("No current offering available", log: logger, type: .debug)
        }

        guard let offering = offerings.current else {
            os_log("No current offering available", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        guard let package = offering.availablePackages.first(where: { $0.identifier == "developerSupport" }) else {
            os_log("Failed to get package", log: logger, type: .debug)
            os_log("Available packages: %{public}@", log: logger, type: .debug,
                  offering.availablePackages.map { $0.identifier }.description)
            throw PurchaseError.productNotFound
        }

        os_log("Found package: %{public}@", log: logger, type: .debug, package.identifier)
        os_log("Product ID: %{public}@", log: logger, type: .debug, package.storeProduct.productIdentifier)

        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            os_log("Purchase completed", log: logger, type: .debug)
            os_log("Premium status: %{public}@", log: logger, type: .debug,
                  String(customerInfo.entitlements["premium"]?.isActive ?? false))
        } catch {
            os_log("Purchase failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw PurchaseError.purchaseFailed
        }

        os_log("=== Purchase Flow End ===", log: logger, type: .debug)
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
