import Foundation

/// Everything Setup chooses (SPEC.md FR-1), and what is remembered between runs (FR-1.6).
public struct SessionConfig: Hashable, Codable, Sendable {
    public var name: String
    public var maxNumber: Int
    public var ops: Set<MathOperation>
    public var cardCount: Int

    public init(
        name: String = "",
        maxNumber: Int = SessionConfig.defaultMax,
        ops: Set<MathOperation> = [.plus],
        cardCount: Int = SessionConfig.defaultCount
    ) {
        self.name = name
        self.maxNumber = maxNumber
        self.ops = ops
        self.cardCount = cardCount
    }

    /// Keypad input stops at this many digits (FR-3.2).
    public var maxDigits: Int {
        String(ops.map { $0.maxAnswer(maxNumber) }.max() ?? maxNumber).count
    }

    /// Brings any stored or restored value back inside what Setup can choose.
    public func sanitized() -> SessionConfig {
        SessionConfig(
            name: Self.sanitizeName(name),
            maxNumber: min(max(maxNumber, Self.minMax), Self.maxMax) / Self.maxStep * Self.maxStep,
            ops: ops.isEmpty ? [.plus] : ops,
            cardCount: Self.cardCounts.contains(cardCount) ? cardCount : Self.defaultCount
        )
    }

    public static let minMax = 5
    public static let maxMax = 100
    public static let maxStep = 5
    public static let defaultMax = 20
    public static let cardCounts = [25, 50, 75, 100]
    public static let defaultCount = 25
    public static let maxNameLength = 20

    /// Letters of any script, spaces, hyphens and apostrophes, at most 20 characters (FR-1.1).
    public static func filterName(_ raw: String) -> String {
        String(raw.filter { $0.isLetter || $0 == " " || $0 == "-" || $0 == "'" || $0 == "’" }.prefix(maxNameLength))
    }

    public static func sanitizeName(_ raw: String) -> String {
        filterName(raw).trimmingCharacters(in: .whitespaces)
    }
}
