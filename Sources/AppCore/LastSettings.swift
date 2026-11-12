import Foundation

/// Remembered 開場設定 so the next session is mostly one tap.
///
/// Older builds also stored `pointValue` (每分幾錢). That feature is removed; the key is
/// ignored when decoding old files.
public struct LastSettings: Codable, Equatable, Sendable {
    public var playerNames: [String]
    public var rulePreset: RulePreset

    public init(
        playerNames: [String] = ["", "", "", ""],
        rulePreset: RulePreset = .hongKongDefault
    ) {
        self.playerNames = Self.padded(playerNames)
        self.rulePreset = rulePreset
    }

    private static func padded(_ names: [String]) -> [String] {
        var result = names
        while result.count < 4 { result.append("") }
        if result.count > 4 { result = Array(result.prefix(4)) }
        return result
    }
}
