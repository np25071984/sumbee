/// Builds a session's deck (SPEC.md FR-2; IMPLEMENTATION.md §4.1). Pure and deterministic for a given
/// generator, which is how it is tested and how a session survives the app being killed (§3.5).
public enum DeckGenerator {

    /// The rules FR-2.8 relaxes, in order. A deck only ever moves down this list.
    public enum Relaxation: Int, CaseIterable, Comparable, Sendable {
        /// Every rule: look back 3 cards, no repeats, trivial budget.
        case none
        /// FR-2.6 looks back 1 card instead of 3.
        case shortWindow
        /// FR-2.6 dropped.
        case noNearCheck
        /// FR-2.5 dropped, except the same card twice in a row.
        case repeats
        /// FR-2.7 dropped too.
        case noTrivialLimit

        public static func < (lhs: Relaxation, rhs: Relaxation) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public struct Deck: Hashable, Sendable {
        public let cards: [Card]
        public let relaxation: Relaxation
    }

    private static let window = 3

    public static func generate<G: RandomNumberGenerator>(_ config: SessionConfig, using random: inout G) -> Deck {
        let n = config.maxNumber
        let ops = MathOperation.allCases.filter { config.ops.contains($0) }
        let count = config.cardCount
        let trivialBudget = max(1, count / 10)

        var pools: [MathOperation: [Card]] = [:]
        // Unused candidates per op, in random order; a pick removes from here (FR-2.5).
        var unused: [MathOperation: [Card]] = [:]
        for op in ops {
            pools[op] = pool(op, n)
            unused[op] = pools[op]!.shuffled(using: &random)
        }

        var deck: [Card] = []
        deck.reserveCapacity(count)
        var trivialCount = 0
        var level = Relaxation.none

        for op in opSequence(ops, count, using: &random) {
            var picked: Card?
            while picked == nil {
                picked = pick(op, level, deck, &unused[op]!, pools[op]!, trivialCount, trivialBudget, &random)
                if picked == nil { level = Relaxation(rawValue: level.rawValue + 1)! }
            }
            let card = picked!
            // + and × show either operand first, so 4 + 6 and 6 + 4 both turn up over time.
            let shown = (op == .plus || op == .times) && Bool.random(using: &random) ? Card(op, card.b, card.a) : card
            deck.append(shown)
            if card.isTrivial { trivialCount += 1 }
        }
        return Deck(cards: deck, relaxation: level)
    }

    /// Every valid card for `op` at "numbers up to `n`", one per canonical form (FR-2.1–2.3).
    public static func pool(_ op: MathOperation, _ n: Int) -> [Card] {
        let m = op.limit(n)
        var cards: [Card] = []
        switch op {
        case .plus, .times: for a in 0...m { for b in a...m { cards.append(Card(op, a, b)) } }
        case .minus: for a in 0...m { for b in 0...a { cards.append(Card(op, a, b)) } }
        case .divide: for b in 1...m { for q in 0...m { cards.append(Card(op, b * q, b)) } }
        }
        return cards
    }

    /// Which operation each slot gets (FR-2.4): each op ⌊C/k⌋ or ⌈C/k⌉ times, never more than 2 of the
    /// same in a row. Always taking an allowed op with the most left (ties broken at random) guarantees
    /// both when the counts are balanced, as they are here.
    public static func opSequence<G: RandomNumberGenerator>(
        _ ops: [MathOperation], _ count: Int, using random: inout G
    ) -> [MathOperation] {
        var remaining = Array(repeating: count / ops.count, count: ops.count)
        for i in ops.indices.shuffled(using: &random).prefix(count % ops.count) { remaining[i] += 1 }
        var seq: [MathOperation] = []
        seq.reserveCapacity(count)
        for _ in 0..<count {
            let blocked = seq.count >= 2 && seq[seq.count - 1] == seq[seq.count - 2]
            var allowed = ops.indices.filter { remaining[$0] > 0 && !(blocked && ops[$0] == seq.last) }
            if allowed.isEmpty { allowed = ops.indices.filter { remaining[$0] > 0 } } // only one op left: a run is unavoidable
            let most = allowed.map { remaining[$0] }.max()!
            let choice = allowed.filter { remaining[$0] == most }.randomElement(using: &random)!
            remaining[choice] -= 1
            seq.append(ops[choice])
        }
        return seq
    }

    private static func pick<G: RandomNumberGenerator>(
        _ op: MathOperation,
        _ level: Relaxation,
        _ deck: [Card],
        _ unused: inout [Card],
        _ pool: [Card],
        _ trivialCount: Int,
        _ trivialBudget: Int,
        _ random: inout G
    ) -> Card? {
        let last = deck.last
        let window: ArraySlice<Card> = switch level {
        case .none: deck.suffix(Self.window)
        case .shortWindow: deck.suffix(1)
        default: []
        }

        func trivialOk(_ c: Card) -> Bool {
            level == .noTrivialLimit || !c.isTrivial || (trivialCount < trivialBudget && last?.isTrivial != true)
        }

        if level < .repeats {
            guard let i = unused.firstIndex(where: { c in trivialOk(c) && !window.contains { $0.isNear(to: c) } }) else {
                return nil
            }
            return unused.remove(at: i)
        }
        // Repeats allowed: anything from the whole pool except the card just shown.
        let lastCanonical = last?.canonical()
        let candidates = pool.filter { $0 != lastCanonical && trivialOk($0) }
        if !candidates.isEmpty { return candidates.randomElement(using: &random) }
        if level == .noTrivialLimit { return pool.randomElement(using: &random) } // a one-card pool; can't happen for N ≥ 5
        return nil
    }
}
