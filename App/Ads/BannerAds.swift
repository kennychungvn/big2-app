import SwiftUI
import UIKit
import GoogleMobileAds
import AppCore

// MARK: - Real AdMob banner

/// Google standard anchored adaptive banner (`BannerView`) for the full screen width,
/// about 50–62 pt tall on iPhone. Loads only after `AdsRuntime` finished UMP consent + ATT.
/// v1.1: the slot ALWAYS reserves the banner's height while ads are on (from the first
/// frame, before consent or the first ad), so nothing above it jumps when an ad arrives.
/// Until an ad is in, the slot shows a subtle placeholder (card colour + faint app icon
/// and name); a received ad fades in over 0.25 s. A failed refresh fades back to the
/// placeholder, never collapses.
/// The slot is exactly the ad size and clips, so the ad never overflows onto bottom buttons.
/// With 移除廣告 bought, `BannerSlot` drops the whole slot.
struct AdMobBannerSlotView: View {
    @ObservedObject private var runtime = AdsRuntime.shared
    @State private var adLoaded = false

    // Build 79 hang fix: back to the 1.0.2 slot (which never froze on device): a static
    // placeholder under the ad, one opacity fade when an ad arrives. No loading shimmer,
    // no per-state animations.
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

/// What the reserved banner slot shows before (or between) ads (HANDOFF §3a): a quiet row
/// of suits ♠♥♣♦ on `adband`, low contrast and with no text, so it never reads as an ad.
/// Not interactive, hidden from VoiceOver.
struct BannerSlotBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Color(theme.adband)
            SuitPatternRow()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// ♠♥♣♦ repeating from the left: 15pt glyphs on a 25pt pitch, whole suits only, centred with
/// ≥ 12pt margins.
///
/// Build 77 / 79 freezes (入名, 入分, 切換外觀: screen stuck for seconds, then iOS killed the
/// app): every screen, sheet and cover hosts its own ad band, and this row used to animate
/// (77: `TimelineView(.animation)` every frame; 79: GeometryReader + staggered fades +
/// repeating masked shimmer + keyboard observers restarting it). It is now completely
/// static: no state, no GeometryReader, no animation, no notifications.
struct SuitPatternRow: View {
    @Environment(\.appTheme) private var theme

    private static let pitch: CGFloat = 25
    private static let glyph: CGFloat = 15
    private static let symbols = ["suit.spade", "suit.heart", "suit.club", "suit.diamond"]

    /// Whole suits that fit the screen width with ≥ 12pt margins (portrait only).
    private var count: Int {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let width = scenes.first?.screen.bounds.width ?? 375
        return max(0, Int((width - 24) / Self.pitch))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                suit(index)
                    .frame(width: Self.pitch, height: Self.glyph)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func suit(_ index: Int) -> some View {
        let name = Self.symbols[index % 4]
        let isRed = index % 2 == 1
        Image(systemName: theme.suitOutline ? name : name + ".fill")
            .font(.system(size: Self.glyph, weight: theme.suitOutline ? .light : .regular))
            .foregroundColor(Color(isRed ? theme.suitRed : theme.suitBlack))
    }
}

/// Visible stand-in for the banner used by UI tests (`-uiTestAds`): no SDK, no network.
struct BannerPlaceholderView: View {
    var body: some View {
        BannerSlotBackground()
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .accessibilityHidden(false)
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        if !vm.model.data.adsRemoved && !vm.isShowingInterstitial {
            // 2.0 ad band: `adband` fill + 1pt `line` hairline. No transition/animation.
            BannerAdContainer(adsRemoved: false)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color(theme.adband).ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(theme.line)).frame(height: 1)
                }
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
