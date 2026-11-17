import Foundation

/// What Settings should tell the user after 「移除廣告」 or 「回復購買」.
/// The app target turns each case into a Cantonese alert (`AppViewModel.storeAlert`).
public enum StoreFeedback: Equatable, Sendable {
    case purchased
    case purchaseFailed(StoreError)
    case restored
    case nothingToRestore
    case restoreFailed(StoreError)

    /// `nil` means stay silent (the user cancelled).
    public static func purchase(_ result: Result<Bool, Error>) -> StoreFeedback? {
        switch result {
        case .success(true):
            return .purchased
        case .success(false):
            return .purchaseFailed(.purchaseFailed)
        case .failure(let error):
            let storeError = StoreError(error)
            return storeError == .cancelled ? nil : .purchaseFailed(storeError)
        }
    }

    /// Restore always answers: found, not found, or an error (a cancelled sign-in included,
    /// so the user is never left wondering whether anything happened).
    public static func restore(_ result: Result<Bool, Error>) -> StoreFeedback {
        switch result {
        case .success(true):
            return .restored
        case .success(false):
            return .nothingToRestore
        case .failure(let error):
            return .restoreFailed(StoreError(error))
        }
    }
}

extension StoreError {
    /// Wraps any error as a `StoreError`, keeping a readable description of non-store errors.
    public init(_ error: Error) {
        if let storeError = error as? StoreError {
            self = storeError
        } else {
            self = .storeKit(StoreError.describe(error))
        }
    }

    /// "Type.case: localized description" (e.g. "StoreKitError.networkError(…): The network
    /// connection was lost."), so a screenshot of the alert says what actually failed.
    public static func describe(_ error: Error) -> String {
        let type = String(describing: Swift.type(of: error))
        let value = String(describing: error)
        let localized = (error as NSError).localizedDescription
        let head = value.hasPrefix(type) ? value : "\(type).\(value)"
        if localized.isEmpty || head.contains(localized) {
            return head
        }
        return "\(head): \(localized)"
    }
}

/// Runs `operation` but stops waiting after `seconds`, throwing `StoreError.timedOut`.
/// The operation is NOT cancelled on timeout: a StoreKit purchase that is still in flight can
/// finish later and grant the entitlement itself. The caller just gets its UI back.
public enum StoreTimeout {
    public static func run<T: Sendable>(
        seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let gate = ResumeGate<T>()
        return try await withCheckedThrowingContinuation { continuation in
            gate.install(continuation)
            Task {
                do {
                    gate.resume(with: .success(try await operation()))
                } catch {
                    gate.resume(with: .failure(error))
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
                gate.resume(with: .failure(StoreError.timedOut))
            }
        }
    }
}

/// Resumes a continuation exactly once (first of operation / timeout wins).
private final class ResumeGate<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    func install(_ continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func resume(with result: Result<T, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
