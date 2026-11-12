import Foundation

/// Abstraction over banner + interstitial ads. The iOS app supplies a real or mock implementation.
/// Main-actor isolated: implementations present UI (interstitials) and are driven by the view model.
@MainActor
public protocol AdManaging: AnyObject {
    var adsRemoved: Bool { get set }
    /// `true` when a skippable interstitial is already loaded and can be shown without waiting.
    var isInterstitialReady: Bool { get }
    func preloadInterstitial()
    /// Shows a ready interstitial. Returns `false` if nothing was shown (not loaded, or ads removed)
    /// so the caller can continue into 入剩牌 immediately.
    func showInterstitialIfReady() async -> Bool
}

/// No-op implementation used in tests and as the shipping stand-in until AdMob is wired up.
public final class MockAdManager: AdManaging {
    public var adsRemoved: Bool
    public var isInterstitialReady: Bool
    public var preloadCount = 0
    public var showCount = 0
    /// When `true`, `showInterstitialIfReady` reports a successful show if `isInterstitialReady`.
    public var shouldPresentWhenReady: Bool

    public init(
        adsRemoved: Bool = false,
        isInterstitialReady: Bool = false,
        shouldPresentWhenReady: Bool = true
    ) {
        self.adsRemoved = adsRemoved
        self.isInterstitialReady = isInterstitialReady
        self.shouldPresentWhenReady = shouldPresentWhenReady
    }

    public func preloadInterstitial() {
        preloadCount += 1
    }

    public func showInterstitialIfReady() async -> Bool {
        if adsRemoved { return false }
        guard isInterstitialReady, shouldPresentWhenReady else { return false }
        showCount += 1
        isInterstitialReady = false
        return true
    }
}
