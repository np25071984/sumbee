/// One problem, shown as `a op b`. For ÷, `a` is the dividend and `b` the divisor; the quotient is
/// `answer`. Every card has exactly one whole-number answer ≥ 0 (SPEC.md §1.4).
public struct Card: Hashable, Codable, Sendable, CustomStringConvertible {
    public let op: MathOperation
    public let a: Int
    public let b: Int

    public init(_ op: MathOperation, _ a: Int, _ b: Int) {
        self.op = op
        self.a = a
        self.b = b
    }

    public var answer: Int {
        switch op {
        case .plus: a + b
        case .minus: a - b
        case .times: a * b
        case .divide: a / b
        }
    }

    public var text: String { "\(a) \(op.symbol) \(b)" }

    public var description: String { text }

    /// ×0, ×1, +0, −0, a−a, ÷1, a÷a, 0÷b (SPEC.md §1.4).
    public var isTrivial: Bool {
        switch op {
        case .plus: a == 0 || b == 0
        case .times: a <= 1 || b <= 1
        case .minus: b == 0 || a == b
        case .divide: b == 1 || a == b || a == 0
        }
    }

    /// The same card regardless of operand order for + and × (FR-2.5).
    public func canonical() -> Card {
        (op == .plus || op == .times) && a > b ? Card(op, b, a) : self
    }

    /// Same operation, and both operands within 2 of the other card's (FR-2.6).
    public func isNear(to other: Card) -> Bool {
        guard op == other.op else { return false }
        switch op {
        case .plus, .times:
            return (close(a, other.a) && close(b, other.b)) || (close(a, other.b) && close(b, other.a))
        case .minus:
            return close(a, other.a) && close(b, other.b)
        case .divide:
            return close(b, other.b) && close(answer, other.answer)
        }
    }

    private func close(_ x: Int, _ y: Int) -> Bool { abs(x - y) <= 2 }
}
