import Foundation

public protocol AppStoring: AnyObject {
    func load() throws -> AppData
    func save(_ data: AppData) throws
}

public enum PersistenceError: Error, Equatable, Sendable {
    case unreadableFile
}

/// In-memory store used by unit tests.
public final class InMemoryStore: AppStoring {
    public var data: AppData

    public init(data: AppData = .empty) {
        self.data = data
    }

    public func load() throws -> AppData { data }

    public func save(_ data: AppData) throws {
        self.data = data
    }
}

/// Codable JSON file store. Atomic replace so a crash mid-write cannot leave a half file.
public final class JSONFileStore: AppStoring {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() throws -> AppData {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        do {
            return try decoder.decode(AppData.self, from: data)
        } catch {
            throw PersistenceError.unreadableFile
        }
    }

    public func save(_ data: AppData) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoded = try encoder.encode(data)
        let tempURL = directory.appendingPathComponent(".\(fileURL.lastPathComponent).tmp")
        if fileManager.fileExists(atPath: tempURL.path) {
            try fileManager.removeItem(at: tempURL)
        }
        try encoded.write(to: tempURL, options: .atomic)
        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: fileURL)
        }
    }
}
