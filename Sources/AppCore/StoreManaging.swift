import Foundation

/// One-time HK$8 non-consumable 「移除廣告」. Real StoreKit 2 code lives in the iOS target.
public enum StoreProduct: Sendable {
    /// Non-consumable in App Store Connect (HK$8 tier set there). Local testing: App/Store/Products.storekit.
    /// Resolved from the target's Info.plist (`RemoveAdsProductID`). Falls back to the
    /// Hong Kong product when the key is missing so the 鋤大D app is unchanged.
    public static var removeAdsProductID: String { AppFlavor.removeAdsProductID }
    public static let removeAdsDisplayPrice = "HK$8"
    public static let removeAdsDisplayName = "移除廣告"
}

public enum StoreError: Error, Equatable, Sendable {
    /// StoreKit returned no product for `StoreProduct.removeAdsProductID`.
    case productNotFound
    /// Generic failure with no more detail (e.g. an unknown `Product.PurchaseResult`).
    case purchaseFailed
    /// Ask to Buy / SCA: the purchase finishes later via `Transaction.updates`.
    case purchasePending
    /// The user dismissed the sign-in or purchase sheet. Never shown as an error.
    case cancelled
    /// The transaction failed App Store signature verification. Carries the reason.
    case unverified(String)
    /// A StoreKit / App Store error. Carries a readable description of the underlying error
    /// (e.g. "StoreKitError.networkError: …") so it can be shown to the user and logged.
    case storeKit(String)
    /// The App Store did not answer within the timeout. The request may still finish later.
    case timedOut
    /// Another purchase or restore is already running.
    case busy

    /// Underlying error text to show under the Cantonese message, if any.
    public var detail: String? {
        switch self {
        case .unverified(let reason): return reason
        case .storeKit(let description): return description
        default: return nil
        }
    }
}

/// Main-actor isolated: purchase state is shown in Settings and owned by the view model.
@MainActor
public protocol StoreManaging: AnyObject {
    var isPurchasing: Bool { get }
    var adsRemoved: Bool { get }
    func purchaseRemoveAds() async throws -> Bool
    func restorePurchases() async throws -> Bool
}

/// Test / development stub. A successful purchase just flips `adsRemoved`.
public final class StubStoreManager: StoreManaging {
    public var isPurchasing: Bool = false
    public var adsRemoved: Bool
    public var purchaseResult: Result<Bool, StoreError>
    public var restoreResult: Result<Bool, StoreError>
    public var purchaseCount = 0
    public var restoreCount = 0

    public init(
        adsRemoved: Bool = false,
        purchaseResult: Result<Bool, StoreError> = .success(true),
        restoreResult: Result<Bool, StoreError> = .success(false)
    ) {
        self.adsRemoved = adsRemoved
        self.purchaseResult = purchaseResult
        self.restoreResult = restoreResult
    }

    public func purchaseRemoveAds() async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseCount += 1
        switch purchaseResult {
        case .success(let ok):
            if ok { adsRemoved = true }
            return ok
        case .failure(let error):
            throw error
        }
    }

    public func restorePurchases() async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        restoreCount += 1
        switch restoreResult {
        case .success(let ok):
            if ok { adsRemoved = true }
            return ok
        case .failure(let error):
            throw error
        }
    }
}
