import Foundation
import AppCore

/// Alert for a 「移除廣告」 / 「回復購買」 result: a Cantonese message, plus the underlying
/// StoreKit error text when there is one (so a screenshot says what actually failed).
struct StoreAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    init(_ feedback: StoreFeedback) {
        switch feedback {
        case .purchased:
            title = tr("已經移除廣告")
            message = tr("已經移除廣告，多謝支持！")
        case .restored:
            title = tr("已回復購買")
            message = tr("已經回復購買，廣告已移除。")
        case .nothingToRestore:
            title = tr("搵唔到之前嘅購買")
            message = tr("呢個 Apple 帳戶未買過「移除廣告」。如果你用另一個 Apple 帳戶買過，請喺「設定」轉返嗰個帳戶再試。")
        case .purchaseFailed(let error):
            title = tr("購買失敗")
            message = Self.body(Self.purchaseText(error), error)
        case .restoreFailed(let error):
            title = tr("回復購買失敗")
            message = Self.body(Self.restoreText(error), error)
        }
    }

    private static func purchaseText(_ error: StoreError) -> String {
        switch error {
        case .productNotFound:
            return tr("App Store 搵唔到「移除廣告」呢件商品（product id：%@）。可能你個 Apple 帳戶所在地區未有發售，請稍後再試。", StoreProduct.removeAdsProductID)
        case .purchasePending:
            return tr("購買等候批准，稍後會自動生效。")
        case .unverified:
            return tr("App Store 交易驗證唔到，今次冇扣款都冇移除廣告。請稍後再試或用「回復購買」。")
        case .timedOut:
            return tr("App Store 好耐都冇回應。如果之後買成功，廣告會自動移除；冇嘅話請稍後再試。")
        case .busy:
            return tr("上一個購買仲處理緊，請等一陣。")
        case .cancelled, .purchaseFailed, .storeKit:
            return tr("購買失敗，請稍後再試或用「回復購買」。")
        }
    }

    private static func restoreText(_ error: StoreError) -> String {
        switch error {
        case .cancelled:
            return tr("未登入 Apple 帳戶，回復購買已取消。")
        case .timedOut:
            return tr("App Store 好耐都冇回應，請稍後再試。")
        case .busy:
            return tr("上一個購買仲處理緊，請等一陣。")
        default:
            return tr("回復購買失敗，請稍後再試。")
        }
    }

    private static func body(_ text: String, _ error: StoreError) -> String {
        let detail = error.detail ?? (error == .purchasePending || error == .busy ? nil : String(describing: error))
        guard let detail else { return text }
        return text + "\n\n" + tr("錯誤：%@", detail)
    }
}
