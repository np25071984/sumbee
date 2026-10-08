package dev.sumbee.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * A button with a darker base under it that sinks onto the base while pressed: immediate feedback
 * on every tap (FR-3.2) without a ripple. The press is read in the draw phase only, so pressing
 * redraws this one button and recomposes nothing (IMPLEMENTATION.md §3.2).
 */
@Composable
fun ChunkyButton(
    onClick: () -> Unit,
    color: Color,
    base: Color,
    modifier: Modifier = Modifier,
    radius: Dp = 20.dp,
    depth: Dp = 5.dp,
    enabled: Boolean = true,
    description: String? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed = interaction.collectIsPressedAsState()
    val shape = RoundedCornerShape(radius)
    Box(
        modifier
            .alpha(if (enabled) 1f else 0.45f)
            .clickable(
                interactionSource = interaction,
                indication = null,
                enabled = enabled,
                role = Role.Button,
                onClick = onClick,
            )
            .then(if (description != null) Modifier.semantics { contentDescription = description } else Modifier),
    ) {
        Box(Modifier.fillMaxSize().padding(top = depth).background(base, shape))
        Box(
            Modifier
                .fillMaxSize()
                .padding(bottom = depth)
                .graphicsLayer { translationY = if (pressed.value) depth.toPx() * 0.8f else 0f }
                .background(color, shape),
            contentAlignment = Alignment.Center,
            content = content,
        )
    }
}
