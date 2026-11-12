import Foundation

/// Traditional Chinese (Hong Kong) display helpers for points, money, dates, and rounds.
public struct ScoreFormatting: Equatable, Sendable {
    public var locale: Locale

    public init(locale: Locale = Locale(identifier: "zh_HK")) {
        self.locale = locale
    }

    /// Uses a typographic minus, e.g. `+56`, `−5`, `0`.
    public func points(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        if value < 0 { return "−\(abs(value))" }
        return "0"
    }

    /// Wireframe style: `+$72`, `−$9`. Returns `nil` when there is no per-point value.
    public func money(_ value: Decimal?) -> String? {
        guard let value else { return nil }
        if value > 0 { return "+$\(decimalString(value))" }
        if value < 0 { return "−$\(decimalString(-value))" }
        return "$0"
    }

    public func roundTitle(_ number: Int) -> String {
        "第 \(number) 局"
    }

    public func afterRoundTitle(_ completed: Int) -> String {
        if completed == 0 { return "未開局" }
        return "第 \(completed) 局後"
    }

    public func resultTitle(_ number: Int) -> String {
        "第 \(number) 局結果"
    }

    public func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    public func sessionListSubtitle(date: Date, rounds: Int) -> String {
        "\(shortDate(date)) · \(rounds) 局"
    }

    /// Detail under a player on the result screen, e.g. `5 張 ×1`, `11 張 ×3 🔥`, `出清牌，收 5 + 18 + 33`.
    public func roundDetail(score: RoundScoreDisplay, winnerReceivedFrom: [Int] = []) -> String {
        if score.cardsLeft == 0 {
            if winnerReceivedFrom.isEmpty {
                return "出清牌"
            }
            let parts = winnerReceivedFrom.map { "\($0)" }.joined(separator: " + ")
            return "出清牌，收 \(parts)"
        }
        var text = "\(score.cardsLeft) 張 ×\(score.appliedMultiplier)"
        if score.appliedMultiplier >= 3 {
            text += " 🔥"
        }
        if score.heldTwoApplied {
            text += "（有 2 再 ×2）"
        }
        return text
    }

    public func placeholderName(at index: Int) -> String {
        "玩家 \(index + 1)"
    }

    public func decimalString(_ value: Decimal) -> String {
        var v = value
        if v < 0 { v = -v }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &v, 2, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}

/// Lightweight projection of a per-player round score for display code.
public struct RoundScoreDisplay: Equatable, Sendable {
    public var cardsLeft: Int
    public var appliedMultiplier: Int
    public var heldTwoApplied: Bool
    public var points: Int

    public init(cardsLeft: Int, appliedMultiplier: Int, heldTwoApplied: Bool, points: Int) {
        self.cardsLeft = cardsLeft
        self.appliedMultiplier = appliedMultiplier
        self.heldTwoApplied = heldTwoApplied
        self.points = points
    }
}
