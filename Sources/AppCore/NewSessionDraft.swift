import Foundation
import ScoringEngine

/// Editable draft for the 新開一場 screen, including chip fill and validation.
public struct NewSessionDraft: Equatable, Sendable {
    public var names: [String]
    public var preset: RulePreset

    /// - Parameter region: The preset is mapped to one listed for this region
    ///   (`classic` ↔ `taiwanCommon`), so the picker always has a selection.
    public init(from settings: LastSettings = LastSettings(), region: InterfaceRegion = .hongKong) {
        self.names = settings.playerNames
        while self.names.count < ScoringEngine.playerCount {
            self.names.append("")
        }
        if self.names.count > ScoringEngine.playerCount {
            self.names = Array(self.names.prefix(ScoringEngine.playerCount))
        }
        self.preset = settings.rulePreset.equivalent(in: region)
    }

    public var canStart: Bool {
        (try? AppModel.validatedNames(names)) != nil
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
}
