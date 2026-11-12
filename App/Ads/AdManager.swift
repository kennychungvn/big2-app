import Foundation
import AppCore

/// Production `AdManaging` stand-in. Currently a no-op (never ready) so the
/// app never blocks on an ad. Swap the body of `preloadInterstitial` /
/// `showInterstitialIfReady` for the commented AdMob code in `AdMobStub.swift`
/// when the SDK and ad unit ids are ready.
@MainActor
final class NoOpAdManager: AdManaging {
    var adsRemoved: Bool = false
    var isInterstitialReady: Bool { false }

    func preloadInterstitial() {
        // Intentionally empty until AdMob is wired.
    }

    func showInterstitialIfReady() async -> Bool {
        if adsRemoved { return false }
        // If an interstitial were preloaded, present it here and return true
        // after it is dismissed. Never make the user wait when nothing is ready.
        return false
    }
}
