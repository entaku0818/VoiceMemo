import StoreKit
import RevenueCat
import os.log

protocol PurchaseManagerProtocol {
    func fetchProPlan() async throws -> (name: String, price: String)
    func purchasePro() async throws
    func restorePurchases() async throws
    func startOneTimePurchase() async throws
}

class PurchaseManager: PurchaseManagerProtocol {
    private let logger = OSLog(subsystem: "com.entaku.VoiLog", category: "Purchase")
    static let shared = PurchaseManager()

    private enum Package {
        static let pro = "$rc_monthly"
        static let developerSupport = "developerSupport"
    }

    private init() {}

    enum PurchaseError: Error {
        case productNotFound
        case purchaseFailed
        case noEntitlements
    }

    func fetchProPlan() async throws -> (name: String, price: String) {
        os_log("=== Fetch Pro Plan Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        os_log("Current Offering ID: %{public}@", log: logger, type: .debug, offerings.current?.identifier ?? "nil")

        if let current = offerings.current {
            os_log("Packages in offering:", log: logger, type: .debug)
            current.availablePackages.forEach { package in
                os_log("- ID: %{public}@, Product: %{public}@", log: logger, type: .debug,
                       package.identifier, package.storeProduct.productIdentifier)
            }
        }

        guard let offering = offerings.current,
              let package = offering.availablePackages.first(where: { $0.identifier == Package.pro }) else {
            os_log("Pro package not found", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        os_log("Found pro package: %{public}@", log: logger, type: .debug, package.identifier)
        os_log("=== Fetch Pro Plan End ===", log: logger, type: .debug)

        return (name: package.storeProduct.localizedTitle,
                price: package.localizedPriceString)
    }

    func purchasePro() async throws {
        os_log("=== Purchase Pro Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current,
              let package = offering.availablePackages.first(where: { $0.identifier == Package.pro }) else {
            os_log("Pro package not found", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        do {
            os_log("Starting pro purchase for package: %{public}@", log: logger, type: .debug, package.identifier)
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)

            if customerInfo.entitlements["premium"]?.isActive == true {
                await MainActor.run {
                    UserDefaultsManager.shared.hasPurchasedProduct = true
                }
                os_log("Pro purchase successful", log: logger, type: .debug)
            } else {
                os_log("Pro purchase failed: premium not active", log: logger, type: .error)
                throw PurchaseError.purchaseFailed
            }
        } catch {
            os_log("Pro purchase failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw PurchaseError.purchaseFailed
        }
        os_log("=== Purchase Pro End ===", log: logger, type: .debug)
    }

    func restorePurchases() async throws {
        os_log("=== Restore Purchases Start ===", log: logger, type: .debug)
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            if customerInfo.entitlements["premium"]?.isActive == true {
                UserDefaultsManager.shared.hasPurchasedProduct = true
                os_log("Restore successful", log: logger, type: .debug)
            } else {
                os_log("Restore failed: no entitlements found", log: logger, type: .error)
                throw PurchaseError.noEntitlements
            }
        } catch {
            os_log("Restore failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw error
        }
        os_log("=== Restore Purchases End ===", log: logger, type: .debug)
    }

    func startOneTimePurchase() async throws {
        os_log("=== One Time Purchase Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        os_log("Offerings: %{public}@", log: logger, type: .debug, offerings.all.keys.description)
        os_log("Current Offering ID: %{public}@", log: logger, type: .debug, offerings.current?.identifier ?? "nil")

        if let current = offerings.current {
            os_log("Packages in current offering:", log: logger, type: .debug)
            current.availablePackages.forEach { package in
                os_log("- ID: %{public}@", log: logger, type: .debug, package.identifier)
                os_log("  Product: %{public}@", log: logger, type: .debug, package.storeProduct.productIdentifier)
            }
        }

        guard let offering = offerings.current else {
            os_log("No current offering available", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        guard let package = offering.availablePackages.first(where: { $0.identifier == Package.developerSupport }) else {
            os_log("Failed to get one time package", log: logger, type: .debug)
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

            if customerInfo.entitlements["premium"]?.isActive == true {
                UserDefaultsManager.shared.hasSupportedDeveloper = true
            }
        } catch {
            os_log("Purchase failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw PurchaseError.purchaseFailed
        }

        os_log("=== One Time Purchase End ===", log: logger, type: .debug)
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
