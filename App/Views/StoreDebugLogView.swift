import SwiftUI
import UIKit
import AppCore

/// Hidden 「購買紀錄 (debug)」 screen: long-press the version number in 設定.
/// Lists the last StoreKit events (StoreEventLog) so a tester can copy and send them.
/// Not localised on purpose (debug only).
struct StoreDebugLogView: View {
    @Environment(\.appTheme) private var theme
    @State private var events: [StoreEvent] = []
    @State private var copied = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        List {
            Section {
                Button {
                    UIPasteboard.general.string = StoreEventLog.shared.exportText(
                        header: "鋤大D計分 store log · \(StoreKitStoreManager.environmentSummary)"
                    )
                    copied = true
                } label: {
                    Text(verbatim: copied ? "已複製" : "複製全部")
                }
                .foregroundColor(Color(theme.accentLink))
                .accessibilityIdentifier("storeLog.copy")

                Button(role: .destructive) {
                    StoreEventLog.shared.clear()
                    reload()
                } label: {
                    Text(verbatim: "清除紀錄")
                }
            } footer: {
                Text(verbatim: StoreKitStoreManager.environmentSummary)
            }

            Section {
                if events.isEmpty {
                    Text(verbatim: "未有紀錄")
                        .foregroundColor(Color(theme.secondaryText))
                } else {
                    ForEach(Array(events.enumerated().reversed()), id: \.offset) { _, event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: Self.timeFormatter.string(from: event.date))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(theme.secondaryText))
                            Text(verbatim: event.message)
                                .font(.system(size: 13, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text(verbatim: "最新喺最上（最多 \(StoreEventLog.defaultLimit) 條）")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(theme.background).ignoresSafeArea())
        .navigationTitle(Text(verbatim: "購買紀錄 (debug)"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    private func reload() {
        events = StoreEventLog.shared.events
        copied = false
    }
}
