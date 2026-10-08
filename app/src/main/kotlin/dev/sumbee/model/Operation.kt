package dev.sumbee.model

/** The four operations (SPEC.md §1.4). [symbol] is what a card shows: never `*` or `/` (FR-3.1). */
enum class Operation(val symbol: String) {
    PLUS("+"),
    MINUS("−"),
    TIMES("×"),
    DIVIDE("÷");

    /** The largest answer this operation can produce with operands up to [n] (IMPLEMENTATION.md §4.2). */
    fun maxAnswer(n: Int): Int = when (this) {
        PLUS -> 2 * n
        MINUS -> n
        TIMES -> n * n
        DIVIDE -> n
    }
}
