import UIKit
import GoogleMobileAds
import AppCore

/// Production interstitials: Google's standard (skippable) `InterstitialAd`, never rewarded.
///
/// When to show one (before rounds 6 / 11 / 16…, on entering 完場, ≥ 3 min apart, never after
/// 移除廣告) is decided by `AppModel` / `AppViewModel`; this class only loads and presents.
/// Nothing loads until `AdsRuntime` has finished UMP consent + ATT.
@MainActor
final class AdMobAdManager: NSObject, AdManaging, FullScreenContentDelegate {
    var adsRemoved: Bool = false {
        didSet { if adsRemoved { interstitial = nil } }
    }

    private var interstitial: InterstitialAd?
    private var isLoading = false
    private var waitingForRuntime = false
    private var dismissal: CheckedContinuation<Void, Never>?

    var isInterstitialReady: Bool { !adsRemoved && interstitial != nil }

    func preloadInterstitial() {
        guard !adsRemoved, interstitial == nil, !isLoading else { return }
        guard AdsRuntime.shared.isReady else {
            if !waitingForRuntime {
                waitingForRuntime = true
                AdsRuntime.shared.whenReady { [weak self] in
                    self?.waitingForRuntime = false
                    self?.preloadInterstitial()
                }
            }
            return
        }
        isLoading = true
        let request = AdsRuntime.shared.makeRequest()
        Task { [weak self] in
            do {
                let ad = try await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: request)
                guard let self else { return }
                self.isLoading = false
                guard !self.adsRemoved else { return }
                ad.fullScreenContentDelegate = self
                self.interstitial = ad
            } catch {
                self?.isLoading = false
                NSLog("[Ads] Interstitial failed to load: \(error.localizedDescription)")
            }
        }
    }

    /// Presents a loaded interstitial and returns after the user closes it. Returns `false`
    /// straight away when nothing is loaded, so play never waits on an ad.
    func showInterstitialIfReady() async -> Bool {
        guard !adsRemoved, let ad = interstitial,
              let presenter = AdsRuntime.topViewController() else {
            preloadInterstitial()
            return false
        }
        interstitial = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissal = continuation
            ad.present(from: presenter)
        }
        preloadInterstitial()
        return true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NSLog("[Ads] Interstitial failed to present: \(error.localizedDescription)")
        finishPresentation()
    }

    private func finishPresentation() {
        dismissal?.resume()
        dismissal = nil
    }
}
