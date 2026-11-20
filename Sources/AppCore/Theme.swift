import Foundation

/// Visual tokens for one skin. Only 街坊 (Neighbourhood) is implemented now;
/// 至尊 / 冠軍 can be added later without changing screen code.
public struct Theme: Equatable, Sendable {
    public var id: String
    public var chineseName: String
    public var englishName: String

    public var background: RGBColor
    public var elevatedBackground: RGBColor
    public var card: RGBColor
    public var cardElevated: RGBColor
    public var padBackground: RGBColor
    public var keyBackground: RGBColor
    public var keyUtilityBackground: RGBColor
    public var countUnsetBackground: RGBColor
    public var countSetBackground: RGBColor
    public var historyRow: RGBColor
    public var toastBackground: RGBColor

    public var primary: RGBColor
    public var primaryText: RGBColor
    public var text: RGBColor
    public var secondaryText: RGBColor
    public var tertiaryText: RGBColor
    public var accentLink: RGBColor
    public var positive: RGBColor
    public var negative: RGBColor
    public var winButtonBorder: RGBColor

    public var playerColors: [RGBColor]

    public var keyTier2: RGBColor
    public var keyTier3: RGBColor
    public var keyTier4: RGBColor
    public var badgeTier2: RGBColor
    public var badgeTier3: RGBColor
    public var badgeTier4: RGBColor

    public var bannerPlaceholder: RGBColor
    public var bannerPlaceholderText: RGBColor

    /// Player / result cards.
    public var cardCornerRadius: Double
    /// Number-pad keys and mid-size chips.
    public var keyCornerRadius: Double
    /// Primary call-to-action buttons.
    public var buttonCornerRadius: Double
    public var textFieldCornerRadius: Double

    public var titleFontName: String?
    public var bodyFontName: String?
    public var usesSmallCapsButtons: Bool

    // MARK: 2.0 dual-skin tokens (design2/dual-skin/tokens.md)
    public var skin: SkinID = .classic
    public var isDark: Bool = true
    /// Secondary fill: count box, segmented track, secondary button.
    public var surface2: RGBColor = RGBColor(hex: 0x363B48)
    /// Divider / card border (only drawn when `cardBorderWidth > 0`).
    public var line: RGBColor = RGBColor(hex: 0x343844)
    /// Highlight text / stroke (winner, ×2 chips, caret).
    public var hi: RGBColor = RGBColor(hex: 0xF5C542)
    /// Highlight tint (winner badge, ×2 chip background).
    public var hiSoft: RGBColor = RGBColor(hex: 0x4A3F1E)
    /// Selected row / key stroke.
    public var sel: RGBColor = RGBColor(hex: 0xF5C542)
    public var keyText: RGBColor = RGBColor(hex: 0xFFFFFF)
    public var toggle: RGBColor = RGBColor(hex: 0x30D158)
    /// Ad banner band background.
    public var adband: RGBColor = RGBColor(hex: 0x16181D)
    /// Text on the ×2 / ×3 炒 key tiers.
    public var tierText: RGBColor = RGBColor(hex: 0x1E2128)
    /// 0 = no border (Classic), 1 = 1pt `line` (Ledger).
    public var cardBorderWidth: Double = 0
    /// Classic: SF Pro + monospaced digits. Ledger: SF Mono.
    public var monoNumbers: Bool = false
    /// Player marker: Classic capsule 5×24, Ledger 9pt square.
    public var squareMarker: Bool = false

    /// The default 街坊 skin: dark grey, yellow primary, rounded 14–16 pt.
    public static let neighbourhood = Theme(
        id: "neighbourhood",
        chineseName: "街坊",
        englishName: "Neighbourhood",
        background: RGBColor(hex: 0x1E2128),
        elevatedBackground: RGBColor(hex: 0x181A20),
        card: RGBColor(hex: 0x2A2E37),
        cardElevated: RGBColor(hex: 0x323745),
        padBackground: RGBColor(hex: 0x181A20),
        keyBackground: RGBColor(hex: 0x343946),
        keyUtilityBackground: RGBColor(hex: 0x2A2E37),
        countUnsetBackground: RGBColor(hex: 0x3A3F4B),
        countSetBackground: RGBColor(hex: 0x4A5060),
        historyRow: RGBColor(hex: 0x252830),
        toastBackground: RGBColor(hex: 0x2D3A55),
        primary: RGBColor(hex: 0xF5C542),
        primaryText: RGBColor(hex: 0x222222),
        text: RGBColor(hex: 0xFFFFFF),
        secondaryText: RGBColor(hex: 0x99AAAA),
        tertiaryText: RGBColor(hex: 0x666666),
        accentLink: RGBColor(hex: 0x8AB4FF),
        positive: RGBColor(hex: 0x4CD07D),
        negative: RGBColor(hex: 0xFF6B6B),
        winButtonBorder: RGBColor(hex: 0x555555),
        playerColors: [
            RGBColor(hex: 0x4A8CFF),
            RGBColor(hex: 0xFF5A5A),
            RGBColor(hex: 0x3CCF7A),
            RGBColor(hex: 0xFFA53C)
        ],
        keyTier2: RGBColor(hex: 0xF5C542),
        keyTier3: RGBColor(hex: 0xE38B2C),
        keyTier4: RGBColor(hex: 0xC8372D),
        badgeTier2: RGBColor(hex: 0x2F6D4A),
        badgeTier3: RGBColor(hex: 0x8A5A1A),
        badgeTier4: RGBColor(hex: 0x9B2C2C),
        bannerPlaceholder: RGBColor(hex: 0xD9DCE2),
        bannerPlaceholderText: RGBColor(hex: 0x555555),
        cardCornerRadius: 16,
        keyCornerRadius: 14,
        buttonCornerRadius: 22,
        textFieldCornerRadius: 14,
        titleFontName: nil,
        bodyFontName: nil,
        usesSmallCapsButtons: false
    )

    public static let current = Theme.neighbourhood

    /// 2.0 skins. One layout; views read tokens only.
    public static func make(skin: SkinID, dark: Bool) -> Theme {
        var t = Theme.neighbourhood
        t.skin = skin
        t.isDark = dark
        t.id = skin.rawValue
        t.chineseName = skin.displayName
        t.englishName = skin.displayName
        let p = Palette.of(skin: skin, dark: dark)
        t.background = p.bg
        t.elevatedBackground = p.adband
        t.card = p.surface
        t.cardElevated = p.surface
        t.padBackground = p.bg
        t.keyBackground = p.key
        t.keyUtilityBackground = p.surface2
        t.countUnsetBackground = p.surface2
        t.countSetBackground = p.surface2
        t.historyRow = p.surface
        t.toastBackground = p.surface2
        t.primary = p.accent
        t.primaryText = p.onAccent
        t.text = p.text
        t.secondaryText = p.text2
        t.tertiaryText = p.text3
        t.accentLink = p.link
        t.positive = p.pos
        t.negative = p.neg
        t.winButtonBorder = p.line
        t.playerColors = [p.p1, p.p2, p.p3, p.p4]
        t.bannerPlaceholder = p.surface2
        t.bannerPlaceholderText = p.text3
        t.surface2 = p.surface2
        t.line = p.line
        t.hi = p.hi
        t.hiSoft = p.hiSoft
        t.sel = p.sel
        t.keyText = p.keyText
        t.toggle = p.toggle
        t.adband = p.adband
        switch skin {
        case .classic:
            t.keyTier2 = RGBColor(hex: 0xF5C542)
            t.keyTier3 = RGBColor(hex: 0xE38B2C)
            t.keyTier4 = RGBColor(hex: 0xC8372D)
            t.badgeTier2 = dark ? RGBColor(hex: 0x2F6D4A) : RGBColor(hex: 0x0B7A43)
            t.badgeTier3 = dark ? RGBColor(hex: 0x8A5A1A) : RGBColor(hex: 0xB86E12)
            t.badgeTier4 = dark ? RGBColor(hex: 0x9B2C2C) : RGBColor(hex: 0xD13438)
            t.tierText = RGBColor(hex: 0x1E2128)
            t.cardCornerRadius = 16
            t.buttonCornerRadius = 18
            t.keyCornerRadius = 12
            t.textFieldCornerRadius = 12
            t.cardBorderWidth = 0
            t.monoNumbers = false
            t.squareMarker = false
        case .ledger:
            t.keyTier2 = p.accent
            t.keyTier3 = dark ? RGBColor(hex: 0xE08A2E) : RGBColor(hex: 0xC56A12)
            t.keyTier4 = p.neg
            t.badgeTier2 = p.accent
            t.badgeTier3 = dark ? RGBColor(hex: 0xA8641C) : RGBColor(hex: 0xC56A12)
            t.badgeTier4 = dark ? RGBColor(hex: 0xC9363B) : RGBColor(hex: 0xC9363B)
            t.tierText = RGBColor(hex: 0xFFFFFF)
            t.cardCornerRadius = 10
            t.buttonCornerRadius = 10
            t.keyCornerRadius = 8
            t.textFieldCornerRadius = 8
            t.cardBorderWidth = 1
            t.monoNumbers = true
            t.squareMarker = true
        }
        return t
    }

    public func playerColor(at index: Int) -> RGBColor {
        guard !playerColors.isEmpty else { return primary }
        return playerColors[index % playerColors.count]
    }

    /// Shared 炒倍 colour for the 入剩牌 number pad keys and the 開場設定 炒法 tiles:
    /// grey ×1, yellow ×2, orange ×3, red ×4.
    public func keyColor(forMultiplier multiplier: Int) -> RGBColor {
        switch multiplier {
        case 4...: return keyTier4
        case 3: return keyTier3
        case 2: return keyTier2
        default: return keyBackground
        }
    }

    /// Text on a `keyColor` background: dark on yellow / orange, white on grey / red.
    public func keyTextColor(forMultiplier multiplier: Int) -> RGBColor {
        switch multiplier {
        case 4...: return RGBColor(hex: 0xFFFFFF)
        case 2, 3: return tierText
        default: return keyText
        }
    }

    public func badgeColor(forMultiplier multiplier: Int) -> RGBColor {
        switch multiplier {
        case 4...: return badgeTier4
        case 3: return badgeTier3
        case 2: return badgeTier2
        default: return countSetBackground
        }
    }
}

/// 2.0 skin id, persisted under `skin`.
public enum SkinID: String, CaseIterable, Sendable, Identifiable {
    case classic
    case ledger

    public var id: String { rawValue }
    /// Temporary name for the second skin until release (Kenny, 2026-11-20).
    public static let ledgerName = "Ledger"

    public var displayName: String {
        switch self {
        case .classic: return "經典"
        case .ledger: return SkinID.ledgerName
        }
    }

    /// Alternate icon name for `setAlternateIconName` (nil = primary `AppIcon`).
    public var alternateIconName: String? {
        switch self {
        case .classic: return nil
        case .ledger: return "AppIcon-Ledger"
        }
    }

    public var iconPreviewName: String {
        switch self {
        case .classic: return "IconPreview-Classic"
        case .ledger: return "IconPreview-Ledger"
        }
    }

    public static func fromAlternateIconName(_ name: String?) -> SkinID {
        name == SkinID.ledger.alternateIconName ? .ledger : .classic
    }
}

/// 外觀: 跟系統 / 淺色 / 深色, persisted under `appearance`.
public enum AppearancePreference: String, CaseIterable, Sendable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

/// Raw colour table from tokens.md (four palettes).
struct Palette {
    var bg, surface, surface2, line, text, text2, text3, accent, onAccent, hi, hiSoft, link, sel, key, keyText, pos, neg, toggle, adband, p1, p2, p3, p4: RGBColor

    static func of(skin: SkinID, dark: Bool) -> Palette {
        func c(_ hex: UInt32) -> RGBColor { RGBColor(hex: hex) }
        switch (skin, dark) {
        case (.classic, false):
            return Palette(bg: c(0xF2F3F6), surface: c(0xFFFFFF), surface2: c(0xE7E9EE), line: c(0xE1E3E8),
                           text: c(0x1E2128), text2: c(0x5F6573), text3: c(0x9AA0AC), accent: c(0xF5C542),
                           onAccent: c(0x1E2128), hi: c(0xD9A520), hiSoft: c(0xFBEFC8), link: c(0x1F5FCC),
                           sel: c(0x1E2128), key: c(0xFFFFFF), keyText: c(0x1E2128), pos: c(0x0B7A43),
                           neg: c(0xD13438), toggle: c(0x30D158), adband: c(0xE7E9EE),
                           p1: c(0x3B78E7), p2: c(0xE5484D), p3: c(0x22A447), p4: c(0xF08C1A))
        case (.classic, true):
            return Palette(bg: c(0x1E2128), surface: c(0x2A2E37), surface2: c(0x363B48), line: c(0x343844),
                           text: c(0xFFFFFF), text2: c(0xA3A9B6), text3: c(0x6B7180), accent: c(0xF5C542),
                           onAccent: c(0x1E2128), hi: c(0xF5C542), hiSoft: c(0x4A3F1E), link: c(0x8AB4FF),
                           sel: c(0xF5C542), key: c(0x363B48), keyText: c(0xFFFFFF), pos: c(0x3DD68C),
                           neg: c(0xFF6363), toggle: c(0x30D158), adband: c(0x16181D),
                           p1: c(0x4F8CF7), p2: c(0xFF5A5F), p3: c(0x34C759), p4: c(0xFFA53B))
        case (.ledger, false):
            return Palette(bg: c(0xFFFFFF), surface: c(0xF4F5F7), surface2: c(0xE9EBEF), line: c(0xE4E6EB),
                           text: c(0x0A0A0A), text2: c(0x5C6270), text3: c(0x9CA1AB), accent: c(0x2F5BFF),
                           onAccent: c(0xFFFFFF), hi: c(0x2F5BFF), hiSoft: c(0xE6ECFF), link: c(0x2F5BFF),
                           sel: c(0x0A0A0A), key: c(0xF4F5F7), keyText: c(0x0A0A0A), pos: c(0x007A4D),
                           neg: c(0xC9363B), toggle: c(0x2F5BFF), adband: c(0xF4F5F7),
                           p1: c(0x2F5BFF), p2: c(0xE5484D), p3: c(0x00A86B), p4: c(0xF5A524))
        case (.ledger, true):
            return Palette(bg: c(0x000000), surface: c(0x111214), surface2: c(0x1C1D21), line: c(0x24262B),
                           text: c(0xF5F6F7), text2: c(0x9CA1AB), text3: c(0x5C6270), accent: c(0x5B7CFF),
                           onAccent: c(0xFFFFFF), hi: c(0x5B7CFF), hiSoft: c(0x141C3A), link: c(0x5B7CFF),
                           sel: c(0xF5F6F7), key: c(0x1C1D21), keyText: c(0xF5F6F7), pos: c(0x2BD48F),
                           neg: c(0xFF5C61), toggle: c(0x5B7CFF), adband: c(0x0B0C0E),
                           p1: c(0x5B7CFF), p2: c(0xFF5C61), p3: c(0x2BD48F), p4: c(0xFFB547))
        }
    }
}
