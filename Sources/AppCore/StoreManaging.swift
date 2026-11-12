import Foundation

/// One-time HK$8 non-consumable 「移除廣告」. Real StoreKit 2 code lives in the iOS target.
public enum StoreProduct: Sendable {
    /// Placeholder product id — replace in App Store Connect before release.
    public static let removeAdsProductID = "com.kenny.daidee.removeads"
    public static let removeAdsDisplayPrice = "HK$8"
    public static let removeAdsDisplayName = "移除廣告"
}

public enum StoreError: Error, Equatable, Sendable {
    case productNotFound
    case purchaseFailed
    case purchasePending
    case cancelled
}

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
