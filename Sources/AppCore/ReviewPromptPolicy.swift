import Foundation

/// When to show Apple's native in-app review prompt (`requestReview`).
/// After the 3rd completed 完場, at most once per marketing version. No custom pre-prompt.
public enum ReviewPromptPolicy: Sendable {
    public static let minimumCompletedGames = 3

    /// Short wait after the settlement screen is up, so the prompt is not on top of an interstitial.
    public static let settlementDelayNanoseconds: UInt64 = 1_200_000_000

    public static let completedGameCountKey = "reviewPrompt.completedGameCount"
    public static let lastPromptedVersionKey = "reviewPrompt.lastPromptedVersion"

    public static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6835281948?action=write-review")!

    public static func shouldRequestReview(
        completedGameCount: Int,
        currentVersion: String,
        lastPromptedVersion: String?
    ) -> Bool {
        guard completedGameCount >= minimumCompletedGames else { return false }
        let version = currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else { return false }
        return lastPromptedVersion != version
    }

    /// First launch of this feature: if nothing is stored yet, start from games already finished.
    public static func initialCompletedGameCount(
        storedCount: Int?,
        existingFinishedSessionCount: Int
    ) -> Int {
        storedCount ?? max(0, existingFinishedSessionCount)
    }
}

/// UserDefaults-backed counters for the review prompt. Pass a suite in tests.
/// `@unchecked Sendable` because `UserDefaults` is not Sendable, but its accessors are thread-safe.
public final class ReviewPromptStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `nil` until a count has been written (so first launch can seed from existing sessions).
    public var storedCompletedGameCount: Int? {
        guard defaults.object(forKey: ReviewPromptPolicy.completedGameCountKey) != nil else {
            return nil
        }
        return defaults.integer(forKey: ReviewPromptPolicy.completedGameCountKey)
    }

    public var completedGameCount: Int {
        get { storedCompletedGameCount ?? 0 }
        set { defaults.set(max(0, newValue), forKey: ReviewPromptPolicy.completedGameCountKey) }
    }

    public var lastPromptedVersion: String? {
        get {
            let value = defaults.string(forKey: ReviewPromptPolicy.lastPromptedVersionKey)
            if let value, !value.isEmpty { return value }
            return nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: ReviewPromptPolicy.lastPromptedVersionKey)
            } else {
                defaults.removeObject(forKey: ReviewPromptPolicy.lastPromptedVersionKey)
            }
        }
    }

    public func seedIfNeeded(existingFinishedSessionCount: Int) {
        guard storedCompletedGameCount == nil else { return }
        completedGameCount = ReviewPromptPolicy.initialCompletedGameCount(
            storedCount: nil,
            existingFinishedSessionCount: existingFinishedSessionCount
        )
    }

    public func recordFinishedGame() {
        completedGameCount += 1
    }

    public func recordPromptShown(for version: String) {
        lastPromptedVersion = version
    }

    public func shouldRequestReview(currentVersion: String) -> Bool {
        ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: completedGameCount,
            currentVersion: currentVersion,
            lastPromptedVersion: lastPromptedVersion
        )
    }
}
