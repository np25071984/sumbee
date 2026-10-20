package dev.sumbee.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import dev.sumbee.R

/** The palette from the mockups: pale blue ground, navy ink, one sunny accent. */
object Palette {
    val Ground = Color(0xFFF3F7FC)
    val Ink = Color(0xFF1B2A4A)
    val Muted = Color(0xFF4A5875)
    val Line = Color(0xFFC9D6EA)
    val Track = Color(0xFFDCE6F3)
    val Soft = Color(0xFFE6EEF8)
    val SoftShadow = Color(0xFFCBD7E8)
    val KeyShadow = Color(0xFFD3DEED)
    val InkShadow = Color(0xFF0B1426)
    val Sun = Color(0xFFFFC93C)
    val SunShadow = Color(0xFFD9A21C)
    val Placeholder = Color(0xFFA7B4C8)
    val NudgeBg = Color(0xFFFFEBC7)
    val NudgeInk = Color(0xFF8A4B00)
    val NudgeBorder = Color(0xFFF0A93B)
    val GoodBg = Color(0xFFDDF3EC)
    val GoodInk = Color(0xFF0B6E58)
    val GoodBorder = Color(0xFF1E9C7E)
    val White = Color.White
}

/** Baloo 2 for numbers and headings, Nunito for everything else: both variable fonts, in res/font. */
object Fonts {
    val Baloo = FontFamily(
        Font(R.font.baloo2, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
        Font(R.font.baloo2, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
    )
    val Nunito = FontFamily(
        Font(R.font.nunito, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
        Font(R.font.nunito, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
    )
}

@Composable
fun SumbeeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Palette.Ink,
            onPrimary = Palette.White,
            background = Palette.Ground,
            surface = Palette.White,
            onSurface = Palette.Ink,
        ),
        content = content,
    )
}
