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

    /// 開場設定 炒法 tiles (×2 / ×3 / ×4); ×1 tiles use `countUnsetBackground`.
    public var chaoTile2: RGBColor = RGBColor(hex: 0xF5C542)
    public var chaoTile3: RGBColor = RGBColor(hex: 0xE38B2C)
    public var chaoTile4: RGBColor = RGBColor(hex: 0xC8372D)

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
        keyTier2: RGBColor(hex: 0x24493A),
        keyTier3: RGBColor(hex: 0x5A3E18),
        keyTier4: RGBColor(hex: 0x6B2222),
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

    public func playerColor(at index: Int) -> RGBColor {
        guard !playerColors.isEmpty else { return primary }
        return playerColors[index % playerColors.count]
    }

    public func keyColor(forMultiplier multiplier: Int) -> RGBColor {
        switch multiplier {
        case 4...: return keyTier4
        case 3: return keyTier3
        case 2: return keyTier2
        default: return keyBackground
        }
    }

    /// Background for a 炒法 tile in 開場設定: grey ×1, yellow ×2, orange ×3, red ×4.
    public func chaoTileColor(forMultiplier multiplier: Int) -> RGBColor {
        switch multiplier {
        case 4...: return chaoTile4
        case 3: return chaoTile3
        case 2: return chaoTile2
        default: return countUnsetBackground
        }
    }

    /// Text on a 炒法 tile: dark on yellow / orange, white on grey / red.
    public func chaoTileTextColor(forMultiplier multiplier: Int) -> RGBColor {
        (multiplier == 2 || multiplier == 3) ? primaryText : text
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
