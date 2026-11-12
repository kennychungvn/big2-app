import Foundation

/// Provides the current time so interstitial interval checks can be tested with a fake clock.
public protocol Clock: Sendable {
    var now: Date { get }
}

/// Production clock that reads the system date.
public struct SystemClock: Clock, Sendable {
    public init() {}

    public var now: Date { Date() }
}

/// Interstitial cadence used by `Session.shouldShowInterstitial(beforeStartingRound:)`.
public enum InterstitialPolicy: Sendable {
    /// Show a skippable interstitial after every N completed rounds, before the next one starts.
    public static let roundsPerAd = 5
    /// Default minimum gap between two interstitials in the same session.
    public static let defaultMinimumInterval: TimeInterval = 180
}
