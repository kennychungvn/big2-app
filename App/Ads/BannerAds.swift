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
/// With 移除廣告 bought, `BannerSlot` collapses the 60pt band (220 ms when motion is on).

/// Standard anchored adaptive size for the current (portrait-only) orientation at full
/// width. Not the "large" anchored variant: that one is far taller (a quarter of the
/// screen on build 41) and hid the sheets' bottom buttons.
func anchoredAdaptiveBannerSize() -> AdSize {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let width = scenes.first?.screen.bounds.width ?? 375
    return currentOrientationAnchoredAdaptiveBanner(width: width)
}

/// One long-lived `BannerView`, created and loaded once after `MobileAds.shared.start()`.
/// It lives in a small overlay `UIWindow` pinned to the bottom of the screen, so
/// presenting 新開一場 never re-parents the view and never starts a second WKWebView.
/// Re-parenting a filled banner onto that sheet still stalled the main thread for 9 s
/// while typing (run 44892572340); a second BannerView+load() stalled 7.8 s
/// (44890158068); moving it mid-load stalled 13.8 s. Each screen still reserves a
/// 60 pt slot with the suit placeholder until an ad is in; the overlay sits on top
/// and is hidden on load failure, no-fill, 移除廣告, or an interstitial. Autoload stays off.
@MainActor
final class SharedBannerController: NSObject, ObservableObject, BannerViewDelegate {
    static let shared = SharedBannerController()

    /// `true` once an ad is received, `false` after a failed load / refresh.
    @Published private(set) var hasAd = false

    private var banner: BannerView?
    private var didRequestLoad = false
    private var isLoadInFlight = false
    private var keyboardVisible = false
    private var adSize: AdSize?
    private var keyboardObservers: [NSObjectProtocol] = []
    private var overlayWindow: UIWindow?
    private var overlayHidden = false
    /// Name-entry sheet is on screen. No new ad request until it is dismissed.
    private var nameEntryVisible = false

    private static let slotHeight: CGFloat = 60
    private static let verticalPadding: CGFloat = 5

    private override init() {
        super.init()
    }

    /// Call once `MobileAds.shared.start()` has completed. No-op under `-uiTesting`
    /// unless `-uiTestLiveBanner` is also set, so regular UI tests keep the static
    /// placeholder (824a377).
    func prepare() {
        guard UITestSupport.showsLiveBanner else { return }
        guard banner == nil else { return }
        let size = anchoredAdaptiveBannerSize()
        adSize = size
        let banner = BannerView(adSize: size)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = self
        banner.isAutoloadEnabled = false
        // Must stay visible in the window. A hidden BannerView never fills
        // (hang test run 44894994224: SHEET_BANNER_STATE=placeholder, no ad
        // on the 新開一場 screenshot, and a 3 s stall while the request hung).
        banner.alpha = 1
        self.banner = banner
        observeKeyboard()
        installOverlayIfNeeded()
        requestLoadIfAllowed()
    }

    /// Hide the overlay (and its touch target) while ads are removed or an
    /// interstitial is on screen. The reserved slot still collapses on its own.
    func setOverlayHidden(_ hidden: Bool) {
        overlayHidden = hidden
        if !hidden {
            installOverlayIfNeeded()
        }
        applyOverlayVisibility()
    }

    /// Defer the first `load()` while the keyboard is up, and keep
    /// `isAutoloadEnabled` off so the SDK does not start a new request mid-typing.
    /// The overlay window is also hidden while the keyboard is visible: the
    /// banner sits under the keyboard anyway, and laying out its WKWebView
    /// as the keyboard comes up is what stalled DaLaoEr for 25 s on first
    /// name-field focus (run 44897372915, maxEditingMs=25355).
    func setKeyboardVisible(_ visible: Bool) {
        keyboardVisible = visible
        banner?.isAutoloadEnabled = false
        if !visible {
            installOverlayIfNeeded()
            applyOverlayVisibility()
            if !nameEntryVisible {
                requestLoadIfAllowed()
            }
        } else {
            applyOverlayVisibility()
        }
    }

    /// Call from the name-entry sheet's reserved slot. While the sheet is up
    /// there is no new ad request and the banner is not moved. If the first
    /// load has not filled yet, the overlay stays hidden (suit placeholder).
    /// After dismissal the overlay returns and a pending first load may start.
    func setNameEntryVisible(_ visible: Bool) {
        nameEntryVisible = visible
        banner?.isAutoloadEnabled = false
        if !visible {
            installOverlayIfNeeded()
            applyOverlayVisibility()
            requestLoadIfAllowed()
        } else {
            applyOverlayVisibility()
        }
    }

    func requestLoadIfAllowed() {
        guard let banner, !didRequestLoad, !keyboardVisible, !nameEntryVisible else { return }
        didRequestLoad = true
        isLoadInFlight = true
        banner.rootViewController = overlayWindow?.rootViewController ?? AdsRuntime.topViewController() ?? banner.rootViewController
        banner.load(AdsRuntime.shared.makeRequest())
    }

    /// Hide the overlay for 移除廣告 / interstitials, while the keyboard is up,
    /// or while the name-entry sheet is up and there is not yet a filled ad.
    /// Never sets `banner.isHidden` — a hidden BannerView may never fill.
    private var shouldHideOverlay: Bool {
        overlayHidden || keyboardVisible || (nameEntryVisible && !hasAd)
    }

    private func applyOverlayVisibility() {
        overlayWindow?.isHidden = shouldHideOverlay
    }

    private func installOverlayIfNeeded() {
        guard UITestSupport.showsLiveBanner, let banner else { return }
        if overlayWindow != nil {
            applyOverlayVisibility()
            return
        }
        guard let scene = Self.activeWindowScene() else { return }
        let screen = scene.coordinateSpace.bounds
        let safeBottom = scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom
            ?? scene.windows.first?.safeAreaInsets.bottom
            ?? 0
        let height = Self.slotHeight + safeBottom
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: screen.height - height, width: screen.width, height: height)
        // Above sheets in the main window, below alerts and the keyboard.
        window.windowLevel = UIWindow.Level.alert - 1
        window.backgroundColor = .clear
        window.isOpaque = false
        let host = UIViewController()
        host.view.backgroundColor = .clear
        window.rootViewController = host
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.rootViewController = host
        host.view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            banner.topAnchor.constraint(equalTo: host.view.topAnchor, constant: Self.verticalPadding),
            banner.heightAnchor.constraint(equalToConstant: Self.slotHeight - Self.verticalPadding * 2),
        ])
        overlayWindow = window
        applyOverlayVisibility()
        NSLog("[Ads] Banner overlay window installed")
    }

    private func observeKeyboard() {
        guard keyboardObservers.isEmpty else { return }
        let center = NotificationCenter.default
        keyboardObservers.append(center.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setKeyboardVisible(true)
            }
        })
        keyboardObservers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setKeyboardVisible(false)
            }
        })
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        NSLog("[Ads] Banner received ad")
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoadInFlight = false
            self.hasAd = true
            self.banner?.alpha = 1
            self.banner?.isHidden = false
            // Do not reveal a freshly filled WKWebView under a rising keyboard.
            if !self.keyboardVisible {
                self.installOverlayIfNeeded()
            }
            self.applyOverlayVisibility()
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        NSLog("[Ads] Banner failed to load: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoadInFlight = false
            self.hasAd = false
            // Keep the suit placeholder; do not start another request.
            self.banner?.alpha = 0
        }
    }
}

/// Which 60 pt slot this screen should reserve. Visual layout is the same
/// for all cases: reserved height, suit placeholder until an ad is in.
/// The live `BannerView` is not hosted in the slot; it lives in the overlay window.
enum BannerSlotKind {
    /// Suit placeholder only.
    case placeholder
    /// Home / Settings / scoreboard reserved slot.
    case shared
    /// Name-entry sheet reserved slot (exposes `banner.sheet` for hang tests).
    case sheet
}

struct AdMobBannerSlotView: View {
    var kind: BannerSlotKind = .shared
    @ObservedObject private var sharedBanner = SharedBannerController.shared

    // Build 79 hang fix: back to the 1.0.2 slot (which never froze on device): a static
    // placeholder under the ad, one opacity fade when an ad arrives. No loading shimmer,
    // no per-state animations. The live BannerView is in the overlay window, not here,
    // so opening a sheet never re-parents a WKWebView.
    var body: some View {
        let adSize = anchoredAdaptiveBannerSize()
        ZStack {
            BannerSlotBackground()
            if kind == .sheet || kind == .shared {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier(kind == .sheet ? "banner.sheet" : "banner.home")
                    .accessibilityLabel(sharedBanner.hasAd ? "filled" : "placeholder")
                    .accessibilityValue(sharedBanner.hasAd ? "filled" : "placeholder")
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: adSize.size.height, alignment: .top)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("banner")
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
    var kind: BannerSlotKind = .shared

    var body: some View {
        if adsRemoved {
            EmptyView()
        } else if AdConfig.usesStubAds {
            BannerPlaceholderView()
        } else {
            AdMobBannerSlotView(kind: kind)
        }
    }
}

/// The bottom banner band every screen shows, including sheets and full-screen covers.
/// Sheets cover the root slot, so each still reserves the 60pt band. The live
/// `BannerView` lives in a window-level overlay aligned with that band, so opening
/// 新開一場 never re-parents a WKWebView and never starts a second ad request.
/// Hidden while an interstitial is showing (instant). After 移除廣告,
/// the 60pt band collapses to 0 over 220 ms when 動畫效果 is on and Reduce Motion
/// is off; otherwise it collapses instantly.
/// SuitPatternRow stays static — only the slot height animates, once.
struct BannerSlot: View {
    var kind: BannerSlotKind = .shared
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 50pt ad + 5pt padding on each side.
    private static let expandedHeight: CGFloat = 60

    @State private var height: CGFloat = UITestSupport.hidesBanner ? 0 : BannerSlot.expandedHeight
    @State private var holdsContent = !UITestSupport.hidesBanner

    var body: some View {
        let hideForInterstitial = vm.isShowingInterstitial
        ZStack(alignment: .top) {
            if holdsContent && !hideForInterstitial {
                // 2.0 ad band: `adband` fill + 1pt `line` hairline. No content animation.
                BannerAdContainer(adsRemoved: false, kind: kind)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(Color(theme.adband).ignoresSafeArea(edges: .bottom))
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color(theme.line)).frame(height: 1)
                    }
            }
        }
        .frame(height: hideForInterstitial ? 0 : height)
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear {
            applyAdsRemoved(vm.model.data.adsRemoved || UITestSupport.hidesBanner, animated: false)
            SharedBannerController.shared.setOverlayHidden(
                vm.model.data.adsRemoved || UITestSupport.hidesBanner || hideForInterstitial
            )
            if kind == .sheet {
                SharedBannerController.shared.setNameEntryVisible(true)
            }
        }
        .onDisappear {
            if kind == .sheet {
                SharedBannerController.shared.setNameEntryVisible(false)
            }
        }
        .onChange(of: vm.model.data.adsRemoved) { removed in
            applyAdsRemoved(removed, animated: true)
            SharedBannerController.shared.setOverlayHidden(removed || vm.isShowingInterstitial)
        }
        .onChange(of: vm.isShowingInterstitial) { showing in
            SharedBannerController.shared.setOverlayHidden(vm.model.data.adsRemoved || showing)
        }
        .onChange(of: height) { newHeight in
            if newHeight < 0.5 { holdsContent = false }
        }
    }

    private func applyAdsRemoved(_ removed: Bool, animated: Bool) {
        if !removed {
            holdsContent = true
            height = Self.expandedHeight
            return
        }
        let shouldAnimate = animated && MotionSettings.enabled && !reduceMotion
        if shouldAnimate {
            withAnimation(.easeInOut(duration: 0.22)) {
                height = 0
            }
        } else {
            height = 0
            holdsContent = false
        }
    }
}

extension View {
    /// Puts `BannerSlot` under this screen. A VStack rather than `safeAreaInset`: an inset
    /// applied outside a NavigationStack does not reach pushed screens or the sheet's own
    /// bottom inset, so the banner covered 入今局 / 開波 (seen in UI test screenshots).
    /// The VStack gives the content only the space above the banner, so every bottom
    /// button sits above it; the slot keeps the banner's full height while ads are on.
    func bannerSlot(_ kind: BannerSlotKind = .shared) -> some View {
        modifier(BannerSlotModifier(kind: kind))
    }
}

private struct BannerSlotModifier: ViewModifier {
    var kind: BannerSlotKind = .shared
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            BannerSlot(kind: kind)
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
