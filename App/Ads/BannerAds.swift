import SwiftUI
import UIKit
import GoogleMobileAds
import AppCore

// MARK: - Real AdMob banner

/// Google standard anchored adaptive banner (`BannerView`) for the full screen width,
/// about 50–62 pt tall on iPhone. Loads only after `AdsRuntime` finished UMP consent + ATT.
/// v1.1: the slot ALWAYS reserves the banner's height while ads are on (from the first
/// frame, before consent or the first ad), so nothing above it jumps when an ad arrives.
/// Until an ad is in, the slot shows a subtle placeholder (card colour + tiny 廣告); a received
/// ad fades in over 0.25 s. A failed refresh fades back to the placeholder, never collapses.
/// The slot is exactly the ad size and clips, so the ad never overflows onto bottom buttons.
/// With 移除廣告 bought, `BannerSlot` drops the whole slot.
struct AdMobBannerSlotView: View {
    @ObservedObject private var runtime = AdsRuntime.shared
    @State private var adLoaded = false

    var body: some View {
        let adSize = Self.adaptiveSize()
        ZStack {
            BannerSlotBackground()
            if runtime.isReady {
                AdMobBannerView(adSize: adSize) { loaded in
                    withAnimation(.easeIn(duration: 0.25)) { adLoaded = loaded }
                }
                .frame(width: adSize.size.width, height: adSize.size.height)
                .opacity(adLoaded ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: adSize.size.height, alignment: .top)
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
    /// `true` once an ad is received, `false` after a failed load / refresh.
    let onLoadedChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoadedChange: onLoadedChange) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.load(AdsRuntime.shared.makeRequest())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        context.coordinator.onLoadedChange = onLoadedChange
        if !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) {
            banner.adSize = adSize
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var onLoadedChange: (Bool) -> Void

        init(onLoadedChange: @escaping (Bool) -> Void) {
            self.onLoadedChange = onLoadedChange
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            DispatchQueue.main.async { self.onLoadedChange(true) }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            NSLog("[Ads] Banner failed to load: \(error.localizedDescription)")
            DispatchQueue.main.async { self.onLoadedChange(false) }
        }
    }
}

/// What the reserved banner slot shows before (or between) ads: the card colour with a tiny
/// grey 廣告, so the bar reads as an ad space rather than a glitch.
struct BannerSlotBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Color(theme.card)
            Text(tr("廣告"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(theme.secondaryText).opacity(0.6))
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(theme.secondaryText).opacity(0.15))
                .frame(height: 0.5)
        }
        .accessibilityHidden(true)
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
    /// button sits above it; the slot keeps the banner's full height while ads are on.
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
