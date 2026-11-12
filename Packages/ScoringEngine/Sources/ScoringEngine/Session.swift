import Foundation

/// A player row in the session standings, sorted by total points descending.
public struct RankedPlayer: Codable, Equatable, Sendable {
    /// Index into the session's `players` array.
    public let index: Int
    public let name: String
    public let total: Int
    /// 1-based competition rank (ties share a rank; the next rank is skipped).
    public let rank: Int
}

/// A four-player 鋤大Dee scoring session: rule, rounds, standings, and ad cadence.
public struct Session: Codable, Equatable, Sendable {
    public var players: [String]
    public var rule: ScoringRule
    /// How rounds are settled. Sessions saved before this field existed decode as
    /// `winnerTakesAll`, which is how their rounds were scored.
    public let scoringMode: ScoringMode
    public private(set) var rounds: [Round]

    /// Minimum time that must pass between two interstitials. Defaults to 180 seconds.
    public var interstitialMinimumInterval: TimeInterval

    /// Completed-round counts (5, 10, 15, ...) for which an interstitial was already shown.
    public private(set) var shownInterstitialMilestones: Set<Int>

    public private(set) var lastInterstitialShownAt: Date?

    /// Creates a new session.
    ///
    /// - Parameters:
    ///   - players: Exactly four display names.
    ///   - rule: Scoring rule. Defaults to `hongKongDefault`.
    ///   - scoringMode: Settlement. Defaults to `pairwise` (Hong Kong).
    ///   - interstitialMinimumInterval: Minimum gap between ads. Defaults to 180 seconds.
    public init(
        players: [String],
        rule: ScoringRule = .hongKongDefault,
        scoringMode: ScoringMode = .pairwise,
        interstitialMinimumInterval: TimeInterval = InterstitialPolicy.defaultMinimumInterval
    ) throws {
        guard players.count == ScoringEngine.playerCount else {
            throw ScoringError.wrongPlayerCount(
                expected: ScoringEngine.playerCount,
                actual: players.count
            )
        }
        self.players = players
        self.rule = rule
        self.scoringMode = scoringMode
        self.rounds = []
        self.interstitialMinimumInterval = interstitialMinimumInterval
        self.shownInterstitialMilestones = []
        self.lastInterstitialShownAt = nil
    }

    public var roundsCompleted: Int { rounds.count }

    /// Cumulative points for each player, in player order.
    public var totals: [Int] {
        var result = Array(repeating: 0, count: ScoringEngine.playerCount)
        for round in rounds {
            for (index, points) in round.points.enumerated() {
                result[index] += points
            }
        }
        return result
    }

    /// Players sorted by total descending, then by original index for ties.
    /// Tied totals share a competition rank (1, 1, 3, 4).
    public var ranking: [RankedPlayer] {
        let totals = self.totals
        let order = (0..<ScoringEngine.playerCount).sorted { lhs, rhs in
            if totals[lhs] != totals[rhs] {
                return totals[lhs] > totals[rhs]
            }
            return lhs < rhs
        }

        var ranked: [RankedPlayer] = []
        ranked.reserveCapacity(ScoringEngine.playerCount)
        for (position, index) in order.enumerated() {
            let rank: Int
            if position > 0, totals[index] == totals[order[position - 1]] {
                rank = ranked[position - 1].rank
            } else {
                rank = position + 1
            }
            ranked.append(
                RankedPlayer(
                    index: index,
                    name: players[index],
                    total: totals[index],
                    rank: rank
                )
            )
        }
        return ranked
    }

    /// Scores and appends a round. See `ScoringEngine.score(cardsLeft:rule:heldTwo:)`.
    @discardableResult
    public mutating func addRound(cardsLeft: [Int], heldTwo: [Bool]? = nil) throws -> Round {
        let round = try ScoringEngine.score(cardsLeft: cardsLeft, rule: rule, heldTwo: heldTwo, mode: scoringMode)
        rounds.append(round)
        return round
    }

    /// Removes and returns the most recently added round.
    @discardableResult
    public mutating func undoLastRound() throws -> Round {
        guard let last = rounds.popLast() else {
            throw ScoringError.noRoundsToUndo
        }
        return last
    }

    /// Replaces the round at `index` with a newly scored result using the current rule.
    @discardableResult
    public mutating func editRound(
        at index: Int,
        cardsLeft: [Int],
        heldTwo: [Bool]? = nil
    ) throws -> Round {
        guard rounds.indices.contains(index) else {
            throw ScoringError.invalidRoundIndex(index)
        }
        let round = try ScoringEngine.score(cardsLeft: cardsLeft, rule: rule, heldTwo: heldTwo, mode: scoringMode)
        rounds[index] = round
        return round
    }

    /// Whether a skippable interstitial should play before the user starts entering the next round.
    ///
    /// Returns `true` only when all of the following hold:
    /// - `beforeStartingRound` equals `roundsCompleted + 1` (the next unplayed round).
    /// - The number of completed rounds is a positive multiple of 5 (i.e. before rounds 6, 11, 16, ...).
    /// - That milestone has not already been shown in this session.
    /// - At least `interstitialMinimumInterval` has passed since the last shown interstitial
    ///   (the interval check is skipped if none has been shown yet).
    public func shouldShowInterstitial(
        beforeStartingRound: Int,
        clock: any Clock = SystemClock()
    ) -> Bool {
        let completed = roundsCompleted
        guard beforeStartingRound == completed + 1 else { return false }
        guard completed > 0, completed % InterstitialPolicy.roundsPerAd == 0 else { return false }

        if shownInterstitialMilestones.contains(completed) {
            return false
        }

        if let lastShown = lastInterstitialShownAt,
           clock.now.timeIntervalSince(lastShown) < interstitialMinimumInterval {
            return false
        }

        return true
    }

    /// Records that the interstitial for the current completed-round milestone was shown
    /// (or skipped by the user after being presented).
    public mutating func recordInterstitialShown(clock: any Clock = SystemClock()) {
        let completed = roundsCompleted
        if completed > 0, completed % InterstitialPolicy.roundsPerAd == 0 {
            shownInterstitialMilestones.insert(completed)
        }
        lastInterstitialShownAt = clock.now
    }

    private enum CodingKeys: String, CodingKey {
        case players, rule, scoringMode, rounds, interstitialMinimumInterval
        case shownInterstitialMilestones, lastInterstitialShownAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([String].self, forKey: .players)
        rule = try container.decode(ScoringRule.self, forKey: .rule)
        scoringMode = try container.decodeIfPresent(ScoringMode.self, forKey: .scoringMode) ?? .winnerTakesAll
        rounds = try container.decode([Round].self, forKey: .rounds)
        interstitialMinimumInterval = try container.decode(TimeInterval.self, forKey: .interstitialMinimumInterval)
        shownInterstitialMilestones = try container.decode(Set<Int>.self, forKey: .shownInterstitialMilestones)
        lastInterstitialShownAt = try container.decodeIfPresent(Date.self, forKey: .lastInterstitialShownAt)
    }
}
