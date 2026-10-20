package dev.sumbee.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * The one screen (SPEC.md FR-6.1): its state picks the content, with no navigation library.
 * Back on Cards and Results is the ViewModel's (FR-3.6, FR-5.1); on Setup it leaves the app.
 */
@Composable
fun App(vm: SessionViewModel) {
    val state by vm.state.collectAsStateWithLifecycle()
    BackHandler(enabled = state !is UiState.Setup) { vm.back() }
    Box(
        Modifier.fillMaxSize().background(Palette.Ground).safeDrawingPadding(),
        contentAlignment = Alignment.TopCenter,
    ) {
        // FR-6.3: on a tablet the content stays phone-width, centred.
        Box(Modifier.widthIn(max = 480.dp).fillMaxSize()) {
            when (val s = state) {
                is UiState.Setup -> SetupContent(
                    config = s.config,
                    onName = vm::setName,
                    onMaxNumber = vm::setMaxNumber,
                    onToggleOp = vm::toggleOp,
                    onCardCount = vm::setCardCount,
                    onStart = vm::start,
                )
                is UiState.Cards -> CardContent(
                    state = s,
                    seconds = vm.seconds,
                    onDigit = vm::digit,
                    onDelete = vm::delete,
                    onSubmit = vm::submit,
                )
                is UiState.Results -> ResultsContent(s, onPlayAgain = vm::playAgain)
            }
        }
    }
}
