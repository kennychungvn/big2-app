import Foundation

/// How a round's penalties are settled between the four players.
public enum ScoringMode: String, Codable, CaseIterable, Sendable {
    /// Every pair of players settles the difference of their computed scores
    /// (香港玩法 / 互對). With `p_i` the player's penalty (winner `p = 0`),
    /// `score_i = Σ_{j≠i} (p_j − p_i) = P − 4·p_i` where `P` is the sum of penalties.
    case pairwise
    /// 贏家通吃: each loser pays `p_i` to the winner, who collects every loser's score.
    case winnerTakesAll
}

/// One player's result in a single round.
public struct RoundScore: Codable, Equatable, Sendable {
    /// Cards left at the end of the round. `0` for the winner.
    public let cardsLeft: Int
    /// Multiplier from the scoring rule's tiers (does not include held-two or manual doubles).
    public let baseMultiplier: Int
    /// `true` when the rule's held-two toggle was on and this loser flagged `heldTwo`.
    public let heldTwoApplied: Bool
    /// Count of manual ×2 applications (unplayed 2s, 4條, 同花順). Always `0` in Hong Kong
    /// scoring, which uses `heldTwoApplied` instead. Clamped to `0...ScoringEngine.maxManualDoubles`.
    public let manualDoubles: Int
    /// Signed net points for this round under the session's `ScoringMode`.
    public let points: Int

    public init(
        cardsLeft: Int,
        baseMultiplier: Int,
        heldTwoApplied: Bool,
        points: Int,
        manualDoubles: Int = 0
    ) {
        self.cardsLeft = cardsLeft
        self.baseMultiplier = baseMultiplier
        self.heldTwoApplied = heldTwoApplied
        self.manualDoubles = ScoringEngine.clampManualDoubles(manualDoubles)
        self.points = points
    }

    /// Effective multiplier applied to `cardsLeft` (tier × held-two extra × 2^manualDoubles).
    public var appliedMultiplier: Int {
        ScoringEngine.appliedMultiplier(
            baseMultiplier: baseMultiplier,
            heldTwoApplied: heldTwoApplied,
            manualDoubles: manualDoubles
        )
    }

    /// `cardsLeft × appliedMultiplier`; `0` for the winner.
    public var penalty: Int {
        cardsLeft * appliedMultiplier
    }

    private enum CodingKeys: String, CodingKey {
        case cardsLeft
        case baseMultiplier
        case heldTwoApplied
        case manualDoubles
        case points
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cardsLeft = try container.decode(Int.self, forKey: .cardsLeft)
        let baseMultiplier = try container.decode(Int.self, forKey: .baseMultiplier)
        let heldTwoApplied = try container.decode(Bool.self, forKey: .heldTwoApplied)
        let points = try container.decode(Int.self, forKey: .points)
        let manualDoubles = try container.decodeIfPresent(Int.self, forKey: .manualDoubles) ?? 0
        self.init(
            cardsLeft: cardsLeft,
            baseMultiplier: baseMultiplier,
            heldTwoApplied: heldTwoApplied,
            points: points,
            manualDoubles: manualDoubles
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cardsLeft, forKey: .cardsLeft)
        try container.encode(baseMultiplier, forKey: .baseMultiplier)
        try container.encode(heldTwoApplied, forKey: .heldTwoApplied)
        try container.encode(points, forKey: .points)
        if manualDoubles != 0 {
            try container.encode(manualDoubles, forKey: .manualDoubles)
        }
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
    /// Manual ×2 stepper cap (2^8 = 256). Keeps `cardsLeft × multiplier` inside `Int`.
    public static let maxManualDoubles = 8

    public static func clampManualDoubles(_ value: Int) -> Int {
        min(max(0, value), maxManualDoubles)
    }

    /// Tier multiplier, then ×2 if held-two applied, then ×2 once per manual double.
    public static func appliedMultiplier(
        baseMultiplier: Int,
        heldTwoApplied: Bool = false,
        manualDoubles: Int = 0
    ) -> Int {
        var multiplier = baseMultiplier * (heldTwoApplied ? 2 : 1)
        for _ in 0..<clampManualDoubles(manualDoubles) {
            multiplier *= 2
        }
        return multiplier
    }

    /// `cardsLeft × appliedMultiplier`. The winner (`cardsLeft == 0`) is always 0.
    public static func penalty(
        cardsLeft: Int,
        baseMultiplier: Int,
        heldTwoApplied: Bool = false,
        manualDoubles: Int = 0
    ) -> Int {
        cardsLeft * appliedMultiplier(
            baseMultiplier: baseMultiplier,
            heldTwoApplied: heldTwoApplied,
            manualDoubles: manualDoubles
        )
    }

    /// Scores a four-player round.
    ///
    /// - Parameters:
    ///   - cardsLeft: Exactly four counts. One must be `0` (the winner); the others 1...13.
    ///   - rule: Multiplier table and held-two toggle.
    ///   - heldTwo: Optional per-player flags (same order as `cardsLeft`). Ignored when
    ///     `rule.doubleOnHeldTwo` is `false`. A `nil` value is treated as all `false`.
    ///   - mode: Settlement. `pairwise` (互對 / Hong Kong, default) or `winnerTakesAll` (贏家通吃).
    ///   - manualDoubles: Optional per-player count of extra ×2 taps (unplayed 2, 4條, 同花順).
    ///     A `nil` value is treated as all `0`. The winner's count is ignored. Values are
    ///     clamped to `0...maxManualDoubles`. Hong Kong scoring leaves this `nil`.
    /// - Returns: A `Round` whose points sum to zero. Each player's penalty is
    ///   `cardsLeft × multiplier` (×2 again if the held-two rule applies, then ×2 per
    ///   manual double). In `pairwise` mode `score_i = P − 4·p_i`; in `winnerTakesAll`
    ///   mode losers score `−p_i` and the winner `P`.
    public static func score(
        cardsLeft: [Int],
        rule: ScoringRule,
        heldTwo: [Bool]? = nil,
        mode: ScoringMode = .pairwise,
        manualDoubles: [Int]? = nil
    ) throws -> Round {
        try validateInput(cardsLeft: cardsLeft, heldTwo: heldTwo, manualDoubles: manualDoubles)

        let flags = heldTwo ?? Array(repeating: false, count: playerCount)
        let doubles = (manualDoubles ?? Array(repeating: 0, count: playerCount)).map(clampManualDoubles)
        let winnerIndex = cardsLeft.firstIndex(of: 0)!

        var scores = [RoundScore]()
        scores.reserveCapacity(playerCount)
        var winnerGain = 0

        for index in 0..<playerCount {
            if index == winnerIndex {
                scores.append(
                    RoundScore(
                        cardsLeft: 0,
                        baseMultiplier: 1,
                        heldTwoApplied: false,
                        points: 0,
                        manualDoubles: 0
                    )
                )
                continue
            }

            let cards = cardsLeft[index]
            let baseMultiplier = try rule.multiplier(forCardsLeft: cards)
            let heldTwoApplied = rule.doubleOnHeldTwo && flags[index]
            let manual = doubles[index]
            let penalty = Self.penalty(
                cardsLeft: cards,
                baseMultiplier: baseMultiplier,
                heldTwoApplied: heldTwoApplied,
                manualDoubles: manual
            )
            winnerGain += penalty
            scores.append(
                RoundScore(
                    cardsLeft: cards,
                    baseMultiplier: baseMultiplier,
                    heldTwoApplied: heldTwoApplied,
                    points: -penalty,
                    manualDoubles: manual
                )
            )
        }

        scores[winnerIndex] = RoundScore(
            cardsLeft: 0,
            baseMultiplier: 1,
            heldTwoApplied: false,
            points: winnerGain,
            manualDoubles: 0
        )

        if mode == .pairwise {
            let total = winnerGain
            scores = scores.map { score in
                RoundScore(
                    cardsLeft: score.cardsLeft,
                    baseMultiplier: score.baseMultiplier,
                    heldTwoApplied: score.heldTwoApplied,
                    points: total - ScoringEngine.playerCount * score.penalty,
                    manualDoubles: score.manualDoubles
                )
            }
        }

        return Round(scores: scores)
    }

    static func validateInput(cardsLeft: [Int], heldTwo: [Bool]?, manualDoubles: [Int]? = nil) throws {
        guard cardsLeft.count == playerCount else {
            throw ScoringError.wrongPlayerCount(expected: playerCount, actual: cardsLeft.count)
        }
        if let heldTwo, heldTwo.count != playerCount {
            throw ScoringError.wrongPlayerCount(expected: playerCount, actual: heldTwo.count)
        }
        if let manualDoubles, manualDoubles.count != playerCount {
            throw ScoringError.wrongPlayerCount(expected: playerCount, actual: manualDoubles.count)
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
