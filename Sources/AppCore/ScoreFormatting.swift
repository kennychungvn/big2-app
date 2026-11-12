import Foundation

/// Traditional Chinese display helpers for points, dates, and rounds, in Hong Kong or Taiwan wording.
public struct ScoreFormatting: Equatable, Sendable {
    public var region: InterfaceRegion
    public var locale: Locale

    public init(region: InterfaceRegion = .hongKong) {
        self.region = region
        self.locale = region.locale
    }

    private var isTaiwan: Bool { region == .taiwan }

    /// Uses a typographic minus, e.g. `+56`, `−5`, `0`.
    public func points(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        if value < 0 { return "−\(abs(value))" }
        return "0"
    }

    public func roundTitle(_ number: Int) -> String {
        "第 \(number) 局"
    }

    /// Progress line: under the home screen's 繼續上一場 button, the scoreboard title and
    /// 累計排名（…） on the result screen.
    public func homeProgress(_ completed: Int) -> String {
        if completed == 0 { return isTaiwan ? "尚未開局" : "未開始" }
        return isTaiwan ? "已進行 \(completed) 局" : "打咗 \(completed) 局"
    }

    public func resultTitle(_ number: Int) -> String {
        "第 \(number) 局結果"
    }

    /// Date with year, e.g. `2026/11/12` (both regions).
    public func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        let zone = isTaiwan ? "Asia/Taipei" : "Asia/Hong_Kong"
        formatter.timeZone = TimeZone(identifier: zone) ?? TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }

    public func sessionListSubtitle(date: Date, rounds: Int) -> String {
        "\(shortDate(date)) · \(rounds) 局"
    }

    /// Detail under a player on the result screen, e.g. `出清牌`, `5 張 ×1`, `13 張 ×4`.
    /// The round's net points are shown separately. Every 炒倍 reads the same (no 🔥, no
    /// 炒到盡 wording). TODO: highest-炒倍 highlight will be an animation later.
    public func roundDetail(score: RoundScoreDisplay) -> String {
        if score.cardsLeft == 0 {
            return isTaiwan ? "出完牌" : "出清牌"
        }
        var text = "\(score.cardsLeft) 張 ×\(score.appliedMultiplier)"
        if score.heldTwoApplied {
            text += "（有 2 再 ×2）"
        }
        return text
    }

    /// Header above the running totals on the result screen, e.g. `累計 · 打咗 6 局`.
    public func resultTotalsHeader(_ completed: Int) -> String {
        "累計 · \(homeProgress(completed))"
    }

    public func placeholderName(at index: Int) -> String {
        "玩家 \(index + 1)"
    }

    /// App name used in shared results.
    public var appTitle: String {
        isTaiwan ? "大老二記分" : "鋤大D計分"
    }
}

/// Lightweight projection of a per-player round score for display code.
public struct RoundScoreDisplay: Equatable, Sendable {
    public var cardsLeft: Int
    public var appliedMultiplier: Int
    public var heldTwoApplied: Bool
    public var points: Int
    /// 炒倍 from the session rule, before 有 2 再 ×2.
    public var baseMultiplier: Int

    public init(cardsLeft: Int, appliedMultiplier: Int, heldTwoApplied: Bool, points: Int, baseMultiplier: Int? = nil) {
        self.cardsLeft = cardsLeft
        self.appliedMultiplier = appliedMultiplier
        self.heldTwoApplied = heldTwoApplied
        self.points = points
        self.baseMultiplier = baseMultiplier ?? (heldTwoApplied ? appliedMultiplier / 2 : appliedMultiplier)
    }
}
