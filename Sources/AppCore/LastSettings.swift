import Foundation
import ScoringEngine

/// Remembered 開場設定 so the next session is mostly one tap.
///
/// Older builds stored `rulePreset` (a fixed table name) instead of `chaoTable`; it is
/// migrated to the same multipliers when decoding. They also stored `pointValue` (每分幾錢),
/// which is ignored.
public struct LastSettings: Codable, Equatable, Sendable {
    public var playerNames: [String]
    /// Last-used 炒法, or `nil` if the player has never started a session.
    public var chaoTable: ChaoTable?
    /// Last-used settlement (贏家通吃 / 互對). `nil` in older saves; the Taiwan app
    /// falls back to 贏家通吃. The Hong Kong app ignores this and stays pairwise.
    public var scoringMode: ScoringMode?

    public init(
        playerNames: [String] = ["", "", "", ""],
        chaoTable: ChaoTable? = nil,
        scoringMode: ScoringMode? = nil
    ) {
        self.playerNames = Self.padded(playerNames)
        self.chaoTable = chaoTable
        self.scoringMode = scoringMode
    }

    private enum CodingKeys: String, CodingKey {
        case playerNames
        case chaoTable
        case rulePreset
        case scoringMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let names = try container.decodeIfPresent([String].self, forKey: .playerNames) ?? []
        var table = try container.decodeIfPresent(ChaoTable.self, forKey: .chaoTable)
        if table == nil, let raw = try? container.decodeIfPresent(String.self, forKey: .rulePreset),
           let legacy = RulePreset(rawValue: raw) {
            table = legacy.chaoTable
        }
        let mode = try container.decodeIfPresent(ScoringMode.self, forKey: .scoringMode)
        self.init(playerNames: names, chaoTable: table, scoringMode: mode)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(playerNames, forKey: .playerNames)
        try container.encodeIfPresent(chaoTable, forKey: .chaoTable)
        try container.encodeIfPresent(scoringMode, forKey: .scoringMode)
    }

    private static func padded(_ names: [String]) -> [String] {
        var result = names
        while result.count < 4 { result.append("") }
        if result.count > 4 { result = Array(result.prefix(4)) }
        return result
    }
}
