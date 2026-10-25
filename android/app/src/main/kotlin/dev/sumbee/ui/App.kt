package dev.sumbee.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
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
    // Measured inside the system bars but not the keyboard, so the scale holds while a name is typed.
    BoxWithConstraints(
        Modifier.fillMaxSize().background(Palette.Ground)
            .windowInsetsPadding(WindowInsets.systemBars.union(WindowInsets.displayCutout)),
    ) {
        // FR-6.3: on a tablet the content stays phone-width, centred, and the whole layout scales up.
        // A bigger density makes every dp and sp bigger, so each screen lays itself out again, sharp.
        val density = LocalDensity.current
        val scale = layoutScale(maxWidth, maxHeight)
        CompositionLocalProvider(LocalDensity provides Density(density.density * scale, density.fontScale)) {
            Box(Modifier.fillMaxSize().safeDrawingPadding(), contentAlignment = Alignment.TopCenter) {
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
    }
}

/**
 * 1 on every phone and on short windows; up to 1.5 on a tall tablet. The reference is a 480 × 860 dp
 * phone layout, so a window gets as much scale as both its width and its height can hold. The iOS
 * app uses the same rule (IMPLEMENTATION.md §8).
 */
fun layoutScale(width: Dp, height: Dp): Float =
    minOf(width / 480.dp, height / 860.dp).coerceIn(1f, 1.5f)
