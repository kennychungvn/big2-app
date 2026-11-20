import SwiftUI
import UIKit
import AppCore

/// UserDefaults keys added in 2.0 (HANDOFF §1). Existing keys are untouched; 動畫效果
/// keeps using AppData.chaoAnimationEnabled (the old 炒倍動畫 value), so it carries over.
enum SkinPreferences {
    static let skinKey = "skin"
    /// 2.0 betas had a 外觀 picker; the key is no longer read and is cleared on launch.
    static let legacyAppearanceKey = "appearance"
    static let iconFollowsSkinKey = "iconFollowsSkin"

    static func loadSkin(_ defaults: UserDefaults = .standard) -> SkinID {
        defaults.string(forKey: skinKey).flatMap(SkinID.init(rawValue:)) ?? .classic
    }

    static func loadIconFollowsSkin(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: iconFollowsSkinKey) as? Bool ?? true
    }

    static func save(skin: SkinID, _ defaults: UserDefaults = .standard) {
        defaults.set(skin.rawValue, forKey: skinKey)
    }

    static func clearLegacyAppearance(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: legacyAppearanceKey)
    }

    static func save(iconFollowsSkin: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(iconFollowsSkin, forKey: iconFollowsSkinKey)
    }

    static func resetForUITests(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: skinKey)
        defaults.removeObject(forKey: legacyAppearanceKey)
        defaults.removeObject(forKey: iconFollowsSkinKey)
    }
}

/// Forces the skin's fixed colour scheme on every window (status bar, keyboards, alerts,
/// share sheet), independent of the system light/dark setting.
@MainActor
enum SkinWindowStyle {
    static func apply(_ skin: SkinID) {
        let style: UIUserInterfaceStyle = skin.isDark ? .dark : .light
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

/// Primary icon = 經典 (`AppIcon`), alternate = `AppIcon-Ledger`.
@MainActor
enum AppIconSwitcher {
    static var current: SkinID {
        SkinID.fromAlternateIconName(UIApplication.shared.alternateIconName)
    }

    static func apply(_ skin: SkinID) {
        // UI tests: the system "icon changed" alert would block the flow.
        if UITestSupport.isActive { return }
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.applicationState == .active else { return }
        let name = skin.alternateIconName
        guard app.alternateIconName != name else { return }
        app.setAlternateIconName(name) { _ in }
    }
}

/// Skin switch: snapshot crossfade of the whole window (motion spec §9), so
/// colours, fonts, radii and markers swap under the snapshot instead of morphing.
@MainActor
enum SkinTransition {
    static func crossfade(animated: Bool, haptics: Bool, _ change: () -> Void) {
        if haptics { UISelectionFeedbackGenerator().selectionChanged() }
        guard animated,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow),
              let snapshot = window.snapshotView(afterScreenUpdates: false)
        else {
            change()
            return
        }
        window.addSubview(snapshot)
        change()
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            snapshot.alpha = 0
        } completion: { _ in
            snapshot.removeFromSuperview()
        }
    }
}
