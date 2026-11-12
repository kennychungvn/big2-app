import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Owns the start-up order Google and Apple require before any ad request:
///
/// 1. Google UMP consent (shows the GDPR / US-state form only where it is required),
/// 2. then Apple's App Tracking Transparency prompt (`NSUserTrackingUsageDescription`),
/// 3. then `MobileAds.shared.start` – nothing loads before this point.
///
/// Ads are requested as non-personalised (`npa=1`) unless the user allowed tracking.
/// Never runs when ads are removed or under `-uiTestAds`.
@MainActor
final class AdsRuntime: ObservableObject {
    static let shared = AdsRuntime()

    /// `true` once consent + ATT are done and the SDK has started; banners load only then.
    @Published private(set) var isReady = false
    /// UMP says this user must be able to change their consent later (Settings shows a button).
    @Published private(set) var privacyOptionsRequired = false
    private(set) var personalizedAdsAllowed = false

    private var started = false
    private var readyActions: [() -> Void] = []

    private init() {}

    /// Runs `action` as soon as ads may be requested (immediately if they already may).
    func whenReady(_ action: @escaping () -> Void) {
        if isReady { action() } else { readyActions.append(action) }
    }

    /// A request honouring the user's choices. Under UMP the TCF string is read by the SDK
    /// itself; `npa=1` additionally asks for non-personalised ads when tracking was declined.
    func makeRequest() -> Request {
        let request = Request()
        if !personalizedAdsAllowed {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        return request
    }

    func start() async {
        guard !started, !AdConfig.usesStubAds else { return }
        started = true

        await Self.waitUntilAppIsActive()
        let consent = ConsentInformation.shared
        var umpFailed = false
        do {
            let parameters = RequestParameters()
            parameters.isTaggedForUnderAgeOfConsent = false
            try await consent.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: Self.topViewController())
        } catch {
            umpFailed = true
            NSLog("[Ads] UMP consent error: \(error.localizedDescription)")
        }
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required

        // ATT strictly after the UMP form, and only while the app is frontmost.
        let tracking = await Self.requestTrackingAuthorization()
        personalizedAdsAllowed = tracking == .authorized

        // Google's rule: request ads only when UMP allows it. With Google's TEST app id UMP can
        // report a misconfiguration; test builds still start (non-personalised) so the test ads
        // remain visible during development.
        let mayRequest = consent.canRequestAds
            || (umpFailed && AdConfig.isUsingTestAds && consent.consentStatus != .required)
        guard mayRequest else {
            NSLog("[Ads] Consent does not allow ad requests yet; no ads this launch.")
            return
        }
        if !personalizedAdsAllowed || consent.consentStatus == .required {
            personalizedAdsAllowed = false
        }
        MobileAds.shared.start(completionHandler: nil)
        isReady = true
        let actions = readyActions
        readyActions.removeAll()
        actions.forEach { $0() }
    }

    /// Settings → 廣告私隱設定 (only shown when UMP requires it).
    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController())
        } catch {
            NSLog("[Ads] Privacy options error: \(error.localizedDescription)")
        }
    }

    private static func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        let current = ATTrackingManager.trackingAuthorizationStatus
        guard current == .notDetermined else { return current }
        // Give the UMP form time to finish dismissing; ATT is ignored while another
        // presentation is animating or the app is not active.
        try? await Task.sleep(nanoseconds: 600_000_000)
        await waitUntilAppIsActive()
        return await ATTrackingManager.requestTrackingAuthorization()
    }

    private static func waitUntilAppIsActive() async {
        while UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}
