import AppCore

enum LegalCopy {
    /// Hong Kong disclaimer, also quoted in the README and docs/terms.md.
    static let hongKong = "呢個 app 淨係用嚟記分，唔涉及任何賭博或金錢交易。"
    /// Taiwan disclaimer (台灣華語).
    static let taiwan = "這個 App 只用來記分，不涉及任何賭博或金錢交易。"

    static func disclaimer(for region: InterfaceRegion) -> String {
        switch region {
        case .hongKong: return hongKong
        case .taiwan: return taiwan
        }
    }

    /// Disclaimer for the current 地區介面.
    static var disclaimer: String { disclaimer(for: L10n.region) }
}
