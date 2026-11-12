import Foundation

/// On-disk document: sessions, last 開場設定, known names, and IAP / preference flags.
public struct AppData: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var sessions: [StoredSession]
    public var lastSettings: LastSettings
    public var knownPlayerNames: [String]
    public var adsRemoved: Bool
    public var chaoAnimationEnabled: Bool
    public var hapticsEnabled: Bool

    public static let currentSchemaVersion = 1

    public static let empty = AppData(
        schemaVersion: currentSchemaVersion,
        sessions: [],
        lastSettings: LastSettings(),
        knownPlayerNames: [],
        adsRemoved: false,
        chaoAnimationEnabled: true,
        hapticsEnabled: true
    )

    public init(
        schemaVersion: Int = AppData.currentSchemaVersion,
        sessions: [StoredSession] = [],
        lastSettings: LastSettings = LastSettings(),
        knownPlayerNames: [String] = [],
        adsRemoved: Bool = false,
        chaoAnimationEnabled: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.sessions = sessions
        self.lastSettings = lastSettings
        self.knownPlayerNames = knownPlayerNames
        self.adsRemoved = adsRemoved
        self.chaoAnimationEnabled = chaoAnimationEnabled
        self.hapticsEnabled = hapticsEnabled
    }

    public var unfinishedSessions: [StoredSession] {
        sessions
            .filter { !$0.isFinished }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The session the home screen's 「繼續上一場」 button should open, if any.
    public var latestUnfinished: StoredSession? {
        unfinishedSessions.first
    }

    /// Finished sessions, newest first, plus older unfinished ones that are not the latest.
    public var recentSessionsForHome: [StoredSession] {
        sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    public mutating func remember(playerNames: [String], limit: Int = 30) {
        var names = knownPlayerNames
        for name in playerNames.reversed() {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            names.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
            names.insert(trimmed, at: 0)
        }
        if names.count > limit {
            names = Array(names.prefix(limit))
        }
        knownPlayerNames = names
    }
}
