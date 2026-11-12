import Foundation
import StoreKit
import AppCore

/// StoreKit 2 implementation of the one-time HK$8 「移除廣告」 non-consumable.
/// The product id is a placeholder until it is created in App Store Connect.
@MainActor
final class StoreKitStoreManager: ObservableObject, StoreManaging {
    @Published private(set) var isPurchasing = false
    @Published private(set) var adsRemoved = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForUpdates()
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
        }
    }

    func purchaseRemoveAds() async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        let products = try await Product.products(for: [StoreProduct.removeAdsProductID])
        guard let product = products.first else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checked(verification)
            await transaction.finish()
            adsRemoved = true
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

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? Self.checked(result),
               transaction.productID == StoreProduct.removeAdsProductID,
               transaction.revocationDate == nil {
                entitled = true
                await transaction.finish()
            }
        }
        adsRemoved = entitled
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            if let transaction = try? Self.checked(result) {
                if transaction.productID == StoreProduct.removeAdsProductID,
                   transaction.revocationDate == nil {
                    adsRemoved = true
                }
                if transaction.revocationDate != nil {
                    adsRemoved = false
                }
                await transaction.finish()
            }
        }
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
