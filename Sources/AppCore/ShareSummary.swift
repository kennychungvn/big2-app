import Foundation
import ScoringEngine

/// Plain-text and structured standings used by 完場 sharing. Points only, no money.
public struct ShareSummary: Equatable, Sendable {
    public var title: String
    public var dateLine: String
    public var roundsLine: String
    public var ruleLine: String
    public var rows: [Row]
    public var text: String

    public struct Row: Equatable, Sendable {
        public var rank: Int
        public var name: String
        public var points: String
        public var isLeader: Bool
    }

    public init(stored: StoredSession, format: ScoreFormatting = .init()) {
        let session = stored.session
        self.title = format.appTitle
        self.dateLine = format.shortDate(stored.endedAt ?? stored.updatedAt)
        self.roundsLine = "\(session.roundsCompleted) 局"
        self.ruleLine = format.ruleSummary(session.rule)

        self.rows = session.ranking.map { player in
            Row(
                rank: player.rank,
                name: player.name,
                points: format.points(player.total),
                isLeader: player.rank == 1
            )
        }

        var lines: [String] = [
            title,
            "\(dateLine) · \(roundsLine)",
            ruleLine
        ]
        for row in rows {
            let crown = row.isLeader ? "👑 " : ""
            lines.append("\(row.rank). \(crown)\(row.name)  \(row.points)")
        }
        self.text = lines.joined(separator: "\n")
    }
}
