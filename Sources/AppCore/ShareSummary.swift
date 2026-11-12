import Foundation
import ScoringEngine

/// Plain-text and structured standings used by 完場 sharing.
public struct ShareSummary: Equatable, Sendable {
    public var title: String
    public var dateLine: String
    public var roundsLine: String
    public var ruleLine: String
    public var moneyLine: String?
    public var rows: [Row]
    public var text: String

    public struct Row: Equatable, Sendable {
        public var rank: Int
        public var name: String
        public var points: String
        public var money: String?
        public var isLeader: Bool
    }

    public init(stored: StoredSession, format: ScoreFormatting = .init()) {
        let session = stored.session
        let preset = RulePreset(matching: session.rule)
        self.title = "鋤大Dee 計分"
        self.dateLine = format.shortDate(stored.endedAt ?? stored.updatedAt)
        self.roundsLine = "\(session.roundsCompleted) 局"
        self.ruleLine = "\(preset.displayName)（\(preset.summary)）"
        if let value = session.pointValue {
            self.moneyLine = "每分 $\(NSDecimalNumber(decimal: value).stringValue)"
        } else {
            self.moneyLine = nil
        }

        self.rows = session.ranking.map { player in
            Row(
                rank: player.rank,
                name: player.name,
                points: format.points(player.total),
                money: format.money(player.money),
                isLeader: player.rank == 1
            )
        }

        var lines: [String] = [
            title,
            "\(dateLine) · \(roundsLine)",
            ruleLine
        ]
        if let moneyLine {
            lines.append(moneyLine)
        }
        for row in rows {
            let crown = row.isLeader ? "👑 " : ""
            if let money = row.money {
                lines.append("\(row.rank). \(crown)\(row.name)  \(row.points)  \(money)")
            } else {
                lines.append("\(row.rank). \(crown)\(row.name)  \(row.points)")
            }
        }
        self.text = lines.joined(separator: "\n")
    }
}
