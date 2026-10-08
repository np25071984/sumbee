package dev.sumbee.model

import kotlin.random.Random

/**
 * Builds a session's deck (SPEC.md FR-2; IMPLEMENTATION.md §4.1). Pure and deterministic for a
 * given [Random], which is how it is tested and how a session survives process death (§3.5).
 */
object DeckGenerator {

    /** The rules FR-2.8 relaxes, in order. A deck only ever moves down this list. */
    enum class Relaxation {
        /** Every rule: look back 3 cards, no repeats, trivial budget. */
        NONE,
        /** FR-2.6 looks back 1 card instead of 3. */
        SHORT_WINDOW,
        /** FR-2.6 dropped. */
        NO_NEAR_CHECK,
        /** FR-2.5 dropped, except the same card twice in a row. */
        REPEATS,
        /** FR-2.7 dropped too. */
        NO_TRIVIAL_LIMIT,
    }

    data class Deck(val cards: List<Card>, val relaxation: Relaxation)

    private const val WINDOW = 3

    fun generate(config: SessionConfig, random: Random): Deck {
        val n = config.maxNumber
        val ops = Operation.entries.filter { it in config.ops }
        val count = config.cardCount
        val trivialBudget = maxOf(1, count / 10)

        val pools = ops.associateWith { pool(it, n) }
        // Unused candidates per op, in random order; a pick removes from here (FR-2.5).
        val unused = pools.mapValues { (_, cards) -> cards.shuffled(random).toMutableList() }

        val deck = ArrayList<Card>(count)
        var trivialCount = 0
        var level = Relaxation.NONE

        for (op in opSequence(ops, count, random)) {
            var picked: Card? = null
            while (picked == null) {
                picked = pick(op, level, deck, unused.getValue(op), pools.getValue(op), trivialCount, trivialBudget, random)
                if (picked == null) level = Relaxation.entries[level.ordinal + 1]
            }
            // + and × show either operand first, so 4 + 6 and 6 + 4 both turn up over time.
            val shown = if ((op == Operation.PLUS || op == Operation.TIMES) && random.nextBoolean()) {
                Card(op, picked.b, picked.a)
            } else picked
            deck += shown
            if (picked.isTrivial) trivialCount++
        }
        return Deck(deck, level)
    }

    /** Every valid card for [op] with operands up to [n], one per canonical form (FR-2.1–2.3). */
    fun pool(op: Operation, n: Int): List<Card> {
        val cards = ArrayList<Card>()
        when (op) {
            Operation.PLUS, Operation.TIMES -> for (a in 0..n) for (b in a..n) cards += Card(op, a, b)
            Operation.MINUS -> for (a in 0..n) for (b in 0..a) cards += Card(op, a, b)
            Operation.DIVIDE -> for (b in 1..n) for (q in 0..n) cards += Card(op, b * q, b)
        }
        return cards
    }

    /**
     * Which operation each slot gets (FR-2.4): each op ⌊C/k⌋ or ⌈C/k⌉ times, never more than 2 of
     * the same in a row. Always taking an allowed op with the most left (ties broken at random)
     * guarantees both when the counts are balanced, as they are here.
     */
    fun opSequence(ops: List<Operation>, count: Int, random: Random): List<Operation> {
        val remaining = IntArray(ops.size) { count / ops.size }
        ops.indices.shuffled(random).take(count % ops.size).forEach { remaining[it]++ }
        val seq = ArrayList<Operation>(count)
        repeat(count) {
            val blocked = seq.size >= 2 && seq[seq.size - 1] == seq[seq.size - 2]
            val allowed = ops.indices.filter { remaining[it] > 0 && !(blocked && ops[it] == seq.last()) }
                .ifEmpty { ops.indices.filter { remaining[it] > 0 } } // only one op left: a run is unavoidable
            val most = allowed.maxOf { remaining[it] }
            val choice = allowed.filter { remaining[it] == most }.random(random)
            remaining[choice]--
            seq += ops[choice]
        }
        return seq
    }

    private fun pick(
        op: Operation,
        level: Relaxation,
        deck: List<Card>,
        unused: MutableList<Card>,
        pool: List<Card>,
        trivialCount: Int,
        trivialBudget: Int,
        random: Random,
    ): Card? {
        val last = deck.lastOrNull()
        val window = when (level) {
            Relaxation.NONE -> deck.takeLast(WINDOW)
            Relaxation.SHORT_WINDOW -> deck.takeLast(1)
            else -> emptyList()
        }

        fun trivialOk(c: Card) = level == Relaxation.NO_TRIVIAL_LIMIT ||
            !c.isTrivial || (trivialCount < trivialBudget && last?.isTrivial != true)

        if (level < Relaxation.REPEATS) {
            val i = unused.indexOfFirst { c -> trivialOk(c) && window.none { it.isNearTo(c) } }
            return if (i >= 0) unused.removeAt(i) else null
        }
        // Repeats allowed: anything from the whole pool except the card just shown.
        val lastCanonical = last?.canonical()
        val candidates = pool.filter { it != lastCanonical && trivialOk(it) }
        return when {
            candidates.isNotEmpty() -> candidates.random(random)
            level == Relaxation.NO_TRIVIAL_LIMIT -> pool.random(random) // a one-card pool; can't happen for N ≥ 10
            else -> null
        }
    }
}
