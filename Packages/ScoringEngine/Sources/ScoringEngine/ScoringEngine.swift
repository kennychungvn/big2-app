import Foundation

/// One player's result in a single round.
public struct RoundScore: Codable, Equatable, Sendable {
    /// Cards left at the end of the round. `0` for the winner.
    public let cardsLeft: Int
    /// Multiplier from the scoring rule's tiers (does not include the held-two extra).
    public let baseMultiplier: Int
    /// `true` when the rule's held-two toggle was on and this loser flagged `heldTwo`.
    public let heldTwoApplied: Bool
    /// Signed points for this round. Losers are negative; the winner is positive.
    public let points: Int

    /// Effective multiplier applied to `cardsLeft` to produce `abs(points)` for losers.
    public var appliedMultiplier: Int {
        baseMultiplier * (heldTwoApplied ? 2 : 1)
    }
}

/// The scored outcome of one four-player round. Scores always sum to zero.
public struct Round: Codable, Equatable, Sendable {
    /// Per-player results, aligned with the session's player order.
    public let scores: [RoundScore]

    public var points: [Int] {
        scores.map(\.points)
    }

    public var winnerIndex: Int {
        scores.firstIndex(where: { $0.cardsLeft == 0 }) ?? 0
    }
}

/// Pure 鋤大Dee / Big Two scoring: leftover-card penalties, multipliers, and settlement.
public enum ScoringEngine: Sendable {
    public static let playerCount = 4
    public static let minLoserCards = 1
    public static let maxLoserCards = 13

    /// Scores a four-player round.
    ///
    /// - Parameters:
    ///   - cardsLeft: Exactly four counts. One must be `0` (the winner); the others 1...13.
    ///   - rule: Multiplier table and held-two toggle.
    ///   - heldTwo: Optional per-player flags (same order as `cardsLeft`). Ignored when
    ///     `rule.doubleOnHeldTwo` is `false`. A `nil` value is treated as all `false`.
    /// - Returns: A `Round` whose points sum to zero. Each loser pays
    ///   `cardsLeft × multiplier` (×2 again if the held-two rule applies); the winner
    ///   receives the sum of those penalties.
    public static func score(
        cardsLeft: [Int],
        rule: ScoringRule,
        heldTwo: [Bool]? = nil
    ) throws -> Round {
        try validateInput(cardsLeft: cardsLeft, heldTwo: heldTwo)

        let flags = heldTwo ?? Array(repeating: false, count: playerCount)
        let winnerIndex = cardsLeft.firstIndex(of: 0)!

        var scores = [RoundScore]()
        scores.reserveCapacity(playerCount)
        var winnerGain = 0

        for index in 0..<playerCount {
            if index == winnerIndex {
                // Placeholder; filled in after losers are totaled.
                scores.append(
                    RoundScore(
                        cardsLeft: 0,
                        baseMultiplier: 1,
                        heldTwoApplied: false,
                        points: 0
                    )
                )
                continue
            }

            let cards = cardsLeft[index]
            let baseMultiplier = try rule.multiplier(forCardsLeft: cards)
            let heldTwoApplied = rule.doubleOnHeldTwo && flags[index]
            let penalty = cards * baseMultiplier * (heldTwoApplied ? 2 : 1)
            winnerGain += penalty
            scores.append(
                RoundScore(
                    cardsLeft: cards,
                    baseMultiplier: baseMultiplier,
                    heldTwoApplied: heldTwoApplied,
                    points: -penalty
                )
            )
        }

        scores[winnerIndex] = RoundScore(
            cardsLeft: 0,
            baseMultiplier: 1,
            heldTwoApplied: false,
            points: winnerGain
        )

        return Round(scores: scores)
    }

    static func validateInput(cardsLeft: [Int], heldTwo: [Bool]?) throws {
        guard cardsLeft.count == playerCount else {
            throw ScoringError.wrongPlayerCount(expected: playerCount, actual: cardsLeft.count)
        }
        if let heldTwo, heldTwo.count != playerCount {
            throw ScoringError.wrongPlayerCount(expected: playerCount, actual: heldTwo.count)
        }

        var winnerCount = 0
        for (index, cards) in cardsLeft.enumerated() {
            if cards == 0 {
                winnerCount += 1
                continue
            }
            if cards < minLoserCards || cards > maxLoserCards {
                throw ScoringError.cardsOutOfRange(playerIndex: index, cardsLeft: cards)
            }
        }

        if winnerCount == 0 {
            throw ScoringError.noWinner
        }
        if winnerCount > 1 {
            throw ScoringError.multipleWinners
        }
    }
}
