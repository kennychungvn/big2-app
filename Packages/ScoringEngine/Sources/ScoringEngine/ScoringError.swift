/// Errors thrown when scoring a round or mutating a session.
public enum ScoringError: Error, Equatable, Sendable {
    /// No player has 0 cards left.
    case noWinner
    /// More than one player has 0 cards left.
    case multipleWinners
    /// A non-winner entered a card count outside 1...13.
    case cardsOutOfRange(playerIndex: Int, cardsLeft: Int)
    /// A cards or flags array did not contain exactly 4 entries.
    case wrongPlayerCount(expected: Int, actual: Int)
    /// `undoLastRound()` was called on a session with no rounds.
    case noRoundsToUndo
    /// An edit targeted an index that is not in `rounds`.
    case invalidRoundIndex(Int)
}

/// Errors thrown when constructing a custom `ScoringRule`.
public enum RuleValidationError: Error, Equatable, Sendable {
    case emptyTiers
    /// A tier has `minCards > maxCards`, or a bound outside 1...13.
    case invalidCardRange(minCards: Int, maxCards: Int)
    case multiplierMustBeAtLeastOne(Int)
    /// After sorting, the first tier does not start at 1 or the last does not end at 13.
    case doesNotCoverOneToThirteen
    case overlappingTiers
    case gapInCoverage(missingCard: Int)
}
