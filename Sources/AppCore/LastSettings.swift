import Foundation

/// Remembered 開場設定 so the next session is mostly one tap.
///
/// Older builds stored `rulePreset` (a fixed table name) instead of `chaoTable`; it is
/// migrated to the same multipliers when decoding. They also stored `pointValue` (每分幾錢),
/// which is ignored.
public struct LastSettings: Codable, Equatable, Sendable {
    public var playerNames: [String]
    /// Last-used 炒法, or `nil` if the player has never started a session.
    public var chaoTable: ChaoTable?

    public init(
        playerNames: [String] = ["", "", "", ""],
        chaoTable: ChaoTable? = nil
    ) {
        self.playerNames = Self.padded(playerNames)
        self.chaoTable = chaoTable
    }

    private enum CodingKeys: String, CodingKey {
        case playerNames
        case chaoTable
        case rulePreset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let names = try container.decodeIfPresent([String].self, forKey: .playerNames) ?? []
        var table = try container.decodeIfPresent(ChaoTable.self, forKey: .chaoTable)
        if table == nil, let raw = try? container.decodeIfPresent(String.self, forKey: .rulePreset),
           let legacy = RulePreset(rawValue: raw) {
            table = legacy.chaoTable
        }
        self.init(playerNames: names, chaoTable: table)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(playerNames, forKey: .playerNames)
        try container.encodeIfPresent(chaoTable, forKey: .chaoTable)
    }

    private static func padded(_ names: [String]) -> [String] {
        var result = names
        while result.count < 4 { result.append("") }
        if result.count > 4 { result = Array(result.prefix(4)) }
        return result
    }
}
