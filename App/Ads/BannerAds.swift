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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var adLoaded = false
    /// First request answered (ad or no fill): the loading shimmer stops.
    @State private var requestDone = false

    var body: some View {
        let adSize = Self.adaptiveSize()
        let animated = MotionSettings.enabled && !reduceMotion
        ZStack {
            // §3a: placeholder fades out 200 ms; the ad fades in 250 ms, 50 ms later.
            BannerSlotBackground(loading: !requestDone)
                .opacity(adLoaded ? 0 : 1)
                .animation(animated ? .easeOut(duration: 0.2) : nil, value: adLoaded)
            if runtime.isReady {
                AdMobBannerView(adSize: adSize) { loaded in
                    requestDone = true
                    adLoaded = loaded
                }
                .frame(width: adSize.size.width, height: adSize.size.height)
                .opacity(adLoaded ? 1 : 0)
                .animation(animated ? .easeIn(duration: 0.25).delay(0.05) : nil, value: adLoaded)
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
    var loading: Bool = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Color(theme.adband)
            SuitPatternRow(loading: loading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// ♠♥♣♦ repeating from the left: 15pt glyphs on a 25pt pitch, whole suits only, centred with
/// ≥ 12pt margins. Loading: fade in left to right (200 ms each, 40 ms stagger), then a
/// 120pt shimmer sweep (rest 50 % → 100 %) every 1.2 s, at most 3 loops. Static at 100 %
/// once the request finished, or with Reduce Motion / 動畫效果 off.
struct SuitPatternRow: View {
    var loading: Bool
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private static let pitch: CGFloat = 25
    private static let glyph: CGFloat = 15
    private static let symbols = ["suit.spade", "suit.heart", "suit.club", "suit.diamond"]
    private static let fadeStagger = 0.04
    private static let fadeDuration = 0.2
    private static let loop = 1.2
    private static let maxLoops = 3.0
    private static let sweepWidth: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            let count = max(0, Int((proxy.size.width - 24) / Self.pitch))
            let animate = loading && MotionSettings.enabled && !reduceMotion
            let fadeEnd = Double(max(count - 1, 0)) * Self.fadeStagger + Self.fadeDuration
            TimelineView(.animation(minimumInterval: nil, paused: !animate)) { context in
                let t = context.date.timeIntervalSince(start)
                let running = animate && t < fadeEnd + Self.loop * Self.maxLoops
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        suit(index)
                            .frame(width: Self.pitch, height: Self.glyph)
                            .opacity(running ? opacity(index: index, count: count, t: t, fadeEnd: fadeEnd) : 1)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .onChange(of: loading) { _ in start = Date() }
    }

    @ViewBuilder
    private func suit(_ index: Int) -> some View {
        let name = Self.symbols[index % 4]
        let isRed = index % 2 == 1
        Image(systemName: theme.suitOutline ? name : name + ".fill")
            .font(.system(size: Self.glyph, weight: theme.suitOutline ? .light : .regular))
            .foregroundColor(Color(isRed ? theme.suitRed : theme.suitBlack))
    }

    private func opacity(index: Int, count: Int, t: Double, fadeEnd: Double) -> Double {
        if t < fadeEnd {
            let local = (t - Double(index) * Self.fadeStagger) / Self.fadeDuration
            return 0.5 * min(max(local, 0), 1)
        }
        let phase = ((t - fadeEnd).truncatingRemainder(dividingBy: Self.loop)) / Self.loop
        let rowWidth = CGFloat(count) * Self.pitch
        let sweepX = -Self.sweepWidth / 2 + CGFloat(phase) * (rowWidth + Self.sweepWidth)
        let x = (CGFloat(index) + 0.5) * Self.pitch
        let lift = max(0, 1 - abs(x - sweepX) / (Self.sweepWidth / 2))
        return 0.5 + 0.5 * Double(lift)
    }
}

/// Visible stand-in for the banner used by UI tests (`-uiTestAds`): no SDK, no network.
struct BannerPlaceholderView: View {
    var body: some View {
        BannerSlotBackground(loading: false)
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
            // 2.0 ad band: `adband` fill + 1pt `line` hairline; collapses after 移除廣告.
            BannerAdContainer(adsRemoved: false)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color(theme.adband).ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(theme.line)).frame(height: 1)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var vm: AppViewModel

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            BannerSlot()
        }
        // 移除廣告: the band collapses over 220 ms (instant with 動畫效果 off / Reduce Motion).
        .animation(
            MotionSettings.enabled && !reduceMotion ? .easeOut(duration: 0.22) : nil,
            value: vm.model.data.adsRemoved
        )
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
