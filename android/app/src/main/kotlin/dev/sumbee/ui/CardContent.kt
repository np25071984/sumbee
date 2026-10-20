package dev.sumbee.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.sumbee.R
import kotlinx.coroutines.flow.StateFlow

private val big = TextStyle(fontFamily = Fonts.Baloo, fontWeight = FontWeight.ExtraBold, color = Palette.Ink)
val TrimmedLine = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both)

private val pill = TextStyle(fontFamily = Fonts.Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)

/** Answering a card (SPEC.md FR-3). */
@Composable
fun CardContent(
    state: UiState.Cards,
    seconds: StateFlow<Int>,
    onDigit: (Int) -> Unit,
    onDelete: () -> Unit,
    onSubmit: () -> Unit,
) {
    // The screen stays on while cards show (FR-3.7): a window flag, so no permission, and Setup and
    // Results still sleep as usual.
    val view = LocalView.current
    DisposableEffect(view) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        // Keys give up height, down to FR-3.2's 64 dp, before the problem has to shrink.
        val keyHeight = ((maxHeight - CardChrome) / 4).coerceIn(MinKeyHeight, MaxKeyHeight)
        Column(
            Modifier.fillMaxSize().padding(start = 16.dp, end = 16.dp, top = 20.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            ProgressHeader(state.index + 1, state.total, seconds)
            Column(
                Modifier.weight(1f).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // The problem takes whatever height is left, so on a short screen it shrinks rather than the
                // answer box, the message slot or the keypad. Baloo's digits fill only the middle 0.6 em of
                // its tall line box, centred, so size the font for the digits to fill the space and let the
                // empty rest of the line box overhang.
                BoxWithConstraints(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    val size = with(LocalDensity.current) { (maxHeight * 1.25f).toSp() }.value.coerceIn(24f, 96f).sp
                    BasicText(
                        text = state.card.text,
                        style = big.copy(fontSize = size, textAlign = TextAlign.Center),
                        maxLines = 1,
                        autoSize = TextAutoSize.StepBased(minFontSize = 24.sp, maxFontSize = size),
                        modifier = Modifier.fillMaxWidth().wrapContentHeight(unbounded = true),
                    )
                }
                AnswerBox(state)
                // One slot for every message, so none of them costs the problem any height: the first
                // card's greeting until it is answered (FR-3.1), the feedback, and the Back hint (FR-3.6),
                // which wins for its 2 s; whatever it covers shows again after.
                Box(Modifier.height(52.dp), contentAlignment = Alignment.Center) {
                    val greet = state.index == 0 && state.attempt == 1 && state.name.isNotBlank()
                    when {
                        state.exitArmed -> Pill(stringResource(R.string.back_hint), Palette.Ink, Palette.White, null, small = true)
                        state.feedback == Feedback.NUDGE -> Pill(stringResource(R.string.nudge), Palette.NudgeBg, Palette.NudgeInk, Icons.Question)
                        state.feedback == Feedback.CORRECT -> Pill(stringResource(R.string.correct), Palette.GoodBg, Palette.GoodInk, Icons.Check)
                        state.feedback == Feedback.REVEAL -> Pill(stringResource(R.string.reveal, state.card.answer), Palette.Soft, Palette.Ink, null)
                        greet -> Text(stringResource(R.string.greeting, state.name), style = pill.copy(fontSize = 22.sp, color = Palette.Muted))
                    }
                }
            }
            Keypad(
                onDigit = onDigit,
                onDelete = onDelete,
                onSubmit = onSubmit,
                submitEnabled = state.input.isNotEmpty() && !state.busy,
                keyHeight = keyHeight,
            )
        }
    }
}

/**
 * Everything on the card screen but the four key rows, with the problem at a readable 64 dp:
 * padding 36, header 50, gaps 28, keypad gaps 30, problem 64, answer 104, slot 52, their gaps 32.
 */
private val CardChrome = 396.dp

@Composable
private fun ProgressHeader(number: Int, total: Int, seconds: StateFlow<Int>) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
            Text(stringResource(R.string.progress, number, total), style = big.copy(fontSize = 26.sp))
            Timer(seconds)
        }
        Box(Modifier.fillMaxWidth().height(10.dp).background(Palette.Track, RoundedCornerShape(50))) {
            Box(
                Modifier
                    .fillMaxWidth((number - 1).toFloat() / total)
                    .fillMaxHeight()
                    .background(Palette.Sun, RoundedCornerShape(50)),
            )
        }
    }
}

/** The only reader of the clock, so a tick redraws this pill and nothing else (IMPLEMENTATION.md §3.4). */
@Composable
private fun Timer(seconds: StateFlow<Int>) {
    val s by seconds.collectAsStateWithLifecycle()
    Row(
        Modifier
            .background(Palette.White, RoundedCornerShape(50))
            .border(2.dp, Palette.Track, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Clock, contentDescription = null, tint = Palette.Muted, modifier = Modifier.size(18.dp))
        Text(formatTime(s), style = pill.copy(fontSize = 18.sp, color = Palette.Muted))
    }
}

@Composable
private fun AnswerBox(state: UiState.Cards) {
    val (text, color) = when {
        state.feedback == Feedback.REVEAL -> state.card.answer.toString() to Palette.Ink
        state.feedback == Feedback.CORRECT -> state.input to Palette.GoodInk
        state.input.isEmpty() -> "?" to Palette.Placeholder
        else -> state.input to Palette.Ink
    }
    val border = when (state.feedback) {
        Feedback.NUDGE -> Palette.NudgeBorder
        Feedback.CORRECT -> Palette.GoodBorder
        else -> Palette.Line
    }
    val description = stringResource(R.string.answer_description)
    Box(
        Modifier
            .width(220.dp)
            .height(104.dp)
            .background(Palette.White, RoundedCornerShape(26.dp))
            .border(4.dp, border, RoundedCornerShape(26.dp))
            .semantics {
                contentDescription = description
                liveRegion = LiveRegionMode.Polite
            },
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            text = text,
            style = big.copy(fontSize = 72.sp, color = color, textAlign = TextAlign.Center, lineHeight = 1.1.em, lineHeightStyle = TrimmedLine),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(minFontSize = 32.sp, maxFontSize = 72.sp),
            modifier = Modifier.padding(horizontal = 12.dp),
        )
    }
}

@Composable
private fun Pill(text: String, background: Color, ink: Color, icon: ImageVector?, small: Boolean = false) {
    Row(
        Modifier
            .background(background, RoundedCornerShape(50))
            .padding(horizontal = if (small) 20.dp else 18.dp, vertical = if (small) 12.dp else 10.dp)
            .semantics { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = ink, modifier = Modifier.size(22.dp))
        Text(text, style = pill.copy(color = ink, fontSize = if (small) 17.sp else 20.sp))
    }
}

fun formatTime(seconds: Int): String = "%d:%02d".format(seconds / 60, seconds % 60)
