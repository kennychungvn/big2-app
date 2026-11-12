import Foundation
import ScoringEngine

/// In-place state machine for the 入剩牌 screen. Animation lives in the view;
/// this only reports a `pendingBadge` the UI should spring in after an input.
public struct RoundEntryState: Equatable, Sendable {
    public let rule: ScoringRule
    public private(set) var cards: [Int?]
    public private(set) var focusedIndex: Int?
    /// Set after a loser input whose multiplier is 2 or more. The view should
    /// animate it, then call `consumePendingBadge()`.
    public private(set) var pendingBadge: ChaoBadge?
    /// Becomes `true` only on the transition that fills the last empty seat.
    public private(set) var justCompleted: Bool

    public struct ChaoBadge: Equatable, Sendable {
        public let playerIndex: Int
        public let multiplier: Int
        public let cardsLeft: Int
    }

    public enum Status: Equatable, Sendable {
        case pickingWinner
        case enteringLosers
        case complete(cardsLeft: [Int])
    }

    private var undoStack: [Snapshot]

    private struct Snapshot: Equatable, Sendable {
        var cards: [Int?]
        var focusedIndex: Int?
    }

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
            self.focusedIndex = nil
        }
    }

    public var playerCount: Int { ScoringEngine.playerCount }

    public var winnerIndex: Int? {
        cards.firstIndex(of: 0)
    }

    public var isPadEnabled: Bool {
        winnerIndex != nil && focusedIndex != nil && cards[focusedIndex!] != 0
    }

    public var canUndo: Bool { !undoStack.isEmpty }

    public var completeCards: [Int]? {
        guard cards.allSatisfy({ $0 != nil }), cards.contains(0) else { return nil }
        return cards.map { $0! }
    }

    public var isComplete: Bool { completeCards != nil }

    public var status: Status {
        if let complete = completeCards { return .complete(cardsLeft: complete) }
        if winnerIndex == nil { return .pickingWinner }
        return .enteringLosers
    }

    /// Hong Kong wording, kept for existing callers.
    public var hintText: String { hintText(in: .hongKong) }

    public func hintText(in region: InterfaceRegion) -> String {
        let taiwan = region == .taiwan
        switch status {
        case .pickingWinner:
            return taiwan ? "點「贏」選出誰先出完牌" : "㩒「贏」揀邊個出清牌"
        case .enteringLosers:
            return taiwan ? "選完會自動跳到下一位，點任何一列都可以修改" : "揀完一個自動跳下一個，㩒任何一行可以改"
        case .complete:
            return taiwan ? "輸入完成，正在記分…" : "入完喇，計緊分…"
        }
    }

    public func padPrompt(playerNames: [String], region: InterfaceRegion = .hongKong) -> String {
        let taiwan = region == .taiwan
        if winnerIndex == nil { return taiwan ? "先選贏家" : "先揀贏家" }
        if let focusedIndex, focusedIndex < playerNames.count, cards[focusedIndex] != 0 {
            return taiwan ? "\(playerNames[focusedIndex]) 剩幾張？" : "\(playerNames[focusedIndex]) 剩幾多張？"
        }
        return taiwan ? "剩幾張？" : "剩幾多張？"
    }

    public func multiplier(forCardsLeft cardsLeft: Int) -> Int? {
        guard cardsLeft >= ScoringEngine.minLoserCards else { return nil }
        return try? rule.multiplier(forCardsLeft: cardsLeft)
    }

    /// Marks `index` as the winner (0 cards). A previous winner is cleared.
    /// Tapping the current winner again unsets them. Focus jumps to the next empty loser.
    public mutating func markWinner(_ index: Int) {
        guard cards.indices.contains(index) else { return }
        justCompleted = false
        pendingBadge = nil
        pushUndo()
        if winnerIndex == index {
            cards[index] = nil
            focusedIndex = firstUnset()
            return
        }
        if let old = winnerIndex {
            cards[old] = nil
        }
        cards[index] = 0
        focusedIndex = nextUnset(after: index)
        markCompletedIfNeeded()
    }

    /// Enters 1...13 leftover cards for the focused loser and advances focus.
    public mutating func enterCards(_ count: Int) {
        guard let focus = focusedIndex, cards.indices.contains(focus) else { return }
        guard winnerIndex != nil, cards[focus] != 0 else { return }
        guard (ScoringEngine.minLoserCards...ScoringEngine.maxLoserCards).contains(count) else { return }
        justCompleted = false
        pushUndo()
        cards[focus] = count
        if let multiplier = multiplier(forCardsLeft: count), multiplier >= 2 {
            pendingBadge = ChaoBadge(playerIndex: focus, multiplier: multiplier, cardsLeft: count)
        } else {
            pendingBadge = nil
        }
        if completeCards == nil {
            focusedIndex = nextUnset(after: focus) ?? focus
        }
        markCompletedIfNeeded()
    }

    /// Lets the user tap a row to edit it. The winner row can be focused but the pad stays off.
    public mutating func selectPlayer(_ index: Int) {
        guard cards.indices.contains(index) else { return }
        justCompleted = false
        focusedIndex = index
    }

    /// Reverts the last `markWinner` / `enterCards` / `clear` mutation.
    public mutating func undo() {
        justCompleted = false
        pendingBadge = nil
        guard let snapshot = undoStack.popLast() else { return }
        cards = snapshot.cards
        focusedIndex = snapshot.focusedIndex
    }

    /// Clears the focused row. If nothing is focused, clears the whole pad.
    public mutating func clearFocusedOrAll() {
        justCompleted = false
        pendingBadge = nil
        if let focus = focusedIndex, cards[focus] != nil {
            pushUndo()
            cards[focus] = nil
            if winnerIndex == nil {
                focusedIndex = nil
            }
            return
        }
        clearAll()
    }

    /// Resets every seat and returns to 「先揀贏家」.
    public mutating func clearAll() {
        justCompleted = false
        pendingBadge = nil
        guard cards.contains(where: { $0 != nil }) || focusedIndex != nil else { return }
        pushUndo()
        cards = Array(repeating: nil, count: playerCount)
        focusedIndex = nil
    }

    public mutating func consumePendingBadge() -> ChaoBadge? {
        let badge = pendingBadge
        pendingBadge = nil
        return badge
    }

    private mutating func markCompletedIfNeeded() {
        if completeCards != nil {
            justCompleted = true
            focusedIndex = nil
        }
    }

    private mutating func pushUndo() {
        undoStack.append(Snapshot(cards: cards, focusedIndex: focusedIndex))
    }

    private func firstUnset() -> Int? {
        cards.firstIndex(where: { $0 == nil })
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
