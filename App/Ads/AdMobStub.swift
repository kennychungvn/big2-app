import SwiftUI
import AppCore

// MARK: - AdMob wiring (commented until the SDK is added)
//
// 1. In Xcode, add the Google Mobile Ads package:
//    https://github.com/googleads/swift-package-manager-google-mobile-ads
// 2. Add GADApplicationIdentifier (your AdMob app id) to Info.plist.
// 3. Replace NoOpAdManager with the AdMobAdManager below, and use
//    AdMobBannerView instead of BannerPlaceholderView.
//
// import GoogleMobileAds
//
// @MainActor
// final class AdMobAdManager: NSObject, AdManaging, GADFullScreenContentDelegate {
//     var adsRemoved: Bool = false
//     private var interstitial: GADInterstitialAd?
//     var isInterstitialReady: Bool { interstitial != nil }
//     /// Replace with your real interstitial unit id before release.
//     static let interstitialUnitID = "ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx"
//     private var dismissal: CheckedContinuation<Void, Never>?
//
//     func preloadInterstitial() {
//         guard !adsRemoved else { return }
//         GADInterstitialAd.load(
//             withAdUnitID: Self.interstitialUnitID,
//             request: GADRequest()
//         ) { [weak self] ad, _ in
//             ad?.fullScreenContentDelegate = self
//             self?.interstitial = ad
//         }
//     }
//
//     func showInterstitialIfReady() async -> Bool {
//         guard !adsRemoved, let interstitial else { return false }
//         guard let presenter = Self.topViewController() else { return false }
//         self.interstitial = nil
//         await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
//             self.dismissal = continuation
//             interstitial.present(fromRootViewController: presenter)
//         }
//         return true
//     }
//
//     func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
//         dismissal?.resume()
//         dismissal = nil
//         preloadInterstitial()
//     }
//
//     func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
//         dismissal?.resume()
//         dismissal = nil
//     }
//
//     private static func topViewController() -> UIViewController? {
//         let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
//         var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
//         while let presented = controller?.presentedViewController {
//             controller = presented
//         }
//         return controller
//     }
// }
//
// struct AdMobBannerView: UIViewRepresentable {
//     /// Replace with your real banner unit id before release.
//     var adUnitID: String = "ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx"
//
//     func makeUIView(context: Context) -> GADBannerView {
//         let banner = GADBannerView(adSize: GADAdSizeBanner)
//         banner.adUnitID = adUnitID
//         banner.rootViewController = Self.topViewController()
//         banner.load(GADRequest())
//         return banner
//     }
//
//     func updateUIView(_ uiView: GADBannerView, context: Context) {}
//
//     private static func topViewController() -> UIViewController? {
//         let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
//         var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
//         while let presented = controller?.presentedViewController {
//             controller = presented
//         }
//         return controller
//     }
// }

/// Visible stand-in for the 320×50 banner while AdMob is not linked.
struct BannerPlaceholderView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Color(theme.bannerPlaceholder)
            Text("廣告位置 320×50")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(theme.bannerPlaceholderText))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .overlay(alignment: .top) {
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundColor(Color(theme.bannerPlaceholderText).opacity(0.4))
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("廣告橫額位置")
        .accessibilityIdentifier("banner")
    }
}

struct BannerAdContainer: View {
    var adsRemoved: Bool

    var body: some View {
        if adsRemoved {
            EmptyView()
        } else {
            BannerPlaceholderView()
            // When AdMob is ready, replace the line above with:
            // AdMobBannerView()
            //     .frame(height: 50)
        }
    }
}

/// The bottom banner every screen shows, including sheets and full-screen covers (they
/// cover the root's banner, so each hosts its own). Hidden only when ads are removed or
/// while an interstitial is showing. Accessibility id `banner`.
struct BannerSlot: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        if !vm.model.data.adsRemoved && !vm.isShowingInterstitial {
            BannerAdContainer(adsRemoved: false)
        }
    }
}

extension View {
    /// Pins `BannerSlot` to the bottom safe area of this screen.
    func bannerSlot() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { BannerSlot() }
    }
}

struct AdSafeGap: View {
    var body: some View {
        Color.clear
            .frame(height: 18)
            .accessibilityLabel("安全距離")
    }
}
