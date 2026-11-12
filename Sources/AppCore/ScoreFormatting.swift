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

    public func afterRoundTitle(_ completed: Int) -> String {
        if completed == 0 { return isTaiwan ? "尚未開局" : "未開局" }
        return "第 \(completed) 局後"
    }

    /// Progress line under the home screen's 繼續上一場 button.
    public func homeProgress(_ completed: Int) -> String {
        if completed == 0 { return isTaiwan ? "尚未開局" : "未開始" }
        return isTaiwan ? "已進行 \(completed) 局" : "打咗 \(completed) 局"
    }

    public func resultTitle(_ number: Int) -> String {
        "第 \(number) 局結果"
    }

    public func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        let zone = isTaiwan ? "Asia/Taipei" : "Asia/Hong_Kong"
        formatter.timeZone = TimeZone(identifier: zone) ?? TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    public func sessionListSubtitle(date: Date, rounds: Int) -> String {
        "\(shortDate(date)) · \(rounds) 局"
    }

    /// Detail under a player on the result screen, e.g. `5 張 ×1`, `11 張 ×3 🔥`, `出清牌，收 5 + 18 + 33`.
    public func roundDetail(score: RoundScoreDisplay, winnerReceivedFrom: [Int] = []) -> String {
        let cleared = isTaiwan ? "出完牌" : "出清牌"
        if score.cardsLeft == 0 {
            if winnerReceivedFrom.isEmpty {
                return cleared
            }
            let parts = winnerReceivedFrom.map { "\($0)" }.joined(separator: " + ")
            return "\(cleared)，收 \(parts)"
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

    public init(cardsLeft: Int, appliedMultiplier: Int, heldTwoApplied: Bool, points: Int) {
        self.cardsLeft = cardsLeft
        self.appliedMultiplier = appliedMultiplier
        self.heldTwoApplied = heldTwoApplied
        self.points = points
    }
}
