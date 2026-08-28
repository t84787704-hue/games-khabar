package com.example.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkGamingColorScheme =
  darkColorScheme(
    primary = NeonGreen,
    onPrimary = BgOuter,
    secondary = AlertRed,
    onSecondary = TextWhite,
    tertiary = NewsBlue,
    background = BgScaffold,
    onBackground = TextWhite,
    surface = CardBg,
    onSurface = TextWhite,
    surfaceVariant = CardBg2,
    onSurfaceVariant = TextGray,
    outline = BorderColor,
  )

@Composable
fun GamesKhabarTheme(
  content: @Composable () -> Unit,
) {
  MaterialTheme(
    colorScheme = DarkGamingColorScheme,
    typography = Typography,
    content = content
  )
}

