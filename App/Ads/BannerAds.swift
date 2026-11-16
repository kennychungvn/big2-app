import SwiftUI
import UIKit
import GoogleMobileAds
import AppCore

// MARK: - Real AdMob banner

/// Google standard anchored adaptive banner (`BannerView`) for the full screen width,
/// about 50–62 pt tall on iPhone. Loads only after `AdsRuntime` finished UMP consent + ATT.
/// The slot takes NO height until an ad has actually been received, and collapses again if
/// a refresh fails, so a not-yet-approved AdMob account never leaves an empty bar. Once an
/// ad is in, the slot is exactly the ad's height and clips, so the ad can never overflow
/// upwards onto the screen's bottom buttons.
struct AdMobBannerSlotView: View {
    @ObservedObject private var runtime = AdsRuntime.shared
    @State private var loadedHeight: CGFloat = 0

    var body: some View {
        let adSize = Self.adaptiveSize()
        ZStack(alignment: .top) {
            if runtime.isReady {
                AdMobBannerView(adSize: adSize) { height in
                    loadedHeight = height
                }
                .frame(width: adSize.size.width, height: adSize.size.height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: runtime.isReady ? loadedHeight : 0, alignment: .top)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("banner")
    }

    /// Standard anchored adaptive size for the current (portrait-only) orientation at full
    /// width. Not the "large" anchored variant: that one is far taller (a quarter of the
    /// screen on build 41) and hid the sheets' bottom buttons.
    private static func adaptiveSize() -> AdSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let width = scenes.first?.screen.bounds.width ?? 375
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }
}

private struct AdMobBannerView: UIViewRepresentable {
    let adSize: AdSize
    /// Height to reserve: the ad's height once one is received, 0 after a failure.
    let onHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onHeightChange: onHeightChange) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.load(AdsRuntime.shared.makeRequest())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        context.coordinator.onHeightChange = onHeightChange
        context.coordinator.maxHeight = adSize.size.height
        if !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) {
            banner.adSize = adSize
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var onHeightChange: (CGFloat) -> Void
        var maxHeight: CGFloat = 0

        init(onHeightChange: @escaping (CGFloat) -> Void) {
            self.onHeightChange = onHeightChange
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            let height = bannerView.adSize.size.height
            let capped = maxHeight > 0 ? min(height, maxHeight) : height
            DispatchQueue.main.async { self.onHeightChange(capped) }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            NSLog("[Ads] Banner failed to load: \(error.localizedDescription)")
            DispatchQueue.main.async { self.onHeightChange(0) }
        }
    }
}

/// Visible stand-in for the banner used by UI tests (`-uiTestAds`): no SDK, no network.
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
        } else if AdConfig.usesStubAds {
            BannerPlaceholderView()
        } else {
            AdMobBannerSlotView()
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
    /// Puts `BannerSlot` under this screen. A VStack rather than `safeAreaInset`: an inset
    /// applied outside a NavigationStack does not reach pushed screens or the sheet's own
    /// bottom inset, so the banner covered 入今局 / 開波 (seen in UI test screenshots).
    /// The VStack gives the content only the space above the banner, so every bottom
    /// button sits above it; the banner itself is 0 pt until an ad loads.
    func bannerSlot() -> some View {
        modifier(BannerSlotModifier())
    }
}

private struct BannerSlotModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            BannerSlot()
        }
        .background(Color(theme.background).ignoresSafeArea())
    }
}

struct AdSafeGap: View {
    var body: some View {
        Color.clear
            .frame(height: 18)
            .accessibilityLabel("安全距離")
    }
}
