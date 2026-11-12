import Foundation

/// How a round's penalties are settled between the four players.
public enum ScoringMode: String, Codable, CaseIterable, Sendable {
    /// Hong Kong 鋤大D: every pair of players settles the difference of their penalties.
    /// With `p_i = cardsLeft_i × multiplier_i` (winner `p = 0`),
    /// `score_i = Σ_{j≠i} (p_j − p_i)`. A loser with few cards can finish the round positive.
    case pairwise
    /// Only the winner collects: each loser pays `p_i` to the winner.
    case winnerTakesAll
}

/// One player's result in a single round.
public struct RoundScore: Codable, Equatable, Sendable {
    /// Cards left at the end of the round. `0` for the winner.
    public let cardsLeft: Int
    /// Multiplier from the scoring rule's tiers (does not include the held-two extra).
    public let baseMultiplier: Int
    /// `true` when the rule's held-two toggle was on and this loser flagged `heldTwo`.
    public let heldTwoApplied: Bool
    /// Signed net points for this round under the session's `ScoringMode`.
    public let points: Int

    /// Effective multiplier applied to `cardsLeft` (tier × held-two extra).
    public var appliedMultiplier: Int {
        baseMultiplier * (heldTwoApplied ? 2 : 1)
    }

    /// `cardsLeft × appliedMultiplier`; `0` for the winner.
    public var penalty: Int {
        cardsLeft * appliedMultiplier
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
    ///   - mode: Settlement. `pairwise` (Hong Kong, default) or `winnerTakesAll`.
    /// - Returns: A `Round` whose points sum to zero. Each player's penalty is
    ///   `cardsLeft × multiplier` (×2 again if the held-two rule applies). In `pairwise`
    ///   mode `score_i = Σ_{j≠i} (p_j − p_i) = P − 4·p_i` where `P` is the sum of penalties;
    ///   in `winnerTakesAll` mode losers score `−p_i` and the winner `P`.
    public static func score(
        cardsLeft: [Int],
        rule: ScoringRule,
        heldTwo: [Bool]? = nil,
        mode: ScoringMode = .pairwise
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

        if mode == .pairwise {
            let total = winnerGain
            scores = scores.map { score in
                RoundScore(
                    cardsLeft: score.cardsLeft,
                    baseMultiplier: score.baseMultiplier,
                    heldTwoApplied: score.heldTwoApplied,
                    points: total - ScoringEngine.playerCount * score.penalty
                )
            }
        }

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
