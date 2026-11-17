import Foundation
import StoreKit
import AppCore
import os

enum StoreLog {
    /// Console.app / `log stream --predicate 'category == "store"'` on a connected iPhone.
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kenny.daidee", category: "store")
}

/// StoreKit 2 implementation of the one-time 「移除廣告」 non-consumable
/// (`com.kenny.daidee.removeads`, HK$8 tier chosen in App Store Connect).
///
/// - Purchase and 「回復購買」 (`AppStore.sync`) from Settings.
/// - `Transaction.currentEntitlements` is checked at launch and `Transaction.updates` is
///   observed for the whole app lifetime (Ask to Buy, purchases on another device, refunds).
/// - The entitlement is also persisted in app-data.json (`AppData.adsRemoved`) by
///   `AppViewModel`, so ads stay hidden offline. A refund (revocation) brings ads back.
/// - Local testing: the Run scheme uses App/Store/Products.storekit.
@MainActor
final class StoreKitStoreManager: ObservableObject, StoreManaging {
    @Published private(set) var isPurchasing = false
    @Published private(set) var adsRemoved = false
    /// Localised App Store price (e.g. "HK$8.00"); `nil` until the product loads.
    @Published private(set) var displayPrice: String?

    /// Called with `true` when the entitlement is found / bought, `false` when it was revoked.
    var onEntitlementChange: ((Bool) -> Void)?

    private var updatesTask: Task<Void, Never>?
    private var product: Product?

    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForUpdates()
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.preloadProduct()
        }
    }

    /// Longest we keep the button busy waiting for the App Store. Covers typing an Apple ID
    /// password and Face ID; if StoreKit is still silent after this, the user gets an alert
    /// and the button back. A purchase that completes later still removes ads (see below).
    static let purchaseTimeout: Double = 120
    static let restoreTimeout: Double = 90

    func purchaseRemoveAds() async throws -> Bool {
        guard !isPurchasing else {
            StoreLog.logger.notice("purchase tapped while busy")
            throw StoreError.busy
        }
        isPurchasing = true
        defer { isPurchasing = false }
        StoreLog.logger.notice("purchase start")
        do {
            let product = try await StoreTimeout.run(seconds: 30) { [weak self] in
                try await self?.loadProduct()
            }
            guard let product else {
                StoreLog.logger.error("purchase: product not found")
                throw StoreError.productNotFound
            }
            StoreLog.logger.notice("purchase: product loaded, price \(product.displayPrice, privacy: .public)")
            // The purchase runs in its own task so a timeout only stops the wait: if the App
            // Store answers late, `completePurchase` still finishes the transaction and
            // removes ads.
            let ok = try await StoreTimeout.run(seconds: Self.purchaseTimeout) { [weak self] in
                let result = try await product.purchase()
                return try await self?.completePurchase(result) ?? false
            }
            StoreLog.logger.notice("purchase done: \(ok, privacy: .public)")
            return ok
        } catch {
            let storeError = Self.storeError(from: error)
            StoreLog.logger.error("purchase failed: \(String(describing: storeError), privacy: .public)")
            throw storeError
        }
    }

    private func completePurchase(_ result: Product.PurchaseResult) async throws -> Bool {
        switch result {
        case .success(let verification):
            let transaction = try Self.checked(verification)
            await transaction.finish()
            setEntitled(true)
            return true
        case .userCancelled:
            throw StoreError.cancelled
        case .pending:
            throw StoreError.purchasePending
        @unknown default:
            throw StoreError.purchaseFailed
        }
    }

    func restorePurchases() async throws -> Bool {
        guard !isPurchasing else { throw StoreError.busy }
        isPurchasing = true
        defer { isPurchasing = false }
        StoreLog.logger.notice("restore start")
        do {
            try await StoreTimeout.run(seconds: Self.restoreTimeout) {
                try await AppStore.sync()
            }
            await refreshEntitlements()
            let entitled = adsRemoved
            StoreLog.logger.notice("restore done: entitled \(entitled, privacy: .public)")
            return entitled
        } catch {
            let storeError = Self.storeError(from: error)
            StoreLog.logger.error("restore failed: \(String(describing: storeError), privacy: .public)")
            throw storeError
        }
    }

    /// Maps StoreKit errors to `StoreError`, keeping the underlying description.
    /// Cancelling the Apple ID sign-in or the purchase sheet becomes `.cancelled` (silent).
    nonisolated static func storeError(from error: Error) -> StoreError {
        if let storeError = error as? StoreError { return storeError }
        if let storeKitError = error as? StoreKitError {
            if case .userCancelled = storeKitError { return .cancelled }
            return .storeKit(StoreError.describe(storeKitError))
        }
        if let purchaseError = error as? Product.PurchaseError {
            return .storeKit(StoreError.describe(purchaseError))
        }
        return StoreError(error)
    }

    @discardableResult
    private func loadProduct() async throws -> Product? {
        if let product { return product }
        let loaded = try await Product.products(for: [StoreProduct.removeAdsProductID]).first
        product = loaded
        displayPrice = loaded?.displayPrice
        return loaded
    }

    private func preloadProduct() async {
        _ = try? await loadProduct()
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? Self.checked(result),
               transaction.productID == StoreProduct.removeAdsProductID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        // Absence is not treated as a revocation (could be offline / signed out); only an
        // explicit revoked transaction in `Transaction.updates` turns ads back on.
        if entitled { setEntitled(true) }
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? Self.checked(result) else { continue }
            if transaction.productID == StoreProduct.removeAdsProductID {
                setEntitled(transaction.revocationDate == nil)
            }
            await transaction.finish()
        }
    }

    private func setEntitled(_ entitled: Bool) {
        adsRemoved = entitled
        onEntitlementChange?(entitled)
    }

    private static func checked(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(_, let error):
            throw StoreError.unverified(StoreError.describe(error))
        case .verified(let transaction):
            return transaction
        }
    }
}

@MainActor
extension StoreManaging {
    /// App Store price when StoreKit has loaded it, else the HK$8 fallback label.
    var removeAdsPriceLabel: String {
        (self as? StoreKitStoreManager)?.displayPrice ?? StoreProduct.removeAdsDisplayPrice
    }
}
