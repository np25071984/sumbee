package dev.sumbee.model

/** The four operations (SPEC.md §1.4). [symbol] is what a card shows: never `*` or `/` (FR-3.1). */
enum class Operation(val symbol: String) {
    PLUS("+"),
    MINUS("−"),
    TIMES("×"),
    DIVIDE("÷");

    /**
     * The largest operand at "numbers up to [n]" (FR-2.1): [n] for + and −, but × and ÷ stop at the
     * times tables, [TABLE_MAX], so a young child's N = 20 never deals 12 × 16. For ÷ it bounds the
     * divisor and the quotient.
     */
    fun limit(n: Int): Int = when (this) {
        PLUS, MINUS -> n
        TIMES, DIVIDE -> minOf(n, TABLE_MAX)
    }

    /** The largest answer this operation can produce at "numbers up to [n]" (IMPLEMENTATION.md §4.2). */
    fun maxAnswer(n: Int): Int = when (this) {
        PLUS -> 2 * n
        MINUS -> n
        TIMES -> limit(n) * limit(n)
        DIVIDE -> limit(n)
    }

    companion object {
        const val TABLE_MAX = 12
    }
}
