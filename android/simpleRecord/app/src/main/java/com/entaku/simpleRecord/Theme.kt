package com.entaku.simpleRecord

import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp


val White = Color(0xFFFFFFFF)
val LightGray = Color(0xFFE0E0E0)
val Gray = Color(0xFF9E9E9E)
val DarkGray = Color(0xFF424242)
val Black = Color(0xFF000000)

val DarkColorScheme = darkColorScheme(
    primary = White,
    secondary = LightGray,
    tertiary = Gray,
    background = Black,
    surface = DarkGray,
    onPrimary = Black,
    onSecondary = DarkGray,
    onTertiary = DarkGray,
    onBackground = White,
    onSurface = LightGray
)

val LightColorScheme = lightColorScheme(
    primary = Black,
    secondary = DarkGray,
    tertiary = Gray,
    background = White,
    surface = LightGray,
    onPrimary = White,
    onSecondary = White,
    onTertiary = White,
    onBackground = Black,
    onSurface = DarkGray
)

val Typography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp
    )
)