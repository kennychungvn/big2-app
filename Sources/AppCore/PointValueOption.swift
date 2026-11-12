import Foundation

/// Per-point money options shown in 開場設定.
public enum PointValueOption: Equatable, Sendable {
    case none
    case one
    case two
    case five
    case custom(Decimal)

    public var decimalValue: Decimal? {
        switch self {
        case .none: return nil
        case .one: return 1
        case .two: return 2
        case .five: return 5
        case .custom(let value): return value
        }
    }

    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    public init(decimal: Decimal?) {
        guard let decimal else {
            self = .none
            return
        }
        switch decimal {
        case 1: self = .one
        case 2: self = .two
        case 5: self = .five
        default: self = .custom(decimal)
        }
    }

    /// Preset chips in display order, excluding whatever custom value is current.
    public static let presets: [PointValueOption] = [.none, .one, .two, .five]

    public var chipTitle: String {
        switch self {
        case .none: return "唔計"
        case .one: return "$1"
        case .two: return "$2"
        case .five: return "$5"
        case .custom(let value):
            return "$\(NSDecimalNumber(decimal: value).stringValue)"
        }
    }
}
