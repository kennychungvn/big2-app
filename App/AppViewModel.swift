import Foundation
import Combine
import AppCore
import ScoringEngine

enum AppRoute: Hashable {
    case scoreboard(UUID)
    case final(UUID)
    /// 所有紀錄 list pushed from the home screen.
    case allSessions
}

struct RoundEntrySheet: Identifiable, Equatable {
    let id: UUID
    var mode: Mode
    var state: RoundEntryState

    enum Mode: Equatable {
        case new
        case edit(roundIndex: Int, previousCards: [Int], previousManualDoubles: [Int] = [])
    }

    init(id: UUID = UUID(), mode: Mode, state: RoundEntryState) {
        self.id = id
        self.mode = mode
        self.state = state
    }
}

struct ResultSheet: Identifiable, Equatable {
    let id: UUID
    var round: Round
    var players: [String]
    var totalsAfter: [Int]
    var roundNumber: Int
    var isEdit: Bool
    /// Pairwise sessions show 「贏/輸{name} {n} 張」 under each row.
    var scoringMode: ScoringMode
    var roundIndex: Int?
    /// Opened from the scoreboard history (read-only, no 撤回).
    var isReview: Bool
    /// Rounds in the session after this result, for 「累計 · 打咗 N 局」.
    var roundsCompleted: Int

    init(
        id: UUID = UUID(),
        round: Round,
        players: [String],
        totalsAfter: [Int],
        roundNumber: Int,
        isEdit: Bool,
        roundsCompleted: Int,
        scoringMode: ScoringMode = .winnerTakesAll,
        roundIndex: Int? = nil,
        isReview: Bool = false
    ) {
        self.roundsCompleted = roundsCompleted
        self.scoringMode = scoringMode
        self.roundIndex = roundIndex
        self.isReview = isReview
        self.id = id
        self.round = round
        self.players = players
        self.totalsAfter = totalsAfter
        self.roundNumber = roundNumber
        self.isEdit = isEdit
    }
}

struct UndoWindow: Equatable {
    var expiresAt: Date
    var kind: Kind

    enum Kind: Equatable {
        case addedRound
        case editedRound(index: Int, previousCards: [Int], previousManualDoubles: [Int] = [])
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var model: AppModel
    @Published var path: [AppRoute] = []
    @Published var isPresentingNewSession = false
    @Published var isPresentingSettings = false
    @Published var roundEntry: RoundEntrySheet?
    @Published var resultSheet: ResultSheet?
    @Published var undoWindow: UndoWindow?
    /// True while a full-screen interstitial is up; every BannerSlot hides meanwhile.
    @Published private(set) var isShowingInterstitial = false
    /// Past round opened from the scoreboard history.
    @Published var reviewSheet: ResultSheet?
    @Published var errorMessage: String?
    /// 「移除廣告」 / 「回復購買」 result shown as an alert in Settings.
    @Published var storeAlert: StoreAlert?
    /// True while a purchase or restore is running; disables both buttons.
    @Published private(set) var isStoreBusy = false
    /// Effective 地區介面 (Hong Kong or Taiwan wording).
    @Published private(set) var region: InterfaceRegion = .hongKong
    /// 2.0 skin (`skin` key, default 經典). The skin fixes the look and the app icon:
    /// 經典 dark / primary icon, Ledger light / AppIcon-Ledger.
    @Published private(set) var skin: SkinID = SkinPreferences.loadSkin()

    let store: AppStoring
    let ads: AdManaging
    let shop: StoreManaging
    let reviewPrompt = ReviewPromptStore()
    var format: ScoreFormatting { ScoreFormatting(region: region) }

    /// Set when a session has just been finished, so FinalView can offer a review prompt
    /// on that appearance only (not when opening a past 完場 from history).
    private var pendingReviewPromptSessionID: UUID?

    private var undoTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var lastCommitted: (cards: [Int], sheetID: UUID)?

    init(
        store: AppStoring,
        ads: AdManaging = MockAdManager(),
        shop: StoreManaging = StubStoreManager()
    ) {
        self.store = store
        self.ads = ads
        self.shop = shop
        var loadFailed = false
        do {
            self.model = AppModel(data: try store.load())
        } catch {
            self.model = AppModel()
            loadFailed = true
        }
        // v1.1: 0-round sessions are never listed; clear the ones older builds saved.
        if !loadFailed, self.model.purgeEmptySessions() > 0 {
            try? store.save(self.model.data)
        }
        refreshRegion()
        if loadFailed {
            self.errorMessage = tr("存檔讀唔到，已經用空白資料重新開始。")
        }
        self.reviewPrompt.seedIfNeeded(existingFinishedSessionCount: Self.finishedPlayableCount(in: self.model))
        self.ads.adsRemoved = self.model.data.adsRemoved
        MotionSettings.enabled = self.model.data.chaoAnimationEnabled
        if !self.model.data.adsRemoved {
            self.ads.preloadInterstitial()
        }
    }

    var showBanner: Bool { !model.data.adsRemoved }

    func persist() {
        do {
            try store.save(model.data)
        } catch {
            errorMessage = tr("儲存失敗，請稍後再試。")
        }
        ads.adsRemoved = model.data.adsRemoved
        MotionSettings.enabled = model.data.chaoAnimationEnabled
    }

    /// Consumes the one-shot flag for this settlement appearance. Returns false for history visits and UI tests.
    func consumePendingReviewPrompt(for sessionID: UUID) -> Bool {
        guard pendingReviewPromptSessionID == sessionID else { return false }
        pendingReviewPromptSessionID = nil
        if UITestSupport.isActive { return false }
        return true
    }

    func isReviewPromptEligible() -> Bool {
        !isShowingInterstitial && reviewPrompt.shouldRequestReview(currentVersion: Self.marketingVersion)
    }

    func markReviewPromptShown() {
        reviewPrompt.recordPromptShown(for: Self.marketingVersion)
    }

    static var marketingVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func finishedPlayableCount(in model: AppModel) -> Int {
        model.data.sessions.filter { $0.isFinished && $0.session.roundsCompleted >= 1 }.count
    }

    // MARK: - Sessions

    func startSession(from draft: NewSessionDraft) {
        do {
            let stored = try model.startNewSession(
                players: draft.names,
                chaoTable: draft.chaoTable,
                scoringMode: AppFlavor.current.isTaiwanApp ? draft.scoringMode : region.defaultScoringMode
            )
            persist()
            isPresentingNewSession = false
            path = [.scoreboard(stored.id)]
        } catch AppModelError.emptyPlayerName {
            errorMessage = tr("要填齊 4 個玩家名先開到")
        } catch {
            errorMessage = tr("開唔到場，請檢查資料。")
        }
    }

    func continueUnfinished() {
        do {
            let stored = try model.continueUnfinished()
            path = [.scoreboard(stored.id)]
        } catch {
            errorMessage = tr("搵唔到上一場。")
        }
    }

    /// - Parameter push: `true` from 所有紀錄, so back returns to the list instead of home.
    func openSession(_ stored: StoredSession, push: Bool = false) {
        do {
            try model.openSession(stored.id)
            let route: AppRoute = stored.isFinished ? .final(stored.id) : .scoreboard(stored.id)
            if push {
                path.append(route)
            } else {
                path = [route]
            }
        } catch {
            errorMessage = tr("開唔到呢場。")
        }
    }

    /// Swipe-to-delete in 所有紀錄 / long-press on 最近場次, after the confirm alert.
    func deleteSession(_ id: UUID) {
        do {
            try model.deleteSession(id)
            path.removeAll { route in
                switch route {
                case .scoreboard(let routeID), .final(let routeID): return routeID == id
                case .allSessions: return false
                }
            }
            persist()
        } catch {
            errorMessage = tr("刪除失敗，請稍後再試。")
        }
    }

    func goHome() {
        pendingReviewPromptSessionID = nil
        roundEntry = nil
        resultSheet = nil
        model.closeCurrentSession()
        path = []
    }

    /// Called after the 完場 confirm. May show one skippable interstitial first
    /// (see `AppModel.shouldShowFinishInterstitial`).
    func finishCurrentSession() async {
        if model.shouldShowFinishInterstitial() {
            _ = await presentInterstitial()
            model.recordInterstitialShown()
            if !model.data.adsRemoved {
                ads.preloadInterstitial()
            }
        }
        do {
            try model.finishCurrentSession()
            if let session = model.currentSession, session.session.roundsCompleted >= 1 {
                reviewPrompt.recordFinishedGame()
                pendingReviewPromptSessionID = session.id
            }
            persist()
            if let id = model.currentSessionID {
                path = [.final(id)]
            }
        } catch {
            errorMessage = tr("完場失敗。")
        }
    }

    private func presentInterstitial() async -> Bool {
        isShowingInterstitial = true
        defer { isShowingInterstitial = false }
        return await ads.showInterstitialIfReady()
    }

    // MARK: - Round entry

    func startEnteringRound() async {
        guard let current = model.currentSession, !current.isFinished else { return }
        if model.shouldShowInterstitial() {
            _ = await presentInterstitial()
            model.recordInterstitialShown()
            persist()
            if !model.data.adsRemoved {
                ads.preloadInterstitial()
            }
        }
        lastCommitted = nil
        roundEntry = RoundEntrySheet(
            mode: .new,
            state: RoundEntryState(
                rule: current.session.rule,
                requiresConfirm: AppFlavor.current.isTaiwanApp
            )
        )
    }

    func editRound(at index: Int) {
        guard let session = model.currentSession?.session,
              session.rounds.indices.contains(index) else { return }
        let cards = session.rounds[index].scores.map(\.cardsLeft)
        let doubles = session.rounds[index].scores.map(\.manualDoubles)
        lastCommitted = nil
        roundEntry = RoundEntrySheet(
            mode: .edit(roundIndex: index, previousCards: cards, previousManualDoubles: doubles),
            state: RoundEntryState(
                rule: session.rule,
                prefill: cards,
                prefillManualDoubles: doubles,
                requiresConfirm: AppFlavor.current.isTaiwanApp
            )
        )
    }

    /// Scoreboard history tap: shows that round's result (with the pairwise breakdown);
    /// 編輯 from there opens the entry screen.
    func reviewRound(at index: Int) {
        guard let session = model.currentSession?.session,
              session.rounds.indices.contains(index) else { return }
        var totals = Array(repeating: 0, count: session.players.count)
        for round in session.rounds[...index] {
            for (i, p) in round.points.enumerated() where i < totals.count { totals[i] += p }
        }
        reviewSheet = ResultSheet(
            round: session.rounds[index],
            players: session.players,
            totalsAfter: totals,
            roundNumber: index + 1,
            isEdit: false,
            roundsCompleted: index + 1,
            scoringMode: session.scoringMode,
            roundIndex: index,
            isReview: true
        )
    }

    func editFromReview() {
        guard let index = reviewSheet?.roundIndex else { return }
        reviewSheet = nil
        Task { @MainActor [weak self] in
            // Let the review sheet finish dismissing before presenting the entry cover.
            try? await Task.sleep(nanoseconds: 450_000_000)
            self?.editRound(at: index)
        }
    }

    func cancelRoundEntry() {
        resultTask?.cancel()
        resultSheet = nil
        roundEntry = nil
    }

    func handleEntryChange() {
        guard let sheet = roundEntry, sheet.state.justCompleted,
              let cards = sheet.state.completeCards else { return }
        if lastCommitted?.cards == cards, lastCommitted?.sheetID == sheet.id {
            return
        }
        lastCommitted = (cards, sheet.id)
        commit(cards: cards, manualDoubles: sheet.state.completeManualDoubles, mode: sheet.mode)
    }

    private func commit(cards: [Int], manualDoubles: [Int]?, mode: RoundEntrySheet.Mode) {
        do {
            let round: Round
            let isEdit: Bool
            let undoKind: UndoWindow.Kind
            switch mode {
            case .new:
                round = try model.addRound(cardsLeft: cards, manualDoubles: manualDoubles)
                isEdit = false
                undoKind = .addedRound
            case .edit(let index, let previous, let previousDoubles):
                round = try model.editRound(at: index, cardsLeft: cards, manualDoubles: manualDoubles)
                isEdit = true
                undoKind = .editedRound(index: index, previousCards: previous, previousManualDoubles: previousDoubles)
            }
            persist()
            guard let current = model.currentSession else { return }
            let sheet = ResultSheet(
                round: round,
                players: current.session.players,
                totalsAfter: current.session.totals,
                roundNumber: {
                    switch mode {
                    case .new: return current.session.roundsCompleted
                    case .edit(let index, _, _): return index + 1
                    }
                }(),
                isEdit: isEdit,
                roundsCompleted: current.session.roundsCompleted,
                scoringMode: current.session.scoringMode,
                roundIndex: {
                    switch mode {
                    case .new: return current.session.roundsCompleted - 1
                    case .edit(let index, _, _): return index
                    }
                }()
            )
            resultSheet = sheet
            // 撤回 stays available for as long as the result sheet is open (no auto-dismiss).
            startUndoWindow(kind: undoKind, duration: nil)
        } catch {
            errorMessage = tr("計分失敗，請檢查入咗嘅牌。")
        }
    }

    func editFromResult() {
        resultTask?.cancel()
        resultSheet = nil
        undoTask?.cancel()
        undoWindow = nil
        guard var sheet = roundEntry else { return }
        if case .new = sheet.mode, let current = model.currentSession {
            let index = current.session.roundsCompleted - 1
            let cards = current.session.rounds[index].scores.map(\.cardsLeft)
            let doubles = current.session.rounds[index].scores.map(\.manualDoubles)
            sheet.mode = .edit(roundIndex: index, previousCards: cards, previousManualDoubles: doubles)
        }
        roundEntry = sheet
    }

    /// 「下一局」: closes the result sheet. 撤回 stays on the scoreboard for 5 more seconds.
    func dismissResult() {
        resultTask?.cancel()
        resultSheet = nil
        roundEntry = nil
        if let kind = undoWindow?.kind {
            startUndoWindow(kind: kind, duration: 5)
        }
    }

    func performUndo() {
        guard let window = undoWindow else { return }
        do {
            switch window.kind {
            case .addedRound:
                _ = try model.undoLastRound()
            case .editedRound(let index, let previous, let previousDoubles):
                _ = try model.editRound(at: index, cardsLeft: previous, manualDoubles: previousDoubles)
            }
            persist()
        } catch {
            errorMessage = tr("撤回失敗。")
        }
        clearUndo()
        resultSheet = nil
        roundEntry = nil
    }

    /// `duration == nil` keeps the window open until it is replaced or cleared.
    private func startUndoWindow(kind: UndoWindow.Kind, duration: TimeInterval?) {
        undoTask?.cancel()
        guard let duration else {
            undoWindow = UndoWindow(expiresAt: .distantFuture, kind: kind)
            return
        }
        let expires = Date().addingTimeInterval(duration)
        undoWindow = UndoWindow(expiresAt: expires, kind: kind)
        undoTask = Task { [weak self] in
            let nanos = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.undoWindow?.expiresAt == expires else { return }
                self?.undoWindow = nil
            }
        }
    }

    private func clearUndo() {
        undoTask?.cancel()
        undoWindow = nil
    }

    // MARK: - Settings / IAP

    func purchaseRemoveAds() async {
        guard !isStoreBusy else { return }
        isStoreBusy = true
        defer { isStoreBusy = false }
        let result: Result<Bool, Error>
        do {
            result = .success(try await shop.purchaseRemoveAds())
        } catch {
            result = .failure(error)
        }
        if case .success(true) = result {
            model.setAdsRemoved(true)
            persist()
        }
        // Success is shown by the 「已經移除廣告」 label; cancelling stays silent.
        if let feedback = StoreFeedback.purchase(result), feedback != .purchased {
            storeAlert = StoreAlert(feedback)
        }
    }

    func restorePurchases() async {
        guard !isStoreBusy else { return }
        isStoreBusy = true
        defer { isStoreBusy = false }
        let result: Result<Bool, Error>
        do {
            result = .success(try await shop.restorePurchases())
        } catch {
            result = .failure(error)
        }
        if case .success(true) = result {
            model.setAdsRemoved(true)
            persist()
        }
        storeAlert = StoreAlert(StoreFeedback.restore(result))
    }

    /// StoreKit reported the 移除廣告 entitlement (launch check, Ask to Buy, another device)
    /// or its revocation (refund). Persisted so ads stay hidden offline.
    func applyStoreEntitlement(_ entitled: Bool) {
        guard model.data.adsRemoved != entitled else { return }
        model.setAdsRemoved(entitled)
        persist()
        if !entitled {
            ads.preloadInterstitial()
        }
    }

    func syncPurchasesFromStore() {
        if shop.adsRemoved && !model.data.adsRemoved {
            model.setAdsRemoved(true)
            persist()
        }
    }

    func setSkin(_ newSkin: SkinID) {
        guard newSkin != skin else { return }
        SkinTransition.crossfade(animated: model.data.chaoAnimationEnabled, haptics: model.data.hapticsEnabled) {
            self.skin = newSkin
            SkinWindowStyle.apply(newSkin)
        }
        SkinPreferences.save(skin: newSkin)
        // After the 250 ms crossfade; iOS shows its own "icon changed" alert
        // only when the icon actually changes.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            AppIconSwitcher.apply(newSkin)
        }
    }

    func setChaoAnimationEnabled(_ enabled: Bool) {
        model.setChaoAnimationEnabled(enabled)
        persist()
    }

    // MARK: - 地區介面

    /// Re-reads the setting and device locale, then points string lookups at that region.
    func refreshRegion() {
        let resolved: InterfaceRegion
        if AppFlavor.current.isTaiwanApp {
            resolved = .taiwan
        } else {
            resolved = model.data.interfaceRegion(
                systemRegion: L10n.systemRegion,
                taiwanEnabled: L10n.taiwanEnabled
            )
        }
        L10n.region = resolved
        if region != resolved {
            region = resolved
        }
    }

    func setDefaultScoringMode(_ mode: ScoringMode) {
        guard AppFlavor.current.isTaiwanApp else { return }
        var settings = model.data.lastSettings
        settings.scoringMode = mode
        model.data.lastSettings = settings
        persist()
    }

    func setDefaultChaoTable(_ table: ChaoTable) {
        guard AppFlavor.current.isTaiwanApp else { return }
        var settings = model.data.lastSettings
        settings.chaoTable = table
        model.data.lastSettings = settings
        persist()
    }

    func setRegionPreference(_ preference: InterfaceRegionPreference) {
        guard L10n.taiwanEnabled else { return }
        model.setInterfaceRegionPreference(preference, systemRegion: L10n.systemRegion)
        persist()
        refreshRegion()
    }

    func setHapticsEnabled(_ enabled: Bool) {
        model.setHapticsEnabled(enabled)
        persist()
    }

    func removeKnownPlayerName(_ name: String) {
        model.removeKnownPlayerName(name)
        persist()
    }

    func removeKnownPlayerNames(at offsets: IndexSet) {
        model.removeKnownPlayerNames(at: offsets)
        persist()
    }

    func moveKnownPlayerNames(from source: IndexSet, to destination: Int) {
        model.moveKnownPlayerNames(from: source, to: destination)
        persist()
    }
}
