import Foundation
import ScoringEngine

/// One player's total as shown on a 最近場次 / 所有紀錄 row.
public struct SessionListScore: Equatable, Sendable {
    public var name: String
    public var total: Int

    public init(name: String, total: Int) {
        self.name = name
        self.total = total
    }
}

/// What a history row shows (v1.1 design B): `HH:mm · N 局` on the left, `🏆 winner +score`
/// on the right (ties list every co-winner, e.g. `曦、肥 +80`), and the remaining players,
/// high to low, on a small second line. Unfinished sessions have no winner and list everyone.
public struct SessionListSummary: Equatable, Sendable {
    public var isFinished: Bool
    public var rounds: Int
    /// Rank-1 players of a finished session, in ranking order. Empty when unfinished.
    public var winners: [SessionListScore]
    /// Everyone not in `winners`, sorted by total descending (ties keep player order).
    public var others: [SessionListScore]

    public init(stored: StoredSession) {
        let ranking = stored.session.ranking
        self.isFinished = stored.isFinished
        self.rounds = stored.session.roundsCompleted
        let scores = ranking.map { SessionListScore(name: $0.name, total: $0.total) }
        if stored.isFinished && rounds > 0 {
            let topCount = ranking.filter { $0.rank == 1 }.count
            self.winners = Array(scores.prefix(topCount))
            self.others = Array(scores.dropFirst(topCount))
        } else {
            self.winners = []
            self.others = scores
        }
    }

    /// Winner names joined with `、`, e.g. `曦、肥`. Nil when there is no winner.
    public var winnerNames: String? {
        winners.isEmpty ? nil : winners.map(\.name).joined(separator: "、")
    }

    /// The winners' shared total. Nil when there is no winner.
    public var winningTotal: Int? {
        winners.first?.total
    }

    /// `🏆 曦 +130` / `🏆 曦、肥 +80`. Nil when there is no winner.
    public func winnerLine(format: ScoreFormatting = .init()) -> String? {
        guard let names = winnerNames, let total = winningTotal else { return nil }
        return "🏆 \(names) \(format.points(total))"
    }
}

/// A date header plus its rows in 所有紀錄.
public struct SessionListSection: Equatable, Identifiable, Sendable {
    public var id: String { title + "#" + (sessions.first?.id.uuidString ?? "") }
    public var title: String
    public var sessions: [StoredSession]

    public init(title: String, sessions: [StoredSession]) {
        self.title = title
        self.sessions = sessions
    }
}

extension StoredSession {
    /// A session with no rounds entered. Never listed in 最近場次 / 所有紀錄.
    public var isEmpty: Bool { session.roundsCompleted == 0 }

    /// Time the row is labelled and grouped by: when the session was started.
    public var listDate: Date { createdAt }
}

extension AppData {
    /// Sessions for 最近場次 / 所有紀錄: no 0-round sessions; unfinished ones first (they can
    /// be resumed), then finished ones; each group newest first.
    public var listedSessions: [StoredSession] {
        let listed = sessions.filter { !$0.isEmpty }
        let unfinished = listed.filter { !$0.isFinished }.sorted { $0.updatedAt > $1.updatedAt }
        let finished = listed.filter(\.isFinished).sorted { $0.updatedAt > $1.updatedAt }
        return unfinished + finished
    }

    /// Removes every 0-round session except `keeping` (the 繼續上一場 target).
    /// Returns how many were removed.
    @discardableResult
    public mutating func removeEmptySessions(keeping keptID: UUID? = nil) -> Int {
        let before = sessions.count
        sessions.removeAll { $0.isEmpty && $0.id != keptID }
        return before - sessions.count
    }
}

extension ScoreFormatting {
    private func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// `14:05`, 24-hour, in `timeZone` (the device's by default).
    public func clockTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Date header: `今日` / `昨日` (TW `今天` / `昨天`), `11/14` this year, else `2025/11/14`.
    public func dayHeader(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        let cal = calendar(timeZone: timeZone)
        let isTaiwan = region == .taiwan
        if cal.isDate(date, inSameDayAs: now) { return isTaiwan ? "今天" : "今日" }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: yesterday) {
            return isTaiwan ? "昨天" : "昨日"
        }
        let parts = cal.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0, month = parts.month ?? 0, day = parts.day ?? 0
        if year == cal.component(.year, from: now) { return "\(month)/\(day)" }
        return "\(year)/\(month)/\(day)"
    }

    /// Row title in 所有紀錄 (under a date header): `14:05 · 4 局`.
    public func sessionRowTitle(date: Date, rounds: Int, timeZone: TimeZone = .current) -> String {
        "\(clockTime(date, timeZone: timeZone)) · \(rounds) 局"
    }

    /// Row title on the home screen (no date headers): `今日 14:05 · 4 局`.
    public func sessionRowTitleWithDay(
        date: Date,
        rounds: Int,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        "\(dayHeader(date, now: now, timeZone: timeZone)) \(sessionRowTitle(date: date, rounds: rounds, timeZone: timeZone))"
    }

    /// Groups already-ordered sessions under date headers. Consecutive sessions on the same
    /// day share a header, so the unfinished-first order of `listedSessions` is kept.
    public func sections(
        for sessions: [StoredSession],
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> [SessionListSection] {
        var result: [SessionListSection] = []
        for stored in sessions {
            let title = dayHeader(stored.listDate, now: now, timeZone: timeZone)
            if var last = result.last, last.title == title {
                last.sessions.append(stored)
                result[result.count - 1] = last
            } else {
                result.append(SessionListSection(title: title, sessions: [stored]))
            }
        }
        return result
    }
}
