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

    /// The largest answer this operation can produce with operands up to `n` (IMPLEMENTATION.md §4.2).
    public func maxAnswer(_ n: Int) -> Int {
        switch self {
        case .plus: 2 * n
        case .minus: n
        case .times: n * n
        case .divide: n
        }
    }
}
