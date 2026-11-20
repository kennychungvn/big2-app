import Foundation
import ScoringEngine

/// Compile-time product flavor. The Hong Kong target (`Big2`, 鋤大D計分) and the
/// Taiwan-only target (`DaLaoEr`, 大老二計分) share AppCore and the views; this
/// switch (or `SWIFT_ACTIVE_COMPILATION_CONDITIONS = TAIWAN`) is what diverges
/// rules, copy, ads and IAP. The Hong Kong target never defines `TAIWAN`.
public enum AppFlavor: String, Equatable, Sendable {
    case hongKong
    case taiwan

    public static var current: AppFlavor {
        #if TAIWAN
        return .taiwan
        #else
        return .hongKong
        #endif
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
