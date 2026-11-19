import Foundation
import StoreKit
import AppCore
import os
import UIKit

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
    /// True while a StoreKit purchase call is running (even after the UI stopped waiting).
    private var purchaseInFlight = false

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
        // `purchaseInFlight` also covers a StoreKit purchase still running after the wait
        // timed out, so a second tap cannot start a second, competing purchase.
        guard !isPurchasing, !purchaseInFlight else {
            Self.record("purchase tapped while busy (ignored)")
            throw StoreError.busy
        }
        isPurchasing = true
        defer { isPurchasing = false }
        Self.record("purchase start (\(Self.environmentSummary))")
        do {
            let product = try await StoreTimeout.run(seconds: 30) { [weak self] in
                try await self?.loadProduct()
            }
            guard let product else {
                Self.record("purchase: product not found for \(StoreProduct.removeAdsProductID)")
                throw StoreError.productNotFound
            }
            // The purchase runs in its own task so a timeout only stops the wait: if the App
            // Store answers late, `runPurchase` still finishes the transaction and removes ads.
            // `runPurchase` is main-actor isolated, so the UI context is read on the main thread.
            let ok = try await StoreTimeout.run(seconds: Self.purchaseTimeout) { [weak self] in
                guard let self else { return false }
                return try await self.runPurchase(product)
            }
            Self.record("purchase done: \(ok ? "entitled" : "not entitled")")
            return ok
        } catch {
            let storeError = Self.storeError(from: error)
            Self.record("purchase failed: \(Self.logDescription(error, mapped: storeError))")
            throw storeError
        }
    }

    /// Starts the StoreKit purchase with an explicit UI context, on the main actor.
    ///
    /// Build 52 symptom: the Apple Account password prompt, then nothing, and StoreKit
    /// answered `.userCancelled`. Up to build 52 the app called `Product.purchase()` with no
    /// UI context (and, in build 52, from a detached timeout task off the main actor).
    /// Without a context StoreKit picks the foreground scene's key window root view controller
    /// to anchor the confirmation sheet; 移除廣告 sits in the 設定 sheet. When StoreKit cannot
    /// resolve a confirmation scene it ends the purchase as cancelled without any UI (known
    /// iOS 18.2+ behaviour, "Could not get confirmation scene ID"), so the next tap asks for
    /// the password again. Apple's documentation now says UIKit apps should call
    /// `purchase(confirmIn:)` (SwiftUI: `PurchaseAction`); `purchase(options:)` is for watchOS.
    /// iOS 18.2+: confirm in the top-most visible view controller (the 設定 sheet);
    /// iOS 17–18.1: the active window scene; iOS 16: the plain call (no other API exists).
    private func runPurchase(_ product: Product) async throws -> Bool {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        let context = PurchaseUIContext.current()
        let result: Product.PurchaseResult
        if #available(iOS 18.2, *), let viewController = context.viewController {
            Self.record("purchase: StoreKit purchase(confirmIn: view controller) \(context.summary)")
            result = try await product.purchase(confirmIn: viewController, options: [])
        } else if #available(iOS 17.0, *), let scene = context.scene {
            Self.record("purchase: StoreKit purchase(confirmIn: scene) \(context.summary)")
            result = try await product.purchase(confirmIn: scene, options: [])
        } else {
            Self.record("purchase: StoreKit purchase() \(context.summary)")
            result = try await product.purchase()
        }
        Self.record("purchase result: \(Self.describe(result))")
        return try await completePurchase(result)
    }

    private func completePurchase(_ result: Product.PurchaseResult) async throws -> Bool {
        switch result {
        case .success(let verification):
            let transaction = try Self.checked(verification)
            await transaction.finish()
            Self.record("purchase: transaction \(transaction.id) finished (\(Self.environmentName(of: transaction)))")
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
        guard !isPurchasing, !purchaseInFlight else {
            Self.record("restore tapped while busy (ignored)")
            throw StoreError.busy
        }
        isPurchasing = true
        defer { isPurchasing = false }
        Self.record("restore start: AppStore.sync (\(Self.environmentSummary))")
        do {
            try await StoreTimeout.run(seconds: Self.restoreTimeout) { [weak self] in
                try await self?.runSync()
            }
            await refreshEntitlements()
            let entitled = adsRemoved
            Self.record("restore done: entitled \(entitled)")
            return entitled
        } catch {
            let storeError = Self.storeError(from: error)
            Self.record("restore failed: \(Self.logDescription(error, mapped: storeError))")
            throw storeError
        }
    }

    /// Only ever called from the 回復購買 button (it can show the Apple Account sign-in).
    private func runSync() async throws {
        try await AppStore.sync()
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
        do {
            let loaded = try await Product.products(for: [StoreProduct.removeAdsProductID]).first
            product = loaded
            displayPrice = loaded?.displayPrice
            if let loaded {
                Self.record("product loaded: \(loaded.id) \(loaded.displayPrice) (\(loaded.priceFormatStyle.currencyCode))")
            } else {
                Self.record("product load: App Store returned no product for \(StoreProduct.removeAdsProductID)")
            }
            return loaded
        } catch {
            Self.record("product load failed: \(StoreError.describe(error))")
            throw error
        }
    }

    private func preloadProduct() async {
        _ = try? await loadProduct()
        let storefront = await Storefront.current
        Self.record("launch: storefront \(storefront?.countryCode ?? "nil"), canMakePayments \(AppStore.canMakePayments), \(Self.environmentSummary)")
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
        Self.record("entitlements: removeads \(entitled ? "owned" : "not owned")")
        if entitled { setEntitled(true) }
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? Self.checked(result) else {
                Self.record("Transaction.updates: unverified transaction ignored")
                continue
            }
            Self.record("Transaction.updates: \(transaction.productID) revoked=\(transaction.revocationDate != nil)")
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

    // MARK: - Diagnostics (購買紀錄 (debug))

    /// Adds a line to the on-device ring log and to os.Logger (category "store").
    nonisolated static func record(_ message: String) {
        StoreLog.logger.notice("\(message, privacy: .public)")
        StoreEventLog.shared.append(message)
    }

    /// Full error text for the log: the mapped case plus the raw StoreKit / NSError detail
    /// (domain, code, underlying error), which a user-facing alert does not show.
    nonisolated static func logDescription(_ error: Error, mapped: StoreError) -> String {
        let ns = error as NSError
        var text = "\(mapped) | raw: \(StoreError.describe(error)) | \(ns.domain) \(ns.code)"
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += " | underlying: \(underlying.domain) \(underlying.code) \(underlying.localizedDescription)"
        }
        return text
    }

    nonisolated static func describe(_ result: Product.PurchaseResult) -> String {
        switch result {
        case .success(.verified): return "success (verified)"
        case .success(.unverified(_, let error)): return "success (UNVERIFIED: \(StoreError.describe(error)))"
        case .userCancelled: return "userCancelled"
        case .pending: return "pending"
        @unknown default: return "unknown"
        }
    }

    nonisolated static func environmentName(of transaction: Transaction) -> String {
        transaction.environment.rawValue
    }

    /// App version / build, iOS version and whether this is a TestFlight (sandbox receipt) install.
    nonisolated static var environmentSummary: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent ?? "none"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "app \(version) (\(build)), iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion), receipt \(receipt)"
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
