package dev.sumbee.model

/**
 * One problem, shown as `a op b`. For ÷, [a] is the dividend and [b] the divisor; the quotient is
 * [answer]. Every card has exactly one whole-number answer ≥ 0 (SPEC.md §1.4).
 */
data class Card(val op: Operation, val a: Int, val b: Int) {

    val answer: Int
        get() = when (op) {
            Operation.PLUS -> a + b
            Operation.MINUS -> a - b
            Operation.TIMES -> a * b
            Operation.DIVIDE -> a / b
        }

    val text: String get() = "$a ${op.symbol} $b"

    /** ×0, ×1, +0, −0, a−a, ÷1, a÷a, 0÷b (SPEC.md §1.4). */
    val isTrivial: Boolean
        get() = when (op) {
            Operation.PLUS -> a == 0 || b == 0
            Operation.TIMES -> a <= 1 || b <= 1
            Operation.MINUS -> b == 0 || a == b
            Operation.DIVIDE -> b == 1 || a == b || a == 0
        }

    /** The same card regardless of operand order for + and × (FR-2.5). */
    fun canonical(): Card =
        if ((op == Operation.PLUS || op == Operation.TIMES) && a > b) Card(op, b, a) else this

    /** Same operation, and both operands within 2 of the other card's (FR-2.6). */
    fun isNearTo(other: Card): Boolean {
        if (op != other.op) return false
        return when (op) {
            Operation.PLUS, Operation.TIMES ->
                (close(a, other.a) && close(b, other.b)) || (close(a, other.b) && close(b, other.a))
            Operation.MINUS -> close(a, other.a) && close(b, other.b)
            Operation.DIVIDE -> close(b, other.b) && close(answer, other.answer)
        }
    }

    private fun close(x: Int, y: Int) = kotlin.math.abs(x - y) <= 2
}
