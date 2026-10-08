package dev.sumbee.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/** The handful of stroke icons the screens use, drawn here rather than pulling in an icon library (FR-7). */
object Icons {
    val ArrowRight = icon("ArrowRight", 3f, "M5 12h14", "M13 6l6 6-6 6")
    val Check = icon("Check", 3f, "M5 12.5l4.5 4.5L19 7.5")
    val Backspace = icon("Backspace", 2.5f, "M21 5H9l-6 7 6 7h12a1 1 0 0 0 1-1V6a1 1 0 0 0-1-1z", "M17 9l-6 6", "M11 9l6 6")
    val Clock = icon("Clock", 2.5f, "M4 13a8 8 0 1 0 16 0a8 8 0 1 0 -16 0", "M12 9v4l2 2", "M10 2h4")
    val Question = icon("Question", 2.5f, "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0", "M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3", "M12 17h.01")
    val PlayAgain = icon("PlayAgain", 3f, "M3 12a9 9 0 1 0 3-6.7", "M3 4v5h5")

    private fun icon(name: String, stroke: Float, vararg paths: String): ImageVector =
        ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply {
            paths.forEach { d ->
                addPath(
                    pathData = addPathNodes(d),
                    stroke = SolidColor(Color.Black),
                    strokeLineWidth = stroke,
                    strokeLineCap = StrokeCap.Round,
                    strokeLineJoin = StrokeJoin.Round,
                )
            }
        }.build()
}
