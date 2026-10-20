package dev.sumbee.model

/** Everything Setup chooses (SPEC.md FR-1), and what is remembered between runs (FR-1.6). */
data class SessionConfig(
    val name: String = "",
    val maxNumber: Int = DEFAULT_MAX,
    val ops: Set<Operation> = setOf(Operation.PLUS),
    val cardCount: Int = DEFAULT_COUNT,
) {
    /** Keypad input stops at this many digits (FR-3.2). */
    val maxDigits: Int get() = ops.maxOf { it.maxAnswer(maxNumber) }.toString().length

    /** Brings any stored or restored value back inside what Setup can choose. */
    fun sanitized(): SessionConfig = copy(
        name = sanitizeName(name),
        maxNumber = (maxNumber.coerceIn(MIN_MAX, MAX_MAX) / MAX_STEP) * MAX_STEP,
        ops = ops.ifEmpty { setOf(Operation.PLUS) },
        cardCount = if (cardCount in CARD_COUNTS) cardCount else DEFAULT_COUNT,
    )

    companion object {
        const val MIN_MAX = 5
        const val MAX_MAX = 100
        const val MAX_STEP = 5
        const val DEFAULT_MAX = 20
        val CARD_COUNTS = listOf(25, 50, 75, 100)
        const val DEFAULT_COUNT = 25
        const val MAX_NAME_LENGTH = 20

        /** Letters of any script, spaces, hyphens and apostrophes, at most 20 characters (FR-1.1). */
        fun filterName(raw: String): String =
            raw.filter { it.isLetter() || it == ' ' || it == '-' || it == '\'' || it == '’' }
                .take(MAX_NAME_LENGTH)

        fun sanitizeName(raw: String): String = filterName(raw).trim()
    }
}
