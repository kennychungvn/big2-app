import Foundation
import Combine
import AppCore
import ScoringEngine

enum AppRoute: Hashable {
    case scoreboard(UUID)
    case final(UUID)
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
    var moneyAfter: [Decimal]?
    var roundNumber: Int
    var isEdit: Bool

    init(
        id: UUID = UUID(),
        round: Round,
        players: [String],
        totalsAfter: [Int],
        moneyAfter: [Decimal]?,
        roundNumber: Int,
        isEdit: Bool
    ) {
        self.id = id
        self.round = round
        self.players = players
        self.totalsAfter = totalsAfter
        self.moneyAfter = moneyAfter
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
    @Published var errorMessage: String?
    @Published var storeMessage: String?

    let store: AppStoring
    let ads: AdManaging
    let shop: StoreManaging
    let format = ScoreFormatting()
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
        do {
            self.model = AppModel(data: try store.load())
        } catch {
            self.model = AppModel()
            self.errorMessage = "存檔讀唔到，已經用空白資料重新開始。"
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
            errorMessage = "儲存失敗，請稍後再試。"
        }
        ads.adsRemoved = model.data.adsRemoved
    }

    // MARK: - Sessions

    func startSession(from draft: NewSessionDraft) {
        do {
            let stored = try model.startNewSession(
                players: draft.names,
                preset: draft.preset,
                pointValue: draft.resolvedPointValue
            )
            persist()
            isPresentingNewSession = false
            path = [.scoreboard(stored.id)]
        } catch AppModelError.emptyPlayerName {
            errorMessage = "四個玩家都要填名。"
        } catch AppModelError.invalidCustomPointValue {
            errorMessage = "自訂每分幾錢要大於 0。"
        } catch {
            errorMessage = "開唔到場，請檢查資料。"
        }
    }

    func continueUnfinished() {
        do {
            let stored = try model.continueUnfinished()
            path = [.scoreboard(stored.id)]
        } catch {
            errorMessage = "搵唔到上一場。"
        }
    }

    func openSession(_ stored: StoredSession) {
        do {
            try model.openSession(stored.id)
            if stored.isFinished {
                path = [.final(stored.id)]
            } else {
                path = [.scoreboard(stored.id)]
            }
        } catch {
            errorMessage = "開唔到呢場。"
        }
    }

    func goHome() {
        roundEntry = nil
        resultSheet = nil
        model.closeCurrentSession()
        path = []
    }

    func finishCurrentSession() {
        do {
            try model.finishCurrentSession()
            persist()
            if let id = model.currentSessionID {
                path = [.final(id)]
            }
        } catch {
            errorMessage = "完場失敗。"
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
                moneyAfter: current.session.moneyTotals,
                roundNumber: {
                    switch mode {
                    case .new: return current.session.roundsCompleted
                    case .edit(let index, _): return index + 1
                    }
                }(),
                isEdit: isEdit
            )
            resultSheet = sheet
            startUndoWindow(kind: undoKind)
            startResultAutoDismiss(id: sheet.id)
        } catch {
            errorMessage = "計分失敗，請檢查入咗嘅牌。"
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

    func dismissResult() {
        resultTask?.cancel()
        resultSheet = nil
        roundEntry = nil
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
            errorMessage = "撤回失敗。"
        }
        clearUndo()
        resultSheet = nil
        roundEntry = nil
    }

    private func startUndoWindow(kind: UndoWindow.Kind, duration: TimeInterval = 5) {
        undoTask?.cancel()
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

    private func startResultAutoDismiss(id: UUID, duration: TimeInterval = 3) {
        resultTask?.cancel()
        resultTask = Task { [weak self] in
            let nanos = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.resultSheet?.id == id else { return }
                self?.dismissResult()
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
                storeMessage = "已經移除廣告，多謝支持！"
            }
        } catch StoreError.cancelled {
            storeMessage = nil
        } catch StoreError.productNotFound {
            storeMessage = "暫時未設定 App Store 商品（product id：\(StoreProduct.removeAdsProductID)），上架前再接。"
        } catch StoreError.purchasePending {
            storeMessage = "購買等候批准，稍後會自動生效。"
        } catch {
            storeMessage = "購買失敗，請稍後再試或用「恢復購買」。"
        }
    }

    func restorePurchases() async {
        storeMessage = nil
        do {
            let ok = try await shop.restorePurchases()
            if ok {
                model.setAdsRemoved(true)
                persist()
                storeMessage = "已經恢復購買，廣告已移除。"
            } else {
                storeMessage = "搵唔到之前嘅購買記錄。"
            }
        } catch {
            storeMessage = "恢復購買失敗，請稍後再試。"
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

    func setHapticsEnabled(_ enabled: Bool) {
        model.setHapticsEnabled(enabled)
        persist()
    }
}
