import Foundation
import ScoringEngine

/// Editable draft for the 新開一場 screen, including chip fill and validation.
public struct NewSessionDraft: Equatable, Sendable {
    public var names: [String]
    public var preset: RulePreset
    public var pointValue: PointValueOption
    public var customAmountText: String

    public init(from settings: LastSettings = LastSettings()) {
        self.names = settings.playerNames
        while self.names.count < ScoringEngine.playerCount {
            self.names.append("")
        }
        if self.names.count > ScoringEngine.playerCount {
            self.names = Array(self.names.prefix(ScoringEngine.playerCount))
        }
        self.preset = settings.rulePreset
        self.pointValue = settings.pointValueOption
        if case .custom(let value) = self.pointValue {
            self.customAmountText = NSDecimalNumber(decimal: value).stringValue
        } else {
            self.customAmountText = ""
        }
    }

    public var canStart: Bool {
        (try? AppModel.validatedNames(names)) != nil && resolvedPointValueError == nil
    }

    public var resolvedPointValue: Decimal? {
        switch pointValue {
        case .none, .one, .two, .five:
            return pointValue.decimalValue
        case .custom:
            return Self.parseCustomAmount(customAmountText)
        }
    }

    public var resolvedPointValueError: AppModelError? {
        if case .custom = pointValue {
            guard let value = Self.parseCustomAmount(customAmountText), value > 0 else {
                return .invalidCustomPointValue
            }
        }
        return nil
    }

    /// Fills the first empty name field with a known-player chip. Returns `false` if every field is full.
    @discardableResult
    public mutating func applyChip(_ name: String) -> Bool {
        if let index = names.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            names[index] = name
            return true
        }
        return false
    }

    public static func parseCustomAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }
}
