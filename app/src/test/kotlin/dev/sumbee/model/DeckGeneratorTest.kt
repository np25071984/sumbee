package dev.sumbee.model

import dev.sumbee.model.DeckGenerator.Relaxation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** SPEC.md FR-2, over the matrix IMPLEMENTATION.md §5 names. */
class DeckGeneratorTest {

    private val ranges = listOf(10, 15, 20, 50, 100)
    private val counts = SessionConfig.CARD_COUNTS
    private val opSets: List<Set<Operation>> = (1 until 16).map { mask ->
        Operation.entries.filterIndexed { i, _ -> mask and (1 shl i) != 0 }.toSet()
    }

    @Test
    fun everyDeckHonoursTheRulesItsRelaxationLevelPromises() {
        var decks = 0
        for (n in ranges) for (ops in opSets) for (count in counts) {
            val seeds = if (n == 100) 3 else 8
            for (seed in 0 until seeds) {
                val config = SessionConfig(maxNumber = n, ops = ops, cardCount = count)
                val deck = DeckGenerator.generate(config, Random(seed))
                checkDeck(config, deck, "n=$n ops=$ops count=$count seed=$seed")
                decks++
            }
        }
        assertTrue(decks > 1000)
    }

    private fun checkDeck(config: SessionConfig, deck: DeckGenerator.Deck, what: String) {
        val cards = deck.cards
        val n = config.maxNumber
        assertEquals("size $what", config.cardCount, cards.size)

        // FR-2.1–2.3: never relaxed.
        for (c in cards) {
            assertTrue("op $c $what", c.op in config.ops)
            when (c.op) {
                Operation.PLUS, Operation.TIMES -> assertTrue("bounds $c $what", c.a in 0..n && c.b in 0..n)
                Operation.MINUS -> assertTrue("bounds $c $what", c.a in 0..n && c.b in 0..c.a)
                Operation.DIVIDE -> {
                    assertTrue("divisor $c $what", c.b in 1..n)
                    assertEquals("whole $c $what", 0, c.a % c.b)
                    assertTrue("quotient $c $what", c.answer in 0..n)
                }
            }
            assertTrue("negative $c $what", c.answer >= 0)
        }

        // FR-2.4: balance, and no run longer than 2 with two or more ops.
        val k = config.ops.size
        for (op in config.ops) {
            val times = cards.count { it.op == op }
            assertTrue("balance $op=$times $what", times == config.cardCount / k || times == (config.cardCount + k - 1) / k)
        }
        if (k >= 2) {
            for (i in 2 until cards.size) {
                assertFalse("run at $i $what", cards[i].op == cards[i - 1].op && cards[i].op == cards[i - 2].op)
            }
        }

        // Never the same card twice in a row, at any level.
        for (i in 1 until cards.size) assertNotEquals("back-to-back at $i $what", cards[i - 1].canonical(), cards[i].canonical())

        if (deck.relaxation < Relaxation.REPEATS) {
            assertEquals("repeat $what", cards.size, cards.map { it.canonical() }.toSet().size)
        }
        if (deck.relaxation < Relaxation.NO_TRIVIAL_LIMIT) {
            val budget = maxOf(1, config.cardCount / 10)
            assertTrue("trivial budget $what", cards.count { it.isTrivial } <= budget)
            for (i in 1 until cards.size) assertFalse("trivial pair $i $what", cards[i].isTrivial && cards[i - 1].isTrivial)
        }
        val window = when (deck.relaxation) {
            Relaxation.NONE -> 3
            Relaxation.SHORT_WINDOW -> 1
            else -> 0
        }
        for (i in cards.indices) for (j in maxOf(0, i - window) until i) {
            assertFalse("near ${cards[j]} → ${cards[i]} $what", cards[i].isNearTo(cards[j]))
        }
    }

    @Test
    fun ordinaryDecksNeedNoRelaxation() {
        for (seed in 0 until 50) {
            for (config in listOf(
                SessionConfig(maxNumber = 20, ops = setOf(Operation.PLUS), cardCount = 25),
                SessionConfig(maxNumber = 20, ops = setOf(Operation.PLUS, Operation.MINUS), cardCount = 50),
                SessionConfig(maxNumber = 50, ops = Operation.entries.toSet(), cardCount = 100),
            )) {
                assertEquals("$config seed=$seed", Relaxation.NONE, DeckGenerator.generate(config, Random(seed)).relaxation)
            }
        }
    }

    @Test
    fun tinyPoolsStillFillTheDeck() {
        // Only 66 distinct + cards exist up to 10 (FR-2.8's example).
        val config = SessionConfig(maxNumber = 10, ops = setOf(Operation.PLUS), cardCount = 100)
        val deck = DeckGenerator.generate(config, Random(7))
        assertEquals(100, deck.cards.size)
        assertTrue(deck.relaxation >= Relaxation.REPEATS)
    }

    @Test
    fun sameSeedSameDeck() {
        val config = SessionConfig(maxNumber = 30, ops = Operation.entries.toSet(), cardCount = 75)
        assertEquals(DeckGenerator.generate(config, Random(99)), DeckGenerator.generate(config, Random(99)))
    }

    @Test
    fun nearNeighboursMatchTheSpecExamples() {
        fun plus(a: Int, b: Int) = Card(Operation.PLUS, a, b)
        assertTrue(plus(6, 4).isNearTo(plus(6, 5)))
        assertTrue(plus(6, 4).isNearTo(plus(7, 3)))
        assertTrue(plus(6, 4).isNearTo(plus(5, 7)))
        assertFalse(plus(6, 4).isNearTo(plus(13, 7)))
        assertFalse(plus(6, 4).isNearTo(Card(Operation.TIMES, 6, 5)))
        // ÷ compares divisor with divisor and quotient with quotient.
        assertTrue(Card(Operation.DIVIDE, 24, 6).isNearTo(Card(Operation.DIVIDE, 35, 7)))
        assertFalse(Card(Operation.DIVIDE, 24, 6).isNearTo(Card(Operation.DIVIDE, 90, 9)))
    }

    @Test
    fun trivialCardsMatchTheSpecList() {
        val trivial = listOf(
            Card(Operation.TIMES, 7, 0), Card(Operation.TIMES, 1, 9), Card(Operation.PLUS, 0, 5),
            Card(Operation.MINUS, 8, 0), Card(Operation.MINUS, 6, 6), Card(Operation.DIVIDE, 9, 1),
            Card(Operation.DIVIDE, 7, 7), Card(Operation.DIVIDE, 0, 4),
        )
        trivial.forEach { assertTrue("$it", it.isTrivial) }
        listOf(Card(Operation.TIMES, 2, 3), Card(Operation.MINUS, 9, 4), Card(Operation.DIVIDE, 12, 3))
            .forEach { assertFalse("$it", it.isTrivial) }
    }

    @Test
    fun largestDeckIsQuick() {
        // FR-7 budgets 50 ms on a low-end phone; on a dev machine's JVM it should be far under.
        val config = SessionConfig(maxNumber = 100, ops = Operation.entries.toSet(), cardCount = 100)
        repeat(5) { DeckGenerator.generate(config, Random(it)) } // warm up
        val start = System.nanoTime()
        repeat(20) { DeckGenerator.generate(config, Random(100 + it)) }
        val avgMs = (System.nanoTime() - start) / 20 / 1_000_000.0
        assertTrue("average $avgMs ms", avgMs < 20)
    }
}
