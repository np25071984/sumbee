package dev.sumbee.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.sumbee.R
import dev.sumbee.model.Operation
import dev.sumbee.model.SessionConfig
import kotlin.math.abs
import kotlin.math.roundToInt

private val labelStyle = TextStyle(fontFamily = Fonts.Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, color = Palette.Muted)
private val valueStyle = TextStyle(fontFamily = Fonts.Baloo, fontWeight = FontWeight.ExtraBold, fontSize = 36.sp, color = Palette.Ink)
private val tickStyle = TextStyle(fontFamily = Fonts.Nunito, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Palette.Muted)

/** Setup (SPEC.md FR-1): everything on one screen, Start always one tap away. */
@Composable
fun SetupContent(
    config: SessionConfig,
    onName: (String) -> Unit,
    onMaxNumber: (Int) -> Unit,
    onToggleOp: (Operation) -> Unit,
    onCardCount: (Int) -> Unit,
    onStart: () -> Unit,
) {
    val focus = LocalFocusManager.current
    Column(
        Modifier
            .fillMaxSize()
            .pointerInput(Unit) { detectTapGestures { focus.clearFocus() } } // FR-1.1: tap outside closes the keyboard
            .padding(start = 24.dp, end = 24.dp, top = 24.dp, bottom = 24.dp),
    ) {
        // FR-6.3: no scrolling on a 5" phone. The gaps close up from 26 dp to 12 dp to fit; the scroll
        // is only a fallback for large font scales.
        BoxWithConstraints(Modifier.weight(1f)) {
            Column(
                Modifier.verticalScroll(rememberScrollState()).heightIn(min = maxHeight),
                verticalArrangement = FlexibleGaps(min = 12.dp, max = 26.dp),
            ) {
                Header()
                NameField(config.name, onName, onDone = { focus.clearFocus() })
                SliderBlock(
                    label = stringResource(R.string.range_label),
                    value = config.maxNumber,
                    range = SessionConfig.MIN_MAX..SessionConfig.MAX_MAX,
                    steps = (SessionConfig.MAX_MAX - SessionConfig.MIN_MAX) / SessionConfig.MAX_STEP - 1,
                    ticks = listOf(SessionConfig.MIN_MAX, SessionConfig.MAX_MAX),
                    onChange = { v -> onMaxNumber((v / SessionConfig.MAX_STEP).roundToInt() * SessionConfig.MAX_STEP) },
                )
                OpsBlock(config.ops, onToggleOp)
                SliderBlock(
                    label = stringResource(R.string.cards_label),
                    value = config.cardCount,
                    range = SessionConfig.CARD_COUNTS.first()..SessionConfig.CARD_COUNTS.last(),
                    steps = SessionConfig.CARD_COUNTS.size - 2,
                    ticks = SessionConfig.CARD_COUNTS,
                    onChange = { v -> onCardCount(SessionConfig.CARD_COUNTS.minBy { abs(it - v) }) },
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        ChunkyButton(
            onClick = { focus.clearFocus(); onStart() },
            color = Palette.Sun,
            base = Palette.SunShadow,
            radius = 24.dp,
            depth = 6.dp,
            modifier = Modifier.fillMaxWidth().height(80.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.start), style = valueStyle)
                Icon(Icons.ArrowRight, contentDescription = null, tint = Palette.Ink, modifier = Modifier.size(30.dp))
            }
        }
    }
}

@Composable
private fun Header() {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        // The app icon's bee on its navy tile, cropped to the bee (the icon canvas has adaptive-icon margins).
        Image(
            painter = painterResource(R.drawable.ic_launcher_foreground),
            contentDescription = null,
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Palette.Ink)
                .graphicsLayer { scaleX = 1.55f; scaleY = 1.55f },
        )
        Text(stringResource(R.string.app_name), style = valueStyle.copy(fontSize = 30.sp))
    }
}

@Composable
private fun NameField(name: String, onName: (String) -> Unit, onDone: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.name_label), style = labelStyle)
        BasicTextField(
            value = name,
            onValueChange = onName,
            singleLine = true,
            textStyle = TextStyle(fontFamily = Fonts.Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, color = Palette.Ink),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onDone() }),
            modifier = Modifier.fillMaxWidth(),
            decorationBox = { inner ->
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(58.dp)
                        .background(Palette.White, RoundedCornerShape(16.dp))
                        .border(2.dp, Palette.Line, RoundedCornerShape(16.dp))
                        .padding(horizontal = 18.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (name.isEmpty()) {
                        Text(stringResource(R.string.name_placeholder), style = labelStyle.copy(fontSize = 22.sp, color = Palette.Placeholder))
                    }
                    inner()
                }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class) // the custom thumb and track slots
@Composable
private fun SliderBlock(
    label: String,
    value: Int,
    range: IntRange,
    steps: Int,
    ticks: List<Int>,
    onChange: (Float) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, style = labelStyle, modifier = Modifier.alignByBaseline())
            Text(value.toString(), style = valueStyle, modifier = Modifier.digitsOnly(valueStyle.fontSize).alignByBaseline())
        }
        val colors = SliderDefaults.colors(
            thumbColor = Palette.Ink,
            activeTrackColor = Palette.Ink,
            inactiveTrackColor = Palette.Track,
            activeTickColor = Color.Transparent,
            inactiveTickColor = Color.Transparent,
        )
        Slider(
            value = value.toFloat(),
            onValueChange = onChange,
            valueRange = range.first.toFloat()..range.last.toFloat(),
            steps = steps,
            colors = colors,
            // A big round thumb rather than Material's thin bar: easier for small fingers.
            thumb = {
                Box(
                    Modifier
                        .size(32.dp)
                        .background(Palette.White, CircleShape)
                        .border(6.dp, Palette.Ink, CircleShape),
                )
            },
            track = { sliderState ->
                SliderDefaults.Track(
                    sliderState = sliderState,
                    colors = colors,
                    drawStopIndicator = null,
                    thumbTrackGapSize = 0.dp,
                    modifier = Modifier.height(12.dp),
                )
            },
            modifier = Modifier.semantics { contentDescription = label },
        )
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            ticks.forEach { Text(it.toString(), style = tickStyle) }
        }
    }
}

@Composable
private fun OpsBlock(selected: Set<Operation>, onToggle: (Operation) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.ops_label), style = labelStyle)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Operation.entries.forEach { op ->
                val on = op in selected
                val description = stringResource(
                    when (op) {
                        Operation.PLUS -> R.string.op_plus
                        Operation.MINUS -> R.string.op_minus
                        Operation.TIMES -> R.string.op_times
                        Operation.DIVIDE -> R.string.op_divide
                    },
                )
                val shape = RoundedCornerShape(18.dp)
                Box(
                    Modifier
                        .weight(1f)
                        .height(76.dp)
                        .background(if (on) Palette.Ink else Palette.White, shape)
                        .border(2.dp, if (on) Palette.Ink else Palette.Line, shape)
                        .toggleable(value = on, role = Role.Checkbox, onValueChange = { onToggle(op) })
                        .semantics { contentDescription = description },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        op.symbol,
                        style = valueStyle.copy(fontSize = 42.sp, fontWeight = FontWeight.Bold, color = if (on) Palette.White else Palette.Muted),
                    )
                }
            }
        }
    }
}

/** Gaps of [min] that grow up to [max] when the column has height to spare. */
@Suppress("FunctionName")
private fun FlexibleGaps(min: Dp, max: Dp) = object : Arrangement.Vertical {
    override val spacing = min

    override fun Density.arrange(totalSize: Int, sizes: IntArray, outPositions: IntArray) {
        val gap = ((totalSize - sizes.sum()) / (sizes.size - 1).coerceAtLeast(1)).coerceIn(min.roundToPx(), max.roundToPx())
        var y = 0
        sizes.forEachIndexed { i, size ->
            outPositions[i] = y
            y += size + gap
        }
    }
}
