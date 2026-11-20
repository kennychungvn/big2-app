import SwiftUI
import UIKit
import AppCore

/// UserDefaults keys added in 2.0 (HANDOFF §1). Existing keys are untouched; 動畫效果
/// keeps using AppData.chaoAnimationEnabled (the old 炒倍動畫 value), so it carries over.
enum SkinPreferences {
    static let skinKey = "skin"
    static let appearanceKey = "appearance"
    static let iconFollowsSkinKey = "iconFollowsSkin"

    static func loadSkin(_ defaults: UserDefaults = .standard) -> SkinID {
        defaults.string(forKey: skinKey).flatMap(SkinID.init(rawValue:)) ?? .classic
    }

    static func loadAppearance(_ defaults: UserDefaults = .standard) -> AppearancePreference {
        defaults.string(forKey: appearanceKey).flatMap(AppearancePreference.init(rawValue:)) ?? .system
    }

    static func loadIconFollowsSkin(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: iconFollowsSkinKey) as? Bool ?? true
    }

    static func save(skin: SkinID, _ defaults: UserDefaults = .standard) {
        defaults.set(skin.rawValue, forKey: skinKey)
    }

    static func save(appearance: AppearancePreference, _ defaults: UserDefaults = .standard) {
        defaults.set(appearance.rawValue, forKey: appearanceKey)
    }

    static func save(iconFollowsSkin: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(iconFollowsSkin, forKey: iconFollowsSkinKey)
    }

    static func resetForUITests(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: skinKey)
        defaults.removeObject(forKey: appearanceKey)
        defaults.removeObject(forKey: iconFollowsSkinKey)
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

/// Skin / appearance switch: snapshot crossfade of the whole window (motion spec §9), so
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
