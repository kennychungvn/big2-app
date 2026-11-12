import Foundation
import ScoringEngine

/// A `Session` plus the identity and timestamps the app needs for the home list.
public struct StoredSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var session: Session
    public var createdAt: Date
    public var updatedAt: Date
    public var endedAt: Date?

    public init(
        id: UUID = UUID(),
        session: Session,
        createdAt: Date,
        updatedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.session = session
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.endedAt = endedAt
    }

    public var isFinished: Bool { endedAt != nil }

    public var playerSummary: String {
        session.players.joined(separator: "、")
    }

    public func leaderSummary(format: ScoreFormatting = .init()) -> String? {
        guard session.roundsCompleted > 0, let leader = session.ranking.first else { return nil }
        return "\(leader.name) \(format.points(leader.total))"
    }
}

/// One row in the scoreboard history list, newest first in the UI.
public struct RoundHistoryRow: Equatable, Identifiable, Sendable {
    public var id: Int { index }
    /// 0-based index into `session.rounds`.
    public let index: Int
    /// 1-based round number shown to the user.
    public let roundNumber: Int
    public let points: [Int]
    public let cardsLeft: [Int]

    public init(index: Int, round: Round) {
        self.index = index
        self.roundNumber = index + 1
        self.points = round.points
        self.cardsLeft = round.scores.map(\.cardsLeft)
    }
}
