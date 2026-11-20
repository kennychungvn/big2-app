import Foundation
import ScoringEngine

/// Product flavor for the shared AppCore + views.
///
/// The `TAIWAN` compile flag is set on the `DaLaoEr` app target, but AppCore is
/// a Swift package and does not inherit that flag. Detection therefore also
/// reads the target's Info.plist (`AppFlavor`) and bundle id so the Taiwan app
/// actually gets Taiwan rules and copy. The Hong Kong target never defines
/// `TAIWAN` and keeps bundle id `com.kenny.daidee`.
public enum AppFlavor: String, Equatable, Sendable {
    case hongKong
    case taiwan

    public static var current: AppFlavor {
        #if TAIWAN
        let flag = true
        #else
        let flag = false
        #endif
        return resolve(
            compilationFlagTaiwan: flag,
            plistFlavor: Bundle.main.object(forInfoDictionaryKey: "AppFlavor") as? String,
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
    }

    /// True when running inside the 大老二計分 target (`com.kenny.dalaoer`).
    public static var runtimeIsTaiwanApp: Bool {
        resolve(
            compilationFlagTaiwan: false,
            plistFlavor: Bundle.main.object(forInfoDictionaryKey: "AppFlavor") as? String,
            bundleIdentifier: Bundle.main.bundleIdentifier
        ) == .taiwan
    }

    /// Shared by `current` and tests. `compilationFlagTaiwan` mirrors `#if TAIWAN`.
    public static func resolve(
        compilationFlagTaiwan: Bool,
        plistFlavor: String?,
        bundleIdentifier: String?
    ) -> AppFlavor {
        if compilationFlagTaiwan { return .taiwan }
        if let raw = plistFlavor?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !raw.isEmpty,
           raw != "todo" {
            if raw == "taiwan" || raw == "dalaoer" { return .taiwan }
            if raw == "hongkong" || raw == "daidee" { return .hongKong }
        }
        if bundleIdentifier == "com.kenny.dalaoer" { return .taiwan }
        return .hongKong
    }

    public var isTaiwanApp: Bool { self == .taiwan }

    public var displayName: String {
        switch self {
        case .hongKong: return "鋤大D計分"
        case .taiwan: return "大老二計分"
        }
    }

    public var defaultChaoTable: ChaoTable {
        switch self {
        case .hongKong: return .hongKongDefault
        case .taiwan: return .daLaoErDefault
        }
    }

    /// 贏家通吃 is the Taiwan-app default; Hong Kong stays pairwise.
    public var defaultScoringMode: ScoringMode {
        switch self {
        case .hongKong: return .pairwise
        case .taiwan: return .winnerTakesAll
        }
    }

    public var defaultRegion: InterfaceRegion {
        switch self {
        case .hongKong: return .hongKong
        case .taiwan: return .taiwan
        }
    }

    /// Info.plist `AppStoreID`. The Taiwan app leaves this as `TODO` until Kenny
    /// creates the App Store Connect record.
    public static var appStoreID: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty || raw.uppercased() == "TODO" { return "" }
        return raw
    }

    public static var writeReviewURL: URL? {
        let id = appStoreID
        if !id.isEmpty {
            return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
        }
        if current.isTaiwanApp { return nil }
        // Hong Kong fallback when the key is missing (older Info.plist).
        return URL(string: "https://apps.apple.com/app/id6835281948?action=write-review")
    }

    /// Info.plist `RemoveAdsProductID`, with a flavor-appropriate fallback so
    /// AppCore tests (no plist) and the Hong Kong app keep `com.kenny.daidee.removeads`.
    public static var removeAdsProductID: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "RemoveAdsProductID") as? String,
           !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return id
        }
        switch current {
        case .hongKong: return "com.kenny.daidee.removeads"
        case .taiwan: return "com.kenny.dalaoer.removeads"
        }
    }
}
