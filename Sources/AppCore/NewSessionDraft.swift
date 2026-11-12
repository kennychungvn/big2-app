import Foundation
import ScoringEngine

/// Editable draft for the 新開一場 screen: names, chip fill, 炒法 tiles and validation.
public struct NewSessionDraft: Equatable, Sendable {
    public var names: [String]
    public var chaoTable: ChaoTable
    /// True when `chaoTable` came from the last session, so the screen shows 已幫你填好上次用嘅炒法.
    public var usesRememberedChao: Bool

    /// - Parameter region: Supplies the first-time 炒法 when nothing is remembered.
    public init(from settings: LastSettings = LastSettings(), region: InterfaceRegion = .hongKong) {
        self.names = settings.playerNames
        while self.names.count < ScoringEngine.playerCount {
            self.names.append("")
        }
        if self.names.count > ScoringEngine.playerCount {
            self.names = Array(self.names.prefix(ScoringEngine.playerCount))
        }
        if let remembered = settings.chaoTable {
            self.chaoTable = remembered
            self.usesRememberedChao = true
        } else {
            self.chaoTable = region.defaultChaoTable
            self.usesRememberedChao = false
        }
    }

    public var canStart: Bool {
        (try? AppModel.validatedNames(names)) != nil
    }

    public var rule: ScoringRule { chaoTable.rule }

    /// Tile tap for `cards` (8...13): ×1 → ×2 → ×3 → ×4 → ×1.
    public mutating func cycleMultiplier(cards: Int) {
        chaoTable.cycle(cards: cards)
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
