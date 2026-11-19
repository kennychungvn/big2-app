import UIKit

/// The UI StoreKit should present its purchase confirmation in: the foreground window
/// scene and the top-most view controller the user is looking at (the 設定 sheet).
@MainActor
struct PurchaseUIContext {
    let scene: UIWindowScene?
    let viewController: UIViewController?
    /// Short description for the 購買紀錄 (debug) log.
    let summary: String

    static func current() -> PurchaseUIContext {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
        let window = scene.flatMap(appWindow(in:))
        let top = window?.rootViewController.map(topMost(from:))
        let summary = "[scenes \(scenes.count), state \(scene.map { stateName($0.activationState) } ?? "none"), "
            + "windows \(scene?.windows.count ?? 0), key \(window?.isKeyWindow == true), "
            + "top \(top.map { String(describing: type(of: $0)) } ?? "none")]"
        return PurchaseUIContext(scene: scene, viewController: top, summary: summary)
    }

    /// The app's own normal-level window: the key window when it is one, else the first
    /// visible normal-level window (ad SDK / alert windows sit at other levels).
    private static func appWindow(in scene: UIWindowScene) -> UIWindow? {
        let normal = scene.windows.filter { $0.windowLevel == .normal && !$0.isHidden && $0.rootViewController != nil }
        return normal.first { $0.isKeyWindow } ?? normal.first
    }

    /// Follows presented controllers (sheets) to the one on screen, skipping alerts and
    /// anything being dismissed.
    private static func topMost(from root: UIViewController) -> UIViewController {
        var current = root
        while let presented = current.presentedViewController,
              !presented.isBeingDismissed,
              !(presented is UIAlertController) {
            current = presented
        }
        return current
    }

    private static func stateName(_ state: UIScene.ActivationState) -> String {
        switch state {
        case .foregroundActive: return "foregroundActive"
        case .foregroundInactive: return "foregroundInactive"
        case .background: return "background"
        case .unattached: return "unattached"
        @unknown default: return "unknown"
        }
    }
}
