import Foundation
import ScoringEngine

/// In-place state machine for the 入剩牌 screen. Animation lives in the view;
/// this only reports a `pendingBadge` the UI should spring in after an input.
///
/// Flow: a new round starts focused on player 1. Each pad press fills the focused row and
/// moves to the next empty row, in seat order. The pad's 贏 key enters 0 cards (the winner).
/// Only one winner is allowed: once someone has 贏, the key is disabled for everyone else
/// until the winner row is focused again and changed. The round auto-scores once all four
/// rows are filled and exactly one of them is the winner.
public struct RoundEntryState: Equatable, Sendable {
    /// Pad value for the 贏 key.
    public static let winnerValue = 0

    public let rule: ScoringRule
    public private(set) var cards: [Int?]
    public private(set) var focusedIndex: Int?
    /// Set after an input whose multiplier is 2 or more. The view should
    /// animate it, then call `consumePendingBadge()`.
    public private(set) var pendingBadge: ChaoBadge?
    /// Becomes `true` only on the input that makes the round complete.
    public private(set) var justCompleted: Bool

    public struct ChaoBadge: Equatable, Sendable {
        public let playerIndex: Int
        public let multiplier: Int
        public let cardsLeft: Int

        public init(playerIndex: Int, multiplier: Int, cardsLeft: Int) {
            self.playerIndex = playerIndex
            self.multiplier = multiplier
            self.cardsLeft = cardsLeft
        }
    }

    public enum Status: Equatable, Sendable {
        /// Nothing entered yet.
        case notStarted
        /// Some rows filled, round not complete yet.
        case entering
        /// Every row filled but nobody has 贏.
        case needsWinner
        case complete(cardsLeft: [Int])
    }

    private var undoStack: [Snapshot]

    private struct Snapshot: Equatable, Sendable {
        var cards: [Int?]
        var focusedIndex: Int?
    }

    /// - Parameter prefill: Cards of an existing round (edit mode). Nothing is focused until
    ///   the user taps a row. Without a prefill the new round starts focused on player 1.
    public init(rule: ScoringRule = .hongKongDefault, prefill: [Int]? = nil) {
        self.rule = rule
        self.pendingBadge = nil
        self.justCompleted = false
        self.undoStack = []
        if let prefill, prefill.count == ScoringEngine.playerCount {
            self.cards = prefill.map { Optional($0) }
            self.focusedIndex = nil
        } else {
            self.cards = Array(repeating: nil, count: ScoringEngine.playerCount)
            self.focusedIndex = 0
        }
    }

    public var playerCount: Int { ScoringEngine.playerCount }

    public var winnerIndex: Int? {
        cards.firstIndex(of: Self.winnerValue)
    }

    /// The pad accepts input whenever a row is focused.
    public var isPadEnabled: Bool {
        focusedIndex != nil
    }

    /// 贏 is available for the focused row unless someone else already has it.
    public var canEnterWinner: Bool {
        guard let focusedIndex else { return false }
        guard let winnerIndex else { return true }
        return winnerIndex == focusedIndex
    }

    public var canUndo: Bool { !undoStack.isEmpty }

    /// All four rows, when filled with exactly one winner.
    public var completeCards: [Int]? {
        guard cards.allSatisfy({ $0 != nil }) else { return nil }
        let values = cards.map { $0! }
        guard values.filter({ $0 == Self.winnerValue }).count == 1 else { return nil }
        return values
    }

    public var isComplete: Bool { completeCards != nil }

    public var status: Status {
        if let complete = completeCards { return .complete(cardsLeft: complete) }
        if cards.allSatisfy({ $0 == nil }) { return .notStarted }
        if cards.allSatisfy({ $0 != nil }) { return .needsWinner }
        return .entering
    }

    /// Hong Kong wording, kept for existing callers.
    public var hintText: String { hintText(in: .hongKong) }

    public func hintText(in region: InterfaceRegion) -> String {
        let taiwan = region == .taiwan
        switch status {
        case .notStarted, .needsWinner:
            return taiwan ? "依序輸入剩幾張，先出完的點「贏」" : "逐個入剩幾多張，出清牌嘅㩒「贏」"
        case .entering:
            return taiwan ? "輸入後會自動跳到下一位，點任一列可修改" : "入完自動跳下一個，㩒邊行都改得"
        case .complete:
            return taiwan ? "輸入完成，正在記分…" : "入完喇，計緊分…"
        }
    }

    /// 「{name} 剩幾多張？」 for the focused row.
    public func padPrompt(playerNames: [String], region: InterfaceRegion = .hongKong) -> String {
        let taiwan = region == .taiwan
        if let focusedIndex, focusedIndex < playerNames.count {
            return taiwan ? "\(playerNames[focusedIndex]) 剩幾張？" : "\(playerNames[focusedIndex]) 剩幾多張？"
        }
        return taiwan ? "剩幾張？" : "剩幾多張？"
    }

    public func multiplier(forCardsLeft cardsLeft: Int) -> Int? {
        guard cardsLeft >= ScoringEngine.minLoserCards else { return nil }
        return try? rule.multiplier(forCardsLeft: cardsLeft)
    }

    /// The pad's 贏 key: the focused player went out first.
    public mutating func enterWinner() {
        enterCards(Self.winnerValue)
    }

    /// Fills the focused row with `count` (0 = 贏, 1...13 leftover cards) and moves focus to
    /// the next empty row in seat order. 贏 is ignored while another row is the winner.
    public mutating func enterCards(_ count: Int) {
        guard let focus = focusedIndex, cards.indices.contains(focus) else { return }
        let isWinner = count == Self.winnerValue
        if isWinner {
            guard canEnterWinner else { return }
        } else {
            guard (ScoringEngine.minLoserCards...ScoringEngine.maxLoserCards).contains(count) else { return }
        }
        justCompleted = false
        pushUndo()
        cards[focus] = count
        if !isWinner, let multiplier = multiplier(forCardsLeft: count), multiplier >= 2 {
            pendingBadge = ChaoBadge(
                playerIndex: focus,
                multiplier: multiplier,
                cardsLeft: count
            )
        } else {
            pendingBadge = nil
        }
        if completeCards != nil {
            justCompleted = true
            focusedIndex = nil
        } else {
            focusedIndex = nextUnset(after: focus) ?? focus
        }
    }

    /// Tapping a row focuses it so its value can be changed.
    public mutating func selectPlayer(_ index: Int) {
        guard cards.indices.contains(index) else { return }
        justCompleted = false
        focusedIndex = index
    }

    /// The pad's ↶ key: reverts the last input. To change a row, tap it and enter again.
    public mutating func undo() {
        justCompleted = false
        pendingBadge = nil
        guard let snapshot = undoStack.popLast() else { return }
        cards = snapshot.cards
        focusedIndex = snapshot.focusedIndex
    }

    public mutating func consumePendingBadge() -> ChaoBadge? {
        let badge = pendingBadge
        pendingBadge = nil
        return badge
    }

    private mutating func pushUndo() {
        undoStack.append(Snapshot(cards: cards, focusedIndex: focusedIndex))
    }

    private func nextUnset(after index: Int) -> Int? {
        let count = playerCount
        for offset in 1...count {
            let candidate = (index + offset) % count
            if cards[candidate] == nil { return candidate }
        }
        return nil
    }
}
