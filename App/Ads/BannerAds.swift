import SwiftUI
import UIKit
import GoogleMobileAds
import AppCore

// MARK: - Real AdMob banner

/// Google adaptive anchored banner (`BannerView`), sized for the full portrait width.
/// Loads only after `AdsRuntime` finished UMP consent + ATT; until then (or if no ad fills)
/// the slot keeps its height so the layout does not jump.
struct AdMobBannerSlotView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var runtime = AdsRuntime.shared

    var body: some View {
        let adSize = Self.adaptiveSize()
        ZStack {
            Color(theme.background)
            if runtime.isReady {
                AdMobBannerView(adSize: adSize)
                    .frame(width: adSize.size.width, height: adSize.size.height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: adSize.size.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("banner")
    }

    /// The app is portrait-only, so the portrait anchored adaptive size is always right.
    private static func adaptiveSize() -> AdSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let width = scenes.first?.screen.bounds.width ?? 375
        return largePortraitAnchoredAdaptiveBanner(width: width)
    }
}

private struct AdMobBannerView: UIViewRepresentable {
    let adSize: AdSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.load(AdsRuntime.shared.makeRequest())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        if !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) {
            banner.adSize = adSize
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            NSLog("[Ads] Banner failed to load: \(error.localizedDescription)")
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
