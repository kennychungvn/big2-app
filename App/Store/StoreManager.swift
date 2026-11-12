import Foundation
import StoreKit
import AppCore

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

    func purchaseRemoveAds() async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        guard let product = try await loadProduct() else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()
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
        try await AppStore.sync()
        await refreshEntitlements()
        return adsRemoved
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
        case .unverified:
            throw StoreError.purchaseFailed
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
