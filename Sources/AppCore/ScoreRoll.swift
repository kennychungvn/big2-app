import Foundation

/// Display-only helpers for the 確定 totals roll (motion spec §4).
/// The model is committed immediately; these values drive the presentation.
public enum ScoreRoll: Sendable {
    /// Session totals immediately before this round's points were applied.
    public static func totalsBefore(after: [Int], points: [Int]) -> [Int] {
        zip(after, points).map(-)
    }
}
