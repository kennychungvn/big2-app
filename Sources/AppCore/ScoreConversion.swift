import Foundation

/// Settlement-screen 換算: multiply all four totals by a positive integer.
/// Display only — no money or currency wording anywhere.
public enum ScoreConversion: Sendable {
    public static let maxDigits = 4
    public static let enabledDefaultsKey = "huansuan.enabled"
    public static let multiplierDefaultsKey = "huansuan.multiplier"

    /// Digits only, at most `maxDigits`, no leading zeros (a lone `0` is kept).
    public static func sanitize(_ raw: String) -> String {
        var digits = ""
        digits.reserveCapacity(maxDigits)
        for character in raw {
            // A decimal separator ends the value: no fractional input.
            if character == "." || character == "," || character == "．" || character == "。" {
                break
            }
            guard character >= "0" && character <= "9" else { continue }
            digits.append(character)
            if digits.count == maxDigits { break }
        }
        let stripped = digits.drop { $0 == "0" }
        if stripped.isEmpty {
            return digits.isEmpty ? "" : "0"
        }
        return String(stripped)
    }

    /// `nil` when the field is empty.
    public static func parse(_ sanitized: String) -> Int? {
        guard !sanitized.isEmpty else { return nil }
        return Int(sanitized)
    }

    /// Applied conversion uses a multiplier of 2...9999. Empty, 0, and 1 are not applied.
    public static func appliedMultiplier(enabled: Bool, input: String) -> Int? {
        guard enabled, let value = parse(sanitize(input)), value >= 2 else { return nil }
        return value
    }

    /// Applied conversion from a stored integer. Values below 2 are not applied.
    public static func appliedMultiplier(enabled: Bool, multiplier: Int) -> Int? {
        guard enabled, (2...9_999).contains(multiplier) else { return nil }
        return multiplier
    }

    /// `score × multiplier`, clamped to `Int` if the product would overflow.
    public static func multiply(_ score: Int, by multiplier: Int) -> Int {
        let (result, overflow) = score.multipliedReportingOverflow(by: multiplier)
        if !overflow { return result }
        if score == 0 || multiplier == 0 { return 0 }
        let negative = (score < 0) != (multiplier < 0)
        return negative ? Int.min : Int.max
    }

    /// Share-card tag and share-text line, e.g. `換算 ×5`.
    public static func line(multiplier: Int) -> String {
        "換算 ×\(multiplier)"
    }
}
