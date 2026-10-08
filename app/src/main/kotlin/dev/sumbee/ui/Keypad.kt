package dev.sumbee.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.sumbee.R

private val digitStyle = TextStyle(fontFamily = Fonts.Baloo, fontWeight = FontWeight.Bold, fontSize = 38.sp, color = Palette.Ink)
/** Key height on a tall screen; [MinKeyHeight] is FR-3.2's floor, used when height is short. */
val MaxKeyHeight = 76.dp
val MinKeyHeight = 64.dp

/**
 * The on-screen keypad (SPEC.md FR-3.2): 0–9, delete and check, each key ≥ 64 dp. It takes no
 * answer state, so typing a digit doesn't recompose it (IMPLEMENTATION.md §3.2).
 */
@Composable
fun Keypad(
    onDigit: (Int) -> Unit,
    onDelete: () -> Unit,
    onSubmit: () -> Unit,
    submitEnabled: Boolean,
    modifier: Modifier = Modifier,
    keyHeight: Dp = MaxKeyHeight,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (row in 0 until 3) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (col in 1..3) DigitKey(row * 3 + col, keyHeight, onDigit)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ChunkyButton(
                onClick = onDelete,
                color = Palette.Soft,
                base = Palette.SoftShadow,
                description = stringResource(R.string.key_delete),
                modifier = Modifier.weight(1f).height(keyHeight),
            ) {
                Icon(Icons.Backspace, contentDescription = null, tint = Palette.Ink, modifier = Modifier.size(32.dp))
            }
            DigitKey(0, keyHeight, onDigit)
            ChunkyButton(
                onClick = onSubmit,
                color = Palette.Ink,
                base = Palette.InkShadow,
                enabled = submitEnabled,
                description = stringResource(R.string.key_submit),
                modifier = Modifier.weight(1f).height(keyHeight),
            ) {
                Icon(Icons.Check, contentDescription = null, tint = Palette.White, modifier = Modifier.size(34.dp))
            }
        }
    }
}

@Composable
private fun RowScope.DigitKey(digit: Int, keyHeight: Dp, onDigit: (Int) -> Unit) {
    ChunkyButton(
        onClick = { onDigit(digit) },
        color = Palette.White,
        base = Palette.KeyShadow,
        modifier = Modifier.weight(1f).height(keyHeight),
    ) {
        Text(digit.toString(), style = digitStyle)
    }
}
