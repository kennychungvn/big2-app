import Foundation

/// Remembered 開場設定 so the next session is mostly one tap.
public struct LastSettings: Codable, Equatable, Sendable {
    public var playerNames: [String]
    public var rulePreset: RulePreset
    public var pointValue: Decimal?

    public init(
        playerNames: [String] = ["", "", "", ""],
        rulePreset: RulePreset = .hongKongDefault,
        pointValue: Decimal? = nil
    ) {
        self.playerNames = Self.padded(playerNames)
        self.rulePreset = rulePreset
        self.pointValue = pointValue
    }

    public var pointValueOption: PointValueOption {
        PointValueOption(decimal: pointValue)
    }

    private static func padded(_ names: [String]) -> [String] {
        var result = names
        while result.count < 4 { result.append("") }
        if result.count > 4 { result = Array(result.prefix(4)) }
        return result
    }
}
