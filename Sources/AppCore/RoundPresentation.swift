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
}
