package dev.sumbee.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import dev.sumbee.R

private val big = TextStyle(fontFamily = Fonts.Baloo, fontWeight = FontWeight.ExtraBold, color = Palette.Ink)

/** Results (SPEC.md FR-4): whose score, how many right, how long; then Play again (FR-5). */
@Composable
fun ResultsContent(state: UiState.Results, onPlayAgain: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(start = 24.dp, end = 24.dp, top = 40.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Column(
            Modifier.weight(1f).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
        ) {
            Text(
                text = if (state.name.isNotBlank()) stringResource(R.string.results_title_named, state.name)
                else stringResource(R.string.results_title),
                style = big.copy(fontSize = 40.sp, textAlign = TextAlign.Center),
                modifier = Modifier.fillMaxWidth().semantics { heading() },
            )
            ScoreCard(state.correct, state.total)
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Palette.White, RoundedCornerShape(24.dp))
                    .padding(horizontal = 24.dp, vertical = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(Icons.Clock, contentDescription = null, tint = Palette.Muted, modifier = Modifier.size(24.dp))
                    Text(
                        stringResource(R.string.time),
                        style = TextStyle(fontFamily = Fonts.Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, color = Palette.Muted),
                    )
                }
                Text(formatTime((state.elapsedMs / 1000).toInt()), style = big.copy(fontSize = 44.sp))
            }
        }
        ChunkyButton(
            onClick = onPlayAgain,
            color = Palette.Sun,
            base = Palette.SunShadow,
            radius = 24.dp,
            depth = 6.dp,
            modifier = Modifier.fillMaxWidth().height(90.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.PlayAgain, contentDescription = null, tint = Palette.Ink, modifier = Modifier.size(30.dp))
                Text(stringResource(R.string.play_again), style = big.copy(fontSize = 36.sp))
            }
        }
    }
}

@Composable
private fun ScoreCard(correct: Int, total: Int) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Palette.White, RoundedCornerShape(32.dp))
            .padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        BasicText(
            text = buildAnnotatedString {
                append(correct.toString())
                withStyle(SpanStyle(fontSize = 0.42.em, color = Palette.Muted)) { append(" / $total") }
            },
            style = big.copy(fontSize = 132.sp, textAlign = TextAlign.Center),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(minFontSize = 48.sp, maxFontSize = 132.sp),
            modifier = Modifier.fillMaxWidth(),
        )
        Box(Modifier.fillMaxWidth().height(14.dp).background(Palette.Track, RoundedCornerShape(50))) {
            Box(
                Modifier
                    .fillMaxWidth(if (total > 0) correct.toFloat() / total else 0f)
                    .fillMaxHeight()
                    .background(Palette.Sun, RoundedCornerShape(50)),
            )
        }
    }
}
