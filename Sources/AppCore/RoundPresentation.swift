import Foundation
import ScoringEngine

/// Maps a scored `Round` into the bits the result / history screens display.
public enum RoundPresentation: Sendable {
    public static func displays(from round: Round) -> [RoundScoreDisplay] {
        round.scores.map { score in
            RoundScoreDisplay(
                cardsLeft: score.cardsLeft,
                appliedMultiplier: score.appliedMultiplier,
                heldTwoApplied: score.heldTwoApplied,
                points: score.points,
                baseMultiplier: score.baseMultiplier
            )
        }
    }


}

/// One opponent in a player's pairwise settlement: 贏/輸/和 {name} {n} 張.
public struct PairwiseItem: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable { case win, lose, tie }
    public var opponent: Int
    public var outcome: Outcome
    /// |p_j − p_i| in multiplied cards (cards × 炒倍, incl. 有 2 再 ×2).
    public var amount: Int

    public init(opponent: Int, outcome: Outcome, amount: Int) {
        self.opponent = opponent
        self.outcome = outcome
        self.amount = amount
    }
}

extension RoundPresentation {
    /// Pairwise (HK) breakdown per player: wins first, then losses, each by amount
    /// (largest first, seat order on ties), then 和 (equal penalties).
    /// The amounts add up to the player's net: Σ win − Σ lose = points.
    public static func pairwiseBreakdown(from round: Round) -> [[PairwiseItem]] {
        let penalties = round.scores.map(\.penalty)
        return penalties.indices.map { i in
            let items = penalties.indices.filter { $0 != i }.map { j -> PairwiseItem in
                let diff = penalties[j] - penalties[i]
                let outcome: PairwiseItem.Outcome = diff > 0 ? .win : (diff < 0 ? .lose : .tie)
                return PairwiseItem(opponent: j, outcome: outcome, amount: abs(diff))
            }
            func group(_ outcome: PairwiseItem.Outcome) -> [PairwiseItem] {
                items.filter { $0.outcome == outcome }
                    .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.opponent < $1.opponent }
            }
            return group(.win) + group(.lose) + group(.tie)
        }
    }
}
