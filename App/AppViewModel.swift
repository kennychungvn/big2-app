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
        case edit(roundIndex: Int, previousCards: [Int])
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
        case editedRound(index: Int, previousCards: [Int])
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
    /// Past round opened from the scoreboard history.
    @Published var reviewSheet: ResultSheet?
    @Published var errorMessage: String?
    @Published var storeMessage: String?
    /// Effective 地區介面 (Hong Kong or Taiwan wording).
    @Published private(set) var region: InterfaceRegion = .hongKong

    let store: AppStoring
    let ads: AdManaging
    let shop: StoreManaging
    var format: ScoreFormatting { ScoreFormatting(region: region) }
    let theme: Theme = .neighbourhood

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
        refreshRegion()
        if loadFailed {
            self.errorMessage = tr("存檔讀唔到，已經用空白資料重新開始。")
        }
        self.ads.adsRemoved = self.model.data.adsRemoved
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
    }

    // MARK: - Sessions

    func startSession(from draft: NewSessionDraft) {
        do {
            let stored = try model.startNewSession(
                players: draft.names,
                chaoTable: draft.chaoTable,
                scoringMode: region.defaultScoringMode
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

    func goHome() {
        roundEntry = nil
        resultSheet = nil
        model.closeCurrentSession()
        path = []
    }

    /// Called after the 完場 confirm. May show one skippable interstitial first
    /// (see `AppModel.shouldShowFinishInterstitial`).
    func finishCurrentSession() async {
        if model.shouldShowFinishInterstitial() {
            _ = await ads.showInterstitialIfReady()
            model.recordInterstitialShown()
            if !model.data.adsRemoved {
                ads.preloadInterstitial()
            }
        }
        do {
            try model.finishCurrentSession()
            persist()
            if let id = model.currentSessionID {
                path = [.final(id)]
            }
        } catch {
            errorMessage = tr("完場失敗。")
        }
    }

    // MARK: - Round entry

    func startEnteringRound() async {
        guard let current = model.currentSession, !current.isFinished else { return }
        if model.shouldShowInterstitial() {
            _ = await ads.showInterstitialIfReady()
            model.recordInterstitialShown()
            persist()
            if !model.data.adsRemoved {
                ads.preloadInterstitial()
            }
        }
        lastCommitted = nil
        roundEntry = RoundEntrySheet(
            mode: .new,
            state: RoundEntryState(rule: current.session.rule)
        )
    }

    func editRound(at index: Int) {
        guard let session = model.currentSession?.session,
              session.rounds.indices.contains(index) else { return }
        let cards = session.rounds[index].scores.map(\.cardsLeft)
        lastCommitted = nil
        roundEntry = RoundEntrySheet(
            mode: .edit(roundIndex: index, previousCards: cards),
            state: RoundEntryState(rule: session.rule, prefill: cards)
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
        commit(cards: cards, mode: sheet.mode)
    }

    private func commit(cards: [Int], mode: RoundEntrySheet.Mode) {
        do {
            let round: Round
            let isEdit: Bool
            let undoKind: UndoWindow.Kind
            switch mode {
            case .new:
                round = try model.addRound(cardsLeft: cards)
                isEdit = false
                undoKind = .addedRound
            case .edit(let index, let previous):
                round = try model.editRound(at: index, cardsLeft: cards)
                isEdit = true
                undoKind = .editedRound(index: index, previousCards: previous)
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
                    case .edit(let index, _): return index + 1
                    }
                }(),
                isEdit: isEdit,
                roundsCompleted: current.session.roundsCompleted,
                scoringMode: current.session.scoringMode,
                roundIndex: {
                    switch mode {
                    case .new: return current.session.roundsCompleted - 1
                    case .edit(let index, _): return index
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
            sheet.mode = .edit(roundIndex: index, previousCards: cards)
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
            case .editedRound(let index, let previous):
                _ = try model.editRound(at: index, cardsLeft: previous)
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
        storeMessage = nil
        do {
            let ok = try await shop.purchaseRemoveAds()
            if ok {
                model.setAdsRemoved(true)
                persist()
                storeMessage = tr("已經移除廣告，多謝支持！")
            }
        } catch StoreError.cancelled {
            storeMessage = nil
        } catch StoreError.productNotFound {
            storeMessage = tr("暫時未設定 App Store 商品（product id：%@），上架前再接。", StoreProduct.removeAdsProductID)
        } catch StoreError.purchasePending {
            storeMessage = tr("購買等候批准，稍後會自動生效。")
        } catch {
            storeMessage = tr("購買失敗，請稍後再試或用「恢復購買」。")
        }
    }

    func restorePurchases() async {
        storeMessage = nil
        do {
            let ok = try await shop.restorePurchases()
            if ok {
                model.setAdsRemoved(true)
                persist()
                storeMessage = tr("已經恢復購買，廣告已移除。")
            } else {
                storeMessage = tr("搵唔到之前嘅購買記錄。")
            }
        } catch {
            storeMessage = tr("恢復購買失敗，請稍後再試。")
        }
    }

    func syncPurchasesFromStore() {
        if shop.adsRemoved && !model.data.adsRemoved {
            model.setAdsRemoved(true)
            persist()
        }
    }

    func setChaoAnimationEnabled(_ enabled: Bool) {
        model.setChaoAnimationEnabled(enabled)
        persist()
    }

    // MARK: - 地區介面

    /// Re-reads the setting and device locale, then points string lookups at that region.
    func refreshRegion() {
        let resolved = model.data.interfaceRegion(
            systemRegion: L10n.systemRegion,
            taiwanEnabled: L10n.taiwanEnabled
        )
        L10n.region = resolved
        if region != resolved {
            region = resolved
        }
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
}
