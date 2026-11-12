import SwiftUI
import UIKit
import AppCore

/// Launch switches used by the XCUITest target (`Big2UITests`). None of them are set in normal use.
///
/// - `-uiTesting`: start from empty data and use the stub store so 移除廣告 works without StoreKit.
/// - `-uiTestAds` (`AdConfig.usesStubAds`): no Google Mobile Ads / UMP / ATT at all; the
///   placeholder banner (`banner`) and the dismissible stand-in interstitial below are used.
enum UITestSupport {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }
}

/// Full-screen stand-in for an AdMob interstitial so UI tests can see and close it.
@MainActor
final class UITestInterstitialAdManager: AdManaging {
    var adsRemoved: Bool = false
    var isInterstitialReady: Bool { !adsRemoved }

    func preloadInterstitial() {}

    func showInterstitialIfReady() async -> Bool {
        guard !adsRemoved, let presenter = Self.topViewController() else { return false }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var host: UIHostingController<InterstitialStubView>?
            let view = InterstitialStubView {
                host?.dismiss(animated: false) { continuation.resume() }
            }
            host = UIHostingController(rootView: view)
            host?.modalPresentationStyle = .fullScreen
            presenter.present(host!, animated: false)
        }
        return true
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

struct InterstitialStubView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(white: 0.9).ignoresSafeArea()
            Text("全版廣告（測試）")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("interstitial.title")
            Button(action: onClose) {
                Text("✕")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("interstitial.close")
            .padding(16)
        }
    }
}
