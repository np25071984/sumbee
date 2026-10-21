/// The four operations (SPEC.md §1.4). `symbol` is what a card shows: never `*` or `/` (FR-3.1).
public enum MathOperation: String, CaseIterable, Codable, Sendable {
    case plus = "PLUS"
    case minus = "MINUS"
    case times = "TIMES"
    case divide = "DIVIDE"

    public var symbol: String {
        switch self {
        case .plus: "+"
        case .minus: "−"
        case .times: "×"
        case .divide: "÷"
        }
    }

    public static let tableMax = 12

    /// The largest operand at "numbers up to `n`" (FR-2.1): `n` for + and −, but × and ÷ stop at the
    /// times tables, `tableMax`, so a young child's N = 20 never deals 12 × 16. For ÷ it bounds the
    /// divisor and the quotient.
    public func limit(_ n: Int) -> Int {
        switch self {
        case .plus, .minus: n
        case .times, .divide: min(n, Self.tableMax)
        }
    }

    /// The largest answer this operation can produce at "numbers up to `n`" (IMPLEMENTATION.md §4.2).
    public func maxAnswer(_ n: Int) -> Int {
        switch self {
        case .plus: 2 * n
        case .minus: n
        case .times: limit(n) * limit(n)
        case .divide: limit(n)
        }
    }
}
