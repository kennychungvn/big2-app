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

/// One long-lived home `BannerView`, created and loaded once after `MobileAds.shared.start()`
/// finishes. Home, Settings and other slots re-parent this instance into the frontmost
/// visible host. The 新開一場 sheet uses a separate `SheetBannerController` so opening
/// that sheet never moves this view (moving it mid-load stalled the main thread for
/// 13.8 s). A slot that does not currently hold the banner keeps the reserved placeholder.
@MainActor
final class SharedBannerController: NSObject, ObservableObject, BannerViewDelegate {
    static let shared = SharedBannerController()

    /// `true` once an ad is received, `false` after a failed load / refresh.
    @Published private(set) var hasAd = false
    /// `true` between `load()` and the matching success or failure callback.
    /// The name-entry sheet waits for this to drop so two banner loads never run at once.
    private(set) var isLoadInFlight = false

    private var banner: BannerView?
    private var didRequestLoad = false
    private var keyboardVisible = false
    private var adSize: AdSize?
    private var hosts: [BannerHostView] = []
    private var keyboardObservers: [NSObjectProtocol] = []

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
        banner.rootViewController = AdsRuntime.topViewController()
        self.banner = banner
        observeKeyboard()
        requestLoadIfAllowed()
    }

    /// Defer the first `load()` while the keyboard is up, and keep
    /// `isAutoloadEnabled` off so the SDK does not start a new request mid-typing.
    /// An already-shown creative stays visible if the slot is still on screen
    /// above the keyboard.
    func setKeyboardVisible(_ visible: Bool) {
        keyboardVisible = visible
        banner?.isAutoloadEnabled = false
        if !visible {
            requestLoadIfAllowed()
        }
    }

    func requestLoadIfAllowed() {
        guard let banner, !didRequestLoad, !keyboardVisible else { return }
        didRequestLoad = true
        isLoadInFlight = true
        banner.rootViewController = AdsRuntime.topViewController() ?? banner.rootViewController
        banner.load(AdsRuntime.shared.makeRequest())
    }

    func attach(to host: BannerHostView, adSize: AdSize) {
        self.adSize = adSize
        if !hosts.contains(where: { $0 === host }) {
            hosts.append(host)
        }
        applyAdSizeIfNeeded()
        reassign()
    }

    func detach(from host: BannerHostView) {
        hosts.removeAll { $0 === host }
        if banner?.superview === host {
            banner?.removeFromSuperview()
        }
        reassign()
    }

    func hostDidChangeWindow() {
        reassign()
    }

    private func reassign() {
        hosts.removeAll { $0.window == nil }
        // Only a host on the frontmost screen may show the banner, so a live ad is
        // never left refreshing under a sheet.
        let visible = hosts.filter { Self.isInFrontmostPresentation($0) }
        moveBanner(to: visible.last)
    }

    private func moveBanner(to host: BannerHostView?) {
        guard let banner else { return }
        applyAdSizeIfNeeded()
        guard let host else {
            banner.removeFromSuperview()
            return
        }
        if banner.superview !== host {
            banner.removeFromSuperview()
            banner.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: host.topAnchor),
                banner.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                banner.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
        }
        banner.rootViewController = AdsRuntime.topViewController() ?? banner.rootViewController
    }

    private func applyAdSizeIfNeeded() {
        guard let banner, let adSize else { return }
        if !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) {
            banner.adSize = adSize
        }
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

    private static func isInFrontmostPresentation(_ view: UIView) -> Bool {
        guard view.window != nil, !view.isHidden, view.alpha > 0.01 else { return false }
        guard let topView = AdsRuntime.topViewController()?.viewIfLoaded else { return true }
        return view.isDescendant(of: topView)
    }

    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor [weak self] in
            self?.isLoadInFlight = false
            self?.hasAd = true
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        NSLog("[Ads] Banner failed to load: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.isLoadInFlight = false
            self?.hasAd = false
        }
    }
}

/// Container a `BannerSlot` uses to borrow the shared or sheet `BannerView`.
final class BannerHostView: UIView {
    var onWindowChange: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?()
    }
}

/// Dedicated `BannerView` for the 新開一場 name-entry sheet. Created once per
/// app session after `MobileAds.shared.start()`, kept alive, and reused across
/// presentations. The first `load()` runs only while the sheet is on screen,
/// after the present animation, after the home banner has finished, and — if
/// the keyboard is already up — a further 1 s after `keyboardDidShow`, so the
/// request does not overlap presentation or keyboard bring-up. Autoload stays
/// off. The view is never re-parented while a request is in flight, and it is
/// not loaded off-screen (Google: no hidden impressions, no ads that are never shown).
@MainActor
final class SheetBannerController: NSObject, ObservableObject, BannerViewDelegate {
    static let shared = SheetBannerController()

    @Published private(set) var hasAd = false

    private enum LoadState {
        case idle, inFlight, filled, failed
    }

    private var banner: BannerView?
    private var adSize: AdSize?
    private var hosts: [BannerHostView] = []
    private var loadState: LoadState = .idle
    private var keyboardVisible = false
    private var sawKeyboardThisPresentation = false
    private var keyboardObservers: [NSObjectProtocol] = []
    private var loadTask: Task<Void, Never>?
    /// Caps automatic retries so SwiftUI's `updateUIView` cannot start a new
    /// request on every refresh after a failed load.
    private var attemptedLoads = 0

    private override init() {
        super.init()
    }

    /// Allocates the view only. Does not call `load()` — the banner is not on
    /// screen yet.
    func prepare() {
        guard UITestSupport.showsLiveBanner else { return }
        guard banner == nil else { return }
        let size = anchoredAdaptiveBannerSize()
        adSize = size
        let banner = BannerView(adSize: size)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = self
        banner.isAutoloadEnabled = false
        self.banner = banner
        observeKeyboard()
    }

    func attach(to host: BannerHostView, adSize: AdSize) {
        self.adSize = adSize
        if !hosts.contains(where: { $0 === host }) {
            hosts.append(host)
        }
        // Never move the view mid-request (that is what caused the 13.8 s stall
        // when the home banner was re-parented onto this sheet).
        if loadState == .inFlight, let banner, banner.superview != nil, banner.superview !== host {
            return
        }
        moveBanner(to: host)
        if loadState == .idle || (loadState == .failed && attemptedLoads < 2) {
            scheduleFirstLoadIfNeeded()
        }
    }

    func detach(from host: BannerHostView) {
        hosts.removeAll { $0 === host }
        if banner?.superview === host {
            banner?.removeFromSuperview()
        }
        if visibleHost() == nil {
            loadTask?.cancel()
            loadTask = nil
            sawKeyboardThisPresentation = false
        } else if loadState != .inFlight {
            moveBanner(to: visibleHost())
        }
    }

    func hostDidChangeWindow() {
        if let host = visibleHost() {
            if loadState == .inFlight, let banner, banner.superview != nil, banner.superview !== host {
                return
            }
            moveBanner(to: host)
            if loadState == .idle || (loadState == .failed && attemptedLoads < 2) {
                scheduleFirstLoadIfNeeded()
            }
        } else {
            loadTask?.cancel()
            loadTask = nil
            sawKeyboardThisPresentation = false
            if loadState != .inFlight {
                banner?.removeFromSuperview()
            }
        }
    }

    private func scheduleFirstLoadIfNeeded() {
        guard loadState == .idle || loadState == .failed else { return }
        guard banner?.window != nil else { return }
        if let loadTask, !loadTask.isCancelled { return }

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Let the sheet present animation finish (~0.35 s) before any work.
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }

            // Never two concurrent banner loads.
            while SharedBannerController.shared.isLoadInFlight {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
            }

            // If the keyboard already came up, wait 1 s after it is shown so
            // the request does not overlap keyboard animation. If it is still
            // down, start now so the first-load cost can finish before the
            // first name field is focused (pre-edit stalls are dropped from
            // the hang-detector verdict).
            if self.keyboardVisible || self.sawKeyboardThisPresentation {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }

            self.requestLoadIfVisible()
        }
    }

    private func requestLoadIfVisible() {
        guard loadState == .idle || loadState == .failed else { return }
        guard let banner, banner.window != nil else { return }
        attemptedLoads += 1
        loadState = .inFlight
        banner.isAutoloadEnabled = false
        banner.rootViewController = AdsRuntime.topViewController() ?? banner.rootViewController
        NSLog("[Ads] Sheet banner requesting ad")
        banner.load(AdsRuntime.shared.makeRequest())
    }

    private func visibleHost() -> BannerHostView? {
        hosts.removeAll { $0.window == nil }
        return hosts.last { $0.window != nil && !$0.isHidden && $0.alpha > 0.01 }
    }

    private func moveBanner(to host: BannerHostView?) {
        guard let banner else { return }
        if let adSize, !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) {
            banner.adSize = adSize
        }
        guard let host else {
            banner.removeFromSuperview()
            return
        }
        if banner.superview !== host {
            banner.removeFromSuperview()
            banner.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: host.topAnchor),
                banner.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                banner.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
        }
        banner.rootViewController = AdsRuntime.topViewController() ?? banner.rootViewController
    }

    private func observeKeyboard() {
        guard keyboardObservers.isEmpty else { return }
        let center = NotificationCenter.default
        keyboardObservers.append(center.addObserver(
            forName: UIResponder.keyboardDidShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.keyboardVisible = true
                self?.sawKeyboardThisPresentation = true
            }
        })
        keyboardObservers.append(center.addObserver(
            forName: UIResponder.keyboardDidHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.keyboardVisible = false
            }
        })
    }

    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        NSLog("[Ads] Sheet banner received ad")
        Task { @MainActor [weak self] in
            self?.loadState = .filled
            self?.hasAd = true
            self?.loadTask = nil
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        NSLog("[Ads] Sheet banner failed to load: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.loadState = .failed
            self?.hasAd = false
            self?.loadTask = nil
        }
    }
}


/// Which `BannerView` a 60 pt slot should host. Visual layout is the same
/// for all cases: reserved height, suit placeholder until an ad is in.
enum BannerSlotKind {
    /// Suit placeholder only; no live `BannerView`.
    case placeholder
    /// The shared home / Settings / scoreboard banner.
    case shared
    /// Dedicated, once-per-session banner for the 新開一場 name-entry sheet.
    case sheet
}

struct AdMobBannerSlotView: View {
    var kind: BannerSlotKind = .shared
    @ObservedObject private var runtime = AdsRuntime.shared
    @ObservedObject private var sharedBanner = SharedBannerController.shared
    @ObservedObject private var sheetBanner = SheetBannerController.shared

    // Build 79 hang fix: back to the 1.0.2 slot (which never froze on device): a static
    // placeholder under the ad, one opacity fade when an ad arrives. No loading shimmer,
    // no per-state animations.
    var body: some View {
        let adSize = anchoredAdaptiveBannerSize()
        let showsLive = kind != .placeholder && runtime.isReady && UITestSupport.showsLiveBanner
        let filled = kind == .sheet ? sheetBanner.hasAd : sharedBanner.hasAd
        ZStack {
            BannerSlotBackground()
            // Regular UI tests keep the static placeholder: a filled demo BannerView
            // is a WKWebView that keeps XCUITest waiting for idle (first name-field
            // focus was 15–18 s). Production, TestFlight, and `-uiTestLiveBanner`
            // still mount the live banner. The reserved slot stays either way.
            if showsLive {
                bannerHost(adSize: adSize)
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    .opacity(filled ? 1 : 0)
                    .animation(.easeIn(duration: 0.25), value: filled)
            }
            if kind == .sheet {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("banner.sheet")
                    .accessibilityLabel(sheetBanner.hasAd ? "filled" : "placeholder")
                    .accessibilityValue(sheetBanner.hasAd ? "filled" : "placeholder")
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: adSize.size.height, alignment: .top)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("banner")
    }

    @ViewBuilder
    private func bannerHost(adSize: AdSize) -> some View {
        if kind == .sheet {
            SheetBannerHostRepresentable(adSize: adSize)
        } else {
            SharedBannerHostRepresentable(adSize: adSize)
        }
    }
}

/// Re-parents the shared `BannerView` into this slot when the slot is on the
/// frontmost screen. `dismantleUIView` does not destroy the banner.
private struct SharedBannerHostRepresentable: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerHostView {
        let host = BannerHostView()
        host.backgroundColor = .clear
        host.clipsToBounds = true
        host.onWindowChange = {
            Task { @MainActor in
                SharedBannerController.shared.hostDidChangeWindow()
            }
        }
        SharedBannerController.shared.attach(to: host, adSize: adSize)
        return host
    }

    func updateUIView(_ host: BannerHostView, context: Context) {
        SharedBannerController.shared.attach(to: host, adSize: adSize)
    }

    static func dismantleUIView(_ host: BannerHostView, coordinator: ()) {
        host.onWindowChange = nil
        SharedBannerController.shared.detach(from: host)
    }
}

/// Hosts the dedicated name-entry `BannerView`. `dismantleUIView` does not
/// destroy the banner; it is reused the next time the sheet appears.
private struct SheetBannerHostRepresentable: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerHostView {
        let host = BannerHostView()
        host.backgroundColor = .clear
        host.clipsToBounds = true
        host.onWindowChange = {
            Task { @MainActor in
                SheetBannerController.shared.hostDidChangeWindow()
            }
        }
        SheetBannerController.shared.attach(to: host, adSize: adSize)
        return host
    }

    func updateUIView(_ host: BannerHostView, context: Context) {
        SheetBannerController.shared.attach(to: host, adSize: adSize)
    }

    static func dismantleUIView(_ host: BannerHostView, coordinator: ()) {
        host.onWindowChange = nil
        SheetBannerController.shared.detach(from: host)
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

/// The bottom banner every screen shows, including sheets and full-screen covers.
/// Sheets cover the root slot, so each still reserves the 60pt band. Most sheets
/// reuse one shared `BannerView` (re-parented into the frontmost host) instead of
/// loading a second ad. The name-entry sheet uses a dedicated `BannerView` that
/// is created once per session and loaded only after the sheet has settled, so
/// opening 新開一場 never re-parents a loading home banner and never starts a
/// second request at the same moment as the keyboard.
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

    @State private var height: CGFloat = BannerSlot.expandedHeight
    @State private var holdsContent = true

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
        .onAppear { applyAdsRemoved(vm.model.data.adsRemoved, animated: false) }
        .onChange(of: vm.model.data.adsRemoved) { removed in
            applyAdsRemoved(removed, animated: true)
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
