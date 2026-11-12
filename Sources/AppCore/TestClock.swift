import Foundation
import ScoringEngine

/// Mutable clock shared by AppCore tests and (optionally) UI previews.
public final class MutableClock: Clock, @unchecked Sendable {
    public var now: Date

    public init(_ now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
