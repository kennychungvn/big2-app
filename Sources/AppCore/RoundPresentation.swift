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
                points: score.points
            )
        }
    }

    /// Positive penalties paid by each loser, in player order, for the winner's "收 5 + 18 + 33" line.
    public static func winnerReceipts(from round: Round) -> [Int] {
        round.scores.compactMap { score in
            score.cardsLeft == 0 ? nil : abs(score.points)
        }
    }
}
