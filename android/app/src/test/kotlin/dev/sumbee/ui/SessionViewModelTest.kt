package dev.sumbee.ui

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import dev.sumbee.data.SettingsStore
import dev.sumbee.model.Operation
import dev.sumbee.model.SessionConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SessionViewModelTest {

    private class FakeStore(initial: SessionConfig = SessionConfig()) : SettingsStore {
        val saved = MutableStateFlow(initial)
        override val config: Flow<SessionConfig> = saved
        override suspend fun save(config: SessionConfig) { saved.value = config }
    }

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun vmTest(
        store: FakeStore = FakeStore(SessionConfig(name = "Jenny", maxNumber = 20, cardCount = 25)),
        handle: SavedStateHandle = SavedStateHandle(),
        body: suspend TestScope.(SessionViewModel) -> Unit,
    ) = runTest {
        var seed = 41L
        val vm = SessionViewModel(handle, store, { testScheduler.currentTime }, { ++seed })
        try {
            runCurrent()
            body(vm)
        } finally {
            vm.viewModelScope.cancel()
        }
    }

    private fun SessionViewModel.cards() = state.value as UiState.Cards

    private fun SessionViewModel.type(n: Int) = n.toString().forEach { digit(it.digitToInt()) }

    /** A wrong answer that still fits the keypad's digit limit. */
    private fun wrong(answer: Int) = if (answer == 0) 1 else answer - 1

    private fun TestScope.answerAllCorrectly(vm: SessionViewModel) {
        while (vm.state.value is UiState.Cards) {
            vm.type(vm.cards().card.answer)
            vm.submit()
            advanceTimeBy(SessionViewModel.CORRECT_MS + 1)
            runCurrent()
        }
    }

    @Test
    fun setupShowsTheRememberedSettings() = vmTest { vm ->
        assertEquals("Jenny", (vm.state.value as UiState.Setup).config.name)
    }

    @Test
    fun startSavesSettingsAndDealsTheDeck() = vmTest(FakeStore()) { vm ->
        vm.setName("Sam")
        vm.toggleOp(Operation.TIMES)
        vm.setCardCount(50)
        vm.start()
        runCurrent()
        val s = vm.cards()
        assertEquals(50, s.total)
        assertEquals(0, s.index)
        assertEquals("Sam", s.name)
    }

    @Test
    fun theLastOperationCannotBeTurnedOff() = vmTest { vm ->
        vm.toggleOp(Operation.PLUS)
        assertEquals(setOf(Operation.PLUS), (vm.state.value as UiState.Setup).config.ops)
    }

    @Test
    fun correctAnswerMovesOn() = vmTest { vm ->
        vm.start()
        vm.type(vm.cards().card.answer)
        vm.submit()
        assertEquals(Feedback.CORRECT, vm.cards().feedback)
        advanceTimeBy(SessionViewModel.CORRECT_MS + 1)
        runCurrent()
        assertEquals(1, vm.cards().index)
        assertEquals(1, vm.cards().correct)
        assertEquals("", vm.cards().input)
    }

    @Test
    fun wrongThenRightCountsAsCorrect() = vmTest { vm ->
        vm.start()
        val answer = vm.cards().card.answer
        vm.type(wrong(answer))
        vm.submit()
        assertEquals(Feedback.NUDGE, vm.cards().feedback)
        assertEquals(0, vm.cards().index)
        vm.delete(); vm.delete(); vm.delete()
        vm.type(answer)
        vm.submit()
        advanceTimeBy(SessionViewModel.CORRECT_MS + 1)
        runCurrent()
        assertEquals(1, vm.cards().index)
        assertEquals(1, vm.cards().correct)
    }

    @Test
    fun wrongTwiceRevealsAndCountsWrong() = vmTest { vm ->
        vm.start()
        val answer = vm.cards().card.answer
        vm.type(wrong(answer))
        vm.submit()
        vm.submit() // unchanged answer, second attempt is final
        assertEquals(Feedback.REVEAL, vm.cards().feedback)
        vm.digit(5) // ignored while the answer shows
        assertEquals(wrong(answer).toString(), vm.cards().input)
        advanceTimeBy(SessionViewModel.REVEAL_MS + 1)
        runCurrent()
        assertEquals(1, vm.cards().index)
        assertEquals(0, vm.cards().correct)
    }

    @Test
    fun inputStopsAtTheDigitLimit() = vmTest { vm ->
        vm.start() // + up to 20: answers have at most 2 digits
        vm.digit(1); vm.digit(2); vm.digit(3)
        assertEquals("12", vm.cards().input)
        vm.delete(); vm.delete()
        vm.digit(0); vm.digit(7)
        assertEquals("7", vm.cards().input)
    }

    @Test
    fun emptyAnswerCannotBeSubmitted() = vmTest { vm ->
        vm.start()
        vm.submit()
        assertEquals(Feedback.NONE, vm.cards().feedback)
    }

    @Test
    fun fullSessionEndsOnResults() = vmTest { vm ->
        vm.start()
        answerAllCorrectly(vm)
        val r = vm.state.value as UiState.Results
        assertEquals(25, r.correct)
        assertEquals(25, r.total)
        assertEquals("Jenny", r.name)
    }

    @Test
    fun playAgainDealsANewDeckStraightAway() = vmTest { vm ->
        vm.start()
        val first = vm.cards().deck
        answerAllCorrectly(vm)
        advanceTimeBy(30_000)
        vm.playAgain()
        val s = vm.cards()
        assertEquals(0, s.index)
        assertEquals(0, s.correct)
        assertEquals("Jenny", s.name)
        assertEquals(25, s.total)
        assertTrue("a different deck", s.deck != first)
        runCurrent()
        assertEquals("the clock starts over", 0, vm.seconds.value)
    }

    @Test
    fun playAgainOnlyWorksFromResults() = vmTest { vm ->
        vm.playAgain()
        assertTrue(vm.state.value is UiState.Setup)
    }

    @Test
    fun oneBackShowsTheHintAndKeepsTheSession() = vmTest { vm ->
        vm.start()
        vm.digit(1)
        assertTrue(vm.back())
        assertTrue(vm.cards().exitArmed)
        assertEquals("1", vm.cards().input)
        advanceTimeBy(SessionViewModel.EXIT_WINDOW_MS + 1)
        runCurrent()
        assertFalse(vm.cards().exitArmed)
    }

    @Test
    fun twoQuickBacksLeave() = vmTest { vm ->
        vm.start()
        vm.back()
        advanceTimeBy(1000)
        vm.back()
        assertTrue(vm.state.value is UiState.Setup)
    }

    @Test
    fun twoSlowBacksDoNotLeave() = vmTest { vm ->
        vm.start()
        vm.back()
        advanceTimeBy(3000)
        runCurrent()
        vm.back()
        assertTrue(vm.state.value is UiState.Cards)
        assertTrue(vm.cards().exitArmed)
    }

    @Test
    fun backOnResultsGoesStraightToSetup() = vmTest { vm ->
        vm.start()
        answerAllCorrectly(vm)
        assertTrue(vm.back())
        assertTrue(vm.state.value is UiState.Setup)
    }

    @Test
    fun backOnSetupIsLeftToTheSystem() = vmTest { vm ->
        assertFalse(vm.back())
    }

    @Test
    fun clockPausesWhileHidden() = vmTest { vm ->
        vm.start()
        advanceTimeBy(5_000)
        vm.onHidden()
        advanceTimeBy(60_000)
        vm.onVisible()
        advanceTimeBy(5_000)
        runCurrent()
        assertEquals(10, vm.seconds.value)
    }

    @Test
    fun aSessionSurvivesProcessDeath() {
        val handle = SavedStateHandle()
        sessionSurvivesProcessDeath(handle)
    }

    private fun sessionSurvivesProcessDeath(handle: SavedStateHandle) = vmTest(handle = handle) { vm ->
        vm.start()
        repeat(3) {
            vm.type(vm.cards().card.answer)
            vm.submit()
            advanceTimeBy(SessionViewModel.CORRECT_MS + 1)
            runCurrent()
        }
        val before = vm.cards()
        vm.type(wrong(before.card.answer))
        vm.submit() // nudged
        vm.onHidden()

        // A fresh process gets back only what was saved.
        val savedHandle = SavedStateHandle(handle.keys().associateWith { handle.get<Any>(it) })
        val restored = SessionViewModel(savedHandle, FakeStore(), { testScheduler.currentTime }, { 0L })
        try {
            runCurrent()
            val after = restored.cards()
            assertEquals(before.index, after.index)
            assertEquals(before.card, after.card)
            assertEquals(before.deck, after.deck)
            assertEquals(3, after.correct)
            assertEquals(2, after.attempt)
            assertEquals(Feedback.NUDGE, after.feedback)
        } finally {
            restored.viewModelScope.cancel()
        }
    }
}
