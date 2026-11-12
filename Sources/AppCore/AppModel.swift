import Foundation
import ScoringEngine

public enum AppModelError: Error, Equatable, Sendable {
    case emptyPlayerName(index: Int)
    case noCurrentSession
    case sessionNotFound(UUID)
}

/// All session / settings mutations the screens need, free of SwiftUI and Combine.
public struct AppModel: Equatable, Sendable {
    public var data: AppData
    public var currentSessionID: UUID?

    public init(data: AppData = .empty, currentSessionID: UUID? = nil) {
        self.data = data
        self.currentSessionID = currentSessionID
    }

    public var currentSession: StoredSession? {
        guard let currentSessionID else { return nil }
        return data.sessions.first(where: { $0.id == currentSessionID })
    }

    public var latestUnfinished: StoredSession? {
        data.latestUnfinished
    }

    public var recentSessions: [StoredSession] {
        data.recentSessionsForHome
    }

    public mutating func startNewSession(
        players: [String],
        preset: RulePreset,
        clock: any Clock = SystemClock()
    ) throws -> StoredSession {
        let names = try Self.validatedNames(players)
        let session = try Session(players: names, rule: preset.rule)
        let now = clock.now
        let stored = StoredSession(session: session, createdAt: now, updatedAt: now)
        data.sessions.append(stored)
        data.lastSettings = LastSettings(playerNames: names, rulePreset: preset)
        data.remember(playerNames: names)
        currentSessionID = stored.id
        return stored
    }

    public mutating func openSession(_ id: UUID) throws {
        guard data.sessions.contains(where: { $0.id == id }) else {
            throw AppModelError.sessionNotFound(id)
        }
        currentSessionID = id
    }

    @discardableResult
    public mutating func continueUnfinished() throws -> StoredSession {
        guard let latest = data.latestUnfinished else {
            throw AppModelError.noCurrentSession
        }
        currentSessionID = latest.id
        return latest
    }

    public mutating func closeCurrentSession() {
        currentSessionID = nil
    }

    @discardableResult
    public mutating func addRound(
        cardsLeft: [Int],
        heldTwo: [Bool]? = nil,
        clock: any Clock = SystemClock()
    ) throws -> Round {
        try mutateCurrent(clock: clock) { session in
            try session.addRound(cardsLeft: cardsLeft, heldTwo: heldTwo)
        }
    }

    @discardableResult
    public mutating func undoLastRound(clock: any Clock = SystemClock()) throws -> Round {
        try mutateCurrent(clock: clock) { session in
            try session.undoLastRound()
        }
    }

    @discardableResult
    public mutating func editRound(
        at index: Int,
        cardsLeft: [Int],
        heldTwo: [Bool]? = nil,
        clock: any Clock = SystemClock()
    ) throws -> Round {
        try mutateCurrent(clock: clock) { session in
            try session.editRound(at: index, cardsLeft: cardsLeft, heldTwo: heldTwo)
        }
    }

    public mutating func finishCurrentSession(clock: any Clock = SystemClock()) throws {
        let now = clock.now
        let id = try requireCurrentID()
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else {
            throw AppModelError.sessionNotFound(id)
        }
        data.sessions[index].endedAt = now
        data.sessions[index].updatedAt = now
    }

    public func shouldShowInterstitial(clock: any Clock = SystemClock()) -> Bool {
        guard !data.adsRemoved else { return false }
        guard let session = currentSession?.session else { return false }
        return session.shouldShowInterstitial(
            beforeStartingRound: session.roundsCompleted + 1,
            clock: clock
        )
    }

    public mutating func recordInterstitialShown(clock: any Clock = SystemClock()) {
        guard currentSessionID != nil else { return }
        do {
            try mutateCurrent(clock: clock) { session in
                session.recordInterstitialShown(clock: clock)
            }
        } catch {
            return
        }
    }

    /// Draft for 新開一場 in `region`. Someone who has never started a session gets the
    /// region's default table (香港炒 or 台灣常見); otherwise the remembered preset is kept,
    /// mapped to the region's list.
    public func newSessionDraft(region: InterfaceRegion) -> NewSessionDraft {
        var draft = NewSessionDraft(from: data.lastSettings, region: region)
        if data.sessions.isEmpty {
            draft.preset = region.defaultRulePreset
        }
        return draft
    }

    /// Saves the 地區介面 setting. When the effective region changes and the remembered preset is
    /// still the old region's default, it switches to the new region's default.
    public mutating func setInterfaceRegionPreference(
        _ preference: InterfaceRegionPreference,
        systemRegion: InterfaceRegion
    ) {
        let oldRegion = data.interfaceRegion(systemRegion: systemRegion)
        data.interfaceRegionPreference = preference
        let newRegion = data.interfaceRegion(systemRegion: systemRegion)
        guard oldRegion != newRegion else { return }
        let remembered = data.lastSettings.rulePreset
        if remembered == oldRegion.defaultRulePreset {
            data.lastSettings.rulePreset = newRegion.defaultRulePreset
        } else {
            data.lastSettings.rulePreset = remembered.equivalent(in: newRegion)
        }
    }

    public mutating func setAdsRemoved(_ removed: Bool) {
        data.adsRemoved = removed
    }

    public mutating func setChaoAnimationEnabled(_ enabled: Bool) {
        data.chaoAnimationEnabled = enabled
    }

    public mutating func setHapticsEnabled(_ enabled: Bool) {
        data.hapticsEnabled = enabled
    }

    public func historyRows() -> [RoundHistoryRow] {
        guard let rounds = currentSession?.session.rounds else { return [] }
        return rounds.enumerated().map { RoundHistoryRow(index: $0.offset, round: $0.element) }
            .reversed()
    }

    public static func validatedNames(_ players: [String]) throws -> [String] {
        var names: [String] = []
        for (index, raw) in players.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw AppModelError.emptyPlayerName(index: index)
            }
            names.append(trimmed)
        }
        guard names.count == ScoringEngine.playerCount else {
            throw ScoringError.wrongPlayerCount(
                expected: ScoringEngine.playerCount,
                actual: names.count
            )
        }
        return names
    }

    /// Name chips that are not already filled in the four fields.
    public func availableNameChips(for currentFields: [String]) -> [String] {
        let filled = Set(
            currentFields
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { $0.lowercased() }
        )
        return data.knownPlayerNames.filter { !filled.contains($0.lowercased()) }
    }

    @discardableResult
    private mutating func mutateCurrent<T>(
        clock: any Clock,
        _ body: (inout Session) throws -> T
    ) throws -> T {
        let id = try requireCurrentID()
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else {
            throw AppModelError.sessionNotFound(id)
        }
        let result = try body(&data.sessions[index].session)
        data.sessions[index].updatedAt = clock.now
        return result
    }

    private func requireCurrentID() throws -> UUID {
        guard let currentSessionID else { throw AppModelError.noCurrentSession }
        return currentSessionID
    }
}
