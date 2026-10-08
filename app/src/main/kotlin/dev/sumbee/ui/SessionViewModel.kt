package dev.sumbee.ui

import android.app.Application
import android.os.SystemClock
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import dev.sumbee.data.SettingsRepository
import dev.sumbee.data.SettingsStore
import dev.sumbee.model.Card
import dev.sumbee.model.DeckGenerator
import dev.sumbee.model.Operation
import dev.sumbee.model.SessionConfig
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.random.Random

enum class Feedback { NONE, CORRECT, NUDGE, REVEAL }

/** One screen, three states (SPEC.md FR-6.1; IMPLEMENTATION.md §3.1). */
sealed interface UiState {
    data class Setup(val config: SessionConfig) : UiState

    data class Cards(
        val deck: List<Card>,
        val index: Int,
        val input: String,
        val attempt: Int,
        val feedback: Feedback,
        val correct: Int,
        val name: String,
        val maxDigits: Int,
        /** FR-3.6: Back was pressed once in the last 2 s; the next press leaves. */
        val exitArmed: Boolean = false,
    ) : UiState {
        val card: Card get() = deck[index]
        val total: Int get() = deck.size

        /** The card is decided and the next one is on its way: input is ignored (§3.3). */
        val busy: Boolean get() = feedback == Feedback.CORRECT || feedback == Feedback.REVEAL
    }

    data class Results(val name: String, val correct: Int, val total: Int, val elapsedMs: Long) : UiState
}

class SessionViewModel(
    private val handle: SavedStateHandle,
    private val settings: SettingsStore,
    private val clock: () -> Long,
    private val newSeed: () -> Long = { Random.nextLong() },
) : ViewModel() {

    private val _state = MutableStateFlow<UiState>(UiState.Setup(SessionConfig()))
    val state: StateFlow<UiState> = _state.asStateFlow()

    /** The running clock in whole seconds, apart from [state] so a tick redraws only the timer (§3.4). */
    private val _seconds = MutableStateFlow(0)
    val seconds: StateFlow<Int> = _seconds.asStateFlow()

    private var config = SessionConfig()
    private var seed = 0L
    private var setupEdited = false

    private var accumulatedMs = 0L
    private var runningSince: Long? = null
    private var visible = true
    private var timing = false

    private var tickJob: Job? = null
    private var advanceJob: Job? = null
    private var exitJob: Job? = null

    init {
        if (!restore()) {
            // FR-1.6: show the defaults at once, then the remembered values when they arrive.
            viewModelScope.launch {
                val saved = settings.config.first()
                if (_state.value is UiState.Setup && !setupEdited) {
                    config = saved
                    _state.value = UiState.Setup(saved)
                }
            }
        }
    }

    // ---- Setup (FR-1) ----

    fun setName(raw: String) = editSetup { it.copy(name = SessionConfig.filterName(raw)) }

    fun setMaxNumber(value: Int) = editSetup { it.copy(maxNumber = value) }

    fun setCardCount(value: Int) = editSetup { it.copy(cardCount = value) }

    /** FR-1.3: deselecting the last selected operation is refused. */
    fun toggleOp(op: Operation) = editSetup {
        when {
            op !in it.ops -> it.copy(ops = it.ops + op)
            it.ops.size > 1 -> it.copy(ops = it.ops - op)
            else -> it
        }
    }

    private inline fun editSetup(change: (SessionConfig) -> SessionConfig) {
        val s = _state.value as? UiState.Setup ?: return
        setupEdited = true
        _state.value = UiState.Setup(change(s.config))
    }

    /** FR-1.5: save the settings, build the deck, show the first card. */
    fun start() {
        val s = _state.value as? UiState.Setup ?: return
        config = s.config.sanitized()
        val saving = config
        viewModelScope.launch { settings.save(saving) }
        deal()
    }

    /** A fresh deck with the current settings: Start, and Play again (FR-5.1). */
    private fun deal() {
        advanceJob?.cancel()
        exitJob?.cancel()
        seed = newSeed()
        val deck = DeckGenerator.generate(config, Random(seed)).cards
        accumulatedMs = 0
        runningSince = null
        _seconds.value = 0
        timing = true
        resumeClock()
        show(
            UiState.Cards(
                deck = deck, index = 0, input = "", attempt = 1, feedback = Feedback.NONE,
                correct = 0, name = config.name, maxDigits = config.maxDigits,
            ),
        )
    }

    // ---- Cards (FR-3) ----

    fun digit(d: Int) {
        val s = cards() ?: return
        if (s.busy || s.input.length >= s.maxDigits) return
        show(s.copy(input = if (s.input == "0") "$d" else s.input + d))
    }

    fun delete() {
        val s = cards() ?: return
        if (s.busy || s.input.isEmpty()) return
        show(s.copy(input = s.input.dropLast(1)))
    }

    /** FR-3.3 and FR-3.4: right → next; wrong once → nudge; wrong twice → show the answer, next. */
    fun submit() {
        val s = cards() ?: return
        if (s.busy || s.input.isEmpty()) return
        when {
            s.input.toInt() == s.card.answer ->
                decide(s.copy(feedback = Feedback.CORRECT, correct = s.correct + 1), CORRECT_MS)
            s.attempt == 1 -> show(s.copy(attempt = 2, feedback = Feedback.NUDGE))
            else -> decide(s.copy(feedback = Feedback.REVEAL), REVEAL_MS)
        }
    }

    private fun decide(s: UiState.Cards, delayMs: Long) {
        if (s.index == s.total - 1) stopClock() // FR-3.5: the clock stops on the last final attempt
        show(s)
        advanceJob = viewModelScope.launch {
            delay(delayMs)
            advance()
        }
    }

    private fun advance() {
        val s = cards() ?: return
        if (s.index == s.total - 1) {
            show(UiState.Results(s.name, s.correct, s.total, accumulatedMs))
        } else {
            show(s.copy(index = s.index + 1, input = "", attempt = 1, feedback = Feedback.NONE))
        }
    }

    // ---- Back and Play again (FR-3.6, FR-5) ----

    /** System Back. Returns false on Setup, where Back leaves the app as usual. */
    fun back(): Boolean {
        when (val s = _state.value) {
            is UiState.Setup -> return false
            is UiState.Results -> toSetup()
            is UiState.Cards -> if (s.exitArmed) {
                toSetup()
            } else {
                show(s.copy(exitArmed = true))
                exitJob?.cancel()
                exitJob = viewModelScope.launch {
                    delay(EXIT_WINDOW_MS)
                    cards()?.let { _state.value = it.copy(exitArmed = false) }
                }
            }
        }
        return true
    }

    /** FR-5.1: straight into a new session with the same settings, no stop at Setup. */
    fun playAgain() {
        if (_state.value is UiState.Results) deal()
    }

    private fun toSetup() {
        advanceJob?.cancel()
        exitJob?.cancel()
        stopClock()
        accumulatedMs = 0
        _seconds.value = 0
        show(UiState.Setup(config))
    }

    // ---- The clock (FR-3.5; IMPLEMENTATION.md §3.4) ----

    fun onVisible() {
        visible = true
        resumeClock()
    }

    fun onHidden() {
        visible = false
        pauseClock()
        persist()
    }

    private fun elapsedNow(): Long = accumulatedMs + (runningSince?.let { clock() - it } ?: 0L)

    private fun resumeClock() {
        if (!timing || !visible || runningSince != null) return
        runningSince = clock()
        tickJob?.cancel()
        tickJob = viewModelScope.launch {
            while (true) {
                val elapsed = elapsedNow()
                _seconds.value = (elapsed / 1000).toInt()
                delay(1000 - elapsed % 1000)
            }
        }
    }

    private fun pauseClock() {
        runningSince?.let { accumulatedMs += clock() - it }
        runningSince = null
        tickJob?.cancel()
        _seconds.value = (accumulatedMs / 1000).toInt()
    }

    private fun stopClock() {
        pauseClock()
        timing = false
    }

    // ---- State and process death (IMPLEMENTATION.md §3.5) ----

    private fun cards(): UiState.Cards? = _state.value as? UiState.Cards

    private fun show(s: UiState) {
        _state.value = s
        persist()
    }

    /**
     * Saves what's needed to rebuild the screen: the deck itself never, only its seed. A card
     * already decided is saved as the card after it, so a restore never replays a decision.
     */
    private fun persist() {
        handle.keys().forEach { handle.remove<Any>(it) }
        when (val s = _state.value) {
            is UiState.Setup -> Unit
            is UiState.Results -> saveResults(s.name, s.correct, s.total, s.elapsedMs)
            is UiState.Cards -> {
                if (s.busy && s.index == s.total - 1) {
                    saveResults(s.name, s.correct, s.total, accumulatedMs)
                    return
                }
                handle[K_MODE] = MODE_CARDS
                handle[K_NAME] = config.name
                handle[K_MAX] = config.maxNumber
                handle[K_OPS] = config.ops.joinToString(",") { it.name }
                handle[K_COUNT] = config.cardCount
                handle[K_SEED] = seed
                handle[K_INDEX] = if (s.busy) s.index + 1 else s.index
                handle[K_INPUT] = if (s.busy) "" else s.input
                handle[K_ATTEMPT] = if (s.busy) 1 else s.attempt
                handle[K_CORRECT] = s.correct
                handle[K_ELAPSED] = elapsedNow()
            }
        }
    }

    private fun saveResults(name: String, correct: Int, total: Int, elapsedMs: Long) {
        handle[K_MODE] = MODE_RESULTS
        handle[K_NAME] = name
        handle[K_MAX] = config.maxNumber
        handle[K_OPS] = config.ops.joinToString(",") { it.name }
        handle[K_COUNT] = config.cardCount
        handle[K_CORRECT] = correct
        handle[K_TOTAL] = total
        handle[K_ELAPSED] = elapsedMs
    }

    /** Rebuilds a saved session; false (and Setup) when there is none or it doesn't add up. */
    private fun restore(): Boolean = runCatching {
        val mode = handle.get<String>(K_MODE) ?: return false
        config = SessionConfig(
            name = handle[K_NAME] ?: "",
            maxNumber = handle[K_MAX] ?: SessionConfig.DEFAULT_MAX,
            ops = handle.get<String>(K_OPS).orEmpty().split(",")
                .mapNotNull { n -> Operation.entries.find { it.name == n } }.toSet(),
            cardCount = handle[K_COUNT] ?: SessionConfig.DEFAULT_COUNT,
        ).sanitized()
        when (mode) {
            MODE_RESULTS -> {
                accumulatedMs = handle[K_ELAPSED] ?: 0L
                _state.value = UiState.Results(config.name, handle[K_CORRECT]!!, handle[K_TOTAL]!!, accumulatedMs)
            }
            MODE_CARDS -> {
                seed = handle[K_SEED]!!
                val deck = DeckGenerator.generate(config, Random(seed)).cards
                val index: Int = handle[K_INDEX]!!
                require(index in deck.indices)
                accumulatedMs = handle[K_ELAPSED] ?: 0L
                _seconds.value = (accumulatedMs / 1000).toInt()
                val attempt: Int = handle[K_ATTEMPT] ?: 1
                _state.value = UiState.Cards(
                    deck = deck, index = index, input = handle[K_INPUT] ?: "", attempt = attempt,
                    feedback = if (attempt == 2) Feedback.NUDGE else Feedback.NONE,
                    correct = handle[K_CORRECT] ?: 0, name = config.name, maxDigits = config.maxDigits,
                )
                timing = true
                resumeClock()
            }
            else -> return false
        }
        true
    }.getOrElse {
        handle.keys().forEach { k -> handle.remove<Any>(k) }
        false
    }

    companion object {
        const val CORRECT_MS = 300L
        const val REVEAL_MS = 1500L
        const val EXIT_WINDOW_MS = 2000L

        private const val MODE_CARDS = "cards"
        private const val MODE_RESULTS = "results"
        private const val K_MODE = "mode"
        private const val K_NAME = "name"
        private const val K_MAX = "max"
        private const val K_OPS = "ops"
        private const val K_COUNT = "count"
        private const val K_SEED = "seed"
        private const val K_INDEX = "index"
        private const val K_INPUT = "input"
        private const val K_ATTEMPT = "attempt"
        private const val K_CORRECT = "correct"
        private const val K_TOTAL = "total"
        private const val K_ELAPSED = "elapsed"

        fun factory(app: Application) = viewModelFactory {
            initializer {
                SessionViewModel(createSavedStateHandle(), SettingsRepository(app), { SystemClock.elapsedRealtime() })
            }
        }
    }
}
