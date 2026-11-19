import Foundation

/// One StoreKit diagnostic event (product load, purchase start / result, restore, errors).
public struct StoreEvent: Codable, Equatable, Sendable {
    public let date: Date
    public let message: String

    public init(date: Date = Date(), message: String) {
        self.date = date
        self.message = message
    }
}

/// Ring log of the last `limit` StoreKit events, kept in `UserDefaults` so it survives a
/// relaunch. Shown on the hidden 「購買紀錄 (debug)」 screen (long-press the version in 設定)
/// so a tester can copy exactly what StoreKit answered on their device.
/// Never stores passwords, receipts or transaction JWS, only short status lines.
public final class StoreEventLog: @unchecked Sendable {
    public static let defaultKey = "storeEventLog.v1"
    public static let defaultLimit = 30
    /// Longest message kept (a full StoreKit error description fits comfortably).
    public static let maxMessageLength = 600

    public static let shared = StoreEventLog()

    private let defaults: UserDefaults
    private let key: String
    public let limit: Int
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = StoreEventLog.defaultKey, limit: Int = StoreEventLog.defaultLimit) {
        self.defaults = defaults
        self.key = key
        self.limit = max(1, limit)
    }

    /// Oldest first.
    public var events: [StoreEvent] {
        lock.lock(); defer { lock.unlock() }
        return load()
    }

    public func append(_ message: String, date: Date = Date()) {
        let trimmed = message.count > Self.maxMessageLength
            ? String(message.prefix(Self.maxMessageLength)) + "…"
            : message
        lock.lock(); defer { lock.unlock() }
        var all = load()
        all.append(StoreEvent(date: date, message: trimmed))
        if all.count > limit {
            all.removeFirst(all.count - limit)
        }
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: key)
        }
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    /// Plain text for the copy button: one "yyyy-MM-dd HH:mm:ss ZZZZZ  message" line per event.
    public func exportText(header: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        var lines: [String] = []
        if let header { lines.append(header) }
        lines += events.map { "\(formatter.string(from: $0.date))  \($0.message)" }
        return lines.joined(separator: "\n")
    }

    private func load() -> [StoreEvent] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([StoreEvent].self, from: data) else { return [] }
        return decoded
    }
}
