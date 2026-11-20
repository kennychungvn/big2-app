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
        let width = UIScreen.main.bounds.width
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
/// ≥ 12pt margins. Loading: fade in left to right (200 ms each, 40 ms stagger, to 50 %), then a
/// 120pt shimmer sweep (50 % → 100 %) every 1.2 s, at most 3 loops. Static at 100 % once the
/// request finished, or with Reduce Motion / 動畫效果 off.
///
/// Build 77 fix: this used to be a `TimelineView(.animation)` re-evaluating the row every
/// display frame while loading. In every sheet that has a real banner (新開一場 …) that ran
/// at the same time as the keyboard's first presentation and starved the main thread
/// (freeze ~4–5 s, then a crash, 「入名有閃退」). Now both effects are plain SwiftUI
/// animations started once (render-server driven, no per-frame body updates), and the
/// row never animates while a text field is being edited.
struct SuitPatternRow: View {
    var loading: Bool
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faded = false
    @State private var sweep = false
    @State private var keyboardUp = false

    private static let pitch: CGFloat = 25
    private static let glyph: CGFloat = 15
    private static let symbols = ["suit.spade", "suit.heart", "suit.club", "suit.diamond"]
    private static let fadeStagger = 0.04
    private static let fadeDuration = 0.2
    private static let loop = 1.2
    private static let maxLoops = 3
    private static let sweepWidth: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            let count = max(0, Int((proxy.size.width - 24) / Self.pitch))
            let animate = loading && !keyboardUp && MotionSettings.enabled && !reduceMotion
            let rowWidth = CGFloat(count) * Self.pitch
            ZStack {
                row(count: count, animate: animate, base: animate ? 0.5 : 1)
                if animate {
                    // Shimmer: the same row at 100 %, revealed through a moving soft band.
                    row(count: count, animate: false, base: 1)
                        .mask(
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: Self.sweepWidth)
                            .offset(x: sweep ? rowWidth / 2 + Self.sweepWidth / 2 : -rowWidth / 2 - Self.sweepWidth / 2)
                        )
                        .opacity(faded ? 1 : 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { start(animate: animate, count: count) }
            .onChange(of: animate) { start(animate: $0, count: count) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            keyboardUp = false
        }
    }

    private func row(count: Int, animate: Bool, base: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                suit(index)
                    .frame(width: Self.pitch, height: Self.glyph)
                    .opacity(animate ? (faded ? base : 0) : base)
                    .animation(
                        animate ? .easeOut(duration: Self.fadeDuration).delay(Double(index) * Self.fadeStagger) : nil,
                        value: faded
                    )
            }
        }
    }

    private func start(animate: Bool, count: Int) {
        guard animate else {
            faded = true
            sweep = false
            return
        }
        faded = false
        sweep = false
        DispatchQueue.main.async {
            faded = true
            let fadeEnd = Double(max(count - 1, 0)) * Self.fadeStagger + Self.fadeDuration
            withAnimation(.linear(duration: Self.loop).repeatCount(Self.maxLoops, autoreverses: false).delay(fadeEnd)) {
                sweep = true
            }
        }
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
