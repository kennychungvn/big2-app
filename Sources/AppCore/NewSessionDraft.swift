import Foundation
import ScoringEngine

/// Editable draft for the 新開一場 screen: names, chip fill, 炒法 tiles and validation.
public struct NewSessionDraft: Equatable, Sendable {
    public static let emptyNames = Array(repeating: "", count: ScoringEngine.playerCount)

    public var names: [String]
    public var chaoTable: ChaoTable
    /// True when `chaoTable` came from the last session, so the screen shows 已幫你填好上次用嘅炒法.
    public var usesRememberedChao: Bool
    /// 計分方式 for the Taiwan-only app (贏家通吃 default, or 互對). Ignored by the Hong Kong app.
    public var scoringMode: ScoringMode

    /// - Parameter region: Supplies the first-time 炒法 when nothing is remembered.
    /// - Parameter sessions: Used only when `lastSettings` has no names, to prefill from the most recent game.
    public init(
        from settings: LastSettings = LastSettings(),
        region: InterfaceRegion = .hongKong,
        sessions: [StoredSession] = []
    ) {
        self.names = Self.prefilledPlayerNames(lastSettings: settings, sessions: sessions)
        if let remembered = settings.chaoTable {
            self.chaoTable = remembered
            self.usesRememberedChao = true
        } else {
            // Taiwan-only app uses 8–9 ×2 / 10–12 ×3 / 13 ×4, not InterfaceRegion.taiwan's
            // milder 台灣常見 table (that table stays for the HK app's optional TW toggle).
            self.chaoTable = AppFlavor.current.isTaiwanApp ? AppFlavor.current.defaultChaoTable : region.defaultChaoTable
            self.usesRememberedChao = false
        }
        if AppFlavor.current.isTaiwanApp {
            self.scoringMode = settings.scoringMode ?? AppFlavor.current.defaultScoringMode
        } else {
            self.scoringMode = region.defaultScoringMode
        }
    }

    /// Names from the most recent game, in seat order. If there is no previous game, empty fields
    /// (the existing first-time defaults, shown with「玩家 1」… placeholders).
    ///
    /// Prefer persisted `LastSettings.playerNames` (written when a session starts). If that is
    /// still empty but a session exists (older data), fall back to the most recently updated game.
    public static func prefilledPlayerNames(
        lastSettings: LastSettings,
        sessions: [StoredSession] = []
    ) -> [String] {
        let remembered = padded(lastSettings.playerNames)
        if remembered.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return remembered
        }
        if let latest = sessions.max(by: { $0.updatedAt < $1.updatedAt }) {
            return padded(latest.session.players)
        }
        return emptyNames
    }

    public var canStart: Bool {
        (try? AppModel.validatedNames(names)) != nil
    }

    public var hasAnyName: Bool {
        names.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public var rule: ScoringRule { chaoTable.rule }

    /// Tile tap for `cards` (8...13): ×1 → ×2 → ×3 → ×4 → ×1.
    public mutating func cycleMultiplier(cards: Int) {
        chaoTable.cycle(cards: cards)
    }

    public mutating func clearAllNames() {
        names = Self.emptyNames
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

    private static func padded(_ names: [String]) -> [String] {
        var result = names
        while result.count < ScoringEngine.playerCount { result.append("") }
        if result.count > ScoringEngine.playerCount {
            result = Array(result.prefix(ScoringEngine.playerCount))
        }
        return result
    }
}
