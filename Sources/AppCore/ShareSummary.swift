import Foundation
import ScoringEngine

/// Plain-text and structured standings used by 完場 sharing. Points only, no money.
public struct ShareSummary: Equatable, Sendable {
    public var title: String
    public var dateLine: String
    public var roundsLine: String
    public var ruleLine: String
    /// `換算 ×N` when conversion is on; otherwise `nil`.
    public var conversionLine: String?
    public var rows: [Row]
    public var text: String

    public struct Row: Equatable, Sendable {
        public var rank: Int
        public var name: String
        public var points: String
        /// Original points, set only when 換算 is applied.
        public var originalPoints: String?
        public var isLeader: Bool

        public init(rank: Int, name: String, points: String, originalPoints: String? = nil, isLeader: Bool) {
            self.rank = rank
            self.name = name
            self.points = points
            self.originalPoints = originalPoints
            self.isLeader = isLeader
        }
    }

    /// - Parameter conversionMultiplier: Applied 換算 multiplier (≥ 2). `nil` or values below 2 leave the summary unchanged.
    public init(stored: StoredSession, format: ScoreFormatting = .init(), conversionMultiplier: Int? = nil) {
        let session = stored.session
        self.title = format.appTitle
        self.dateLine = format.shortDate(stored.endedAt ?? stored.updatedAt)
        self.roundsLine = "\(session.roundsCompleted) 局"
        self.ruleLine = format.ruleSummary(session.rule)

        let applied = conversionMultiplier.flatMap { ScoreConversion.appliedMultiplier(enabled: true, multiplier: $0) }
        self.conversionLine = applied.map(ScoreConversion.line)

        self.rows = session.ranking.map { player in
            if let applied {
                let converted = ScoreConversion.multiply(player.total, by: applied)
                return Row(
                    rank: player.rank,
                    name: player.name,
                    points: format.points(converted),
                    originalPoints: format.points(player.total),
                    isLeader: player.rank == 1
                )
            }
            return Row(
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
        if let conversionLine {
            lines.append(conversionLine)
        }
        for row in rows {
            let crown = row.isLeader ? "👑 " : ""
            if let original = row.originalPoints {
                lines.append("\(row.rank). \(crown)\(row.name)  \(row.points)（\(original)）")
            } else {
                lines.append("\(row.rank). \(crown)\(row.name)  \(row.points)")
            }
        }
        self.text = lines.joined(separator: "\n")
    }
}
