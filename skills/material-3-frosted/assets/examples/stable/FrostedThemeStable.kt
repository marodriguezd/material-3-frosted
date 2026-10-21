package com.example.app.ui.theme

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.view.WindowManager
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazePerformanceMode
import dev.chrisbanes.haze.LocalHazePerformanceMode
import dev.chrisbanes.haze.blur.HazeBlurStyle
import dev.chrisbanes.haze.blur.LocalHazeBlurStyle
import dev.chrisbanes.haze.glass.GlassAccessibilitySettings
import dev.chrisbanes.haze.glass.GlassStyle
import dev.chrisbanes.haze.glass.LocalGlassAccessibilitySettings
import dev.chrisbanes.haze.glass.LocalGlassStyle

/**
 * The **stable** theme: identical glass behaviour, no Material 3 Expressive dependency.
 *
 * Use this instead of `FrostedTheme.kt` when the project cannot take a beta dependency.
 * material3 1.4.0 ships `MaterialExpressiveTheme`, `MotionScheme.expressive()` and the
 * increased shape tokens as `internal`, so none of them can be called. Everything the
 * frosted layer needs — tokens, surface containers, glass styles, accessibility wiring —
 * is available on stable and is configured here exactly as in the expressive version.
 *
 * Compiles against androidx.compose.material3:material3:1.4.0.
 */

// See FrostedTheme.kt for the annotated brand palette. Kept brief here because the point of
// this file is the stable wiring, not the colours.
private val BrandLightColors = lightColorScheme()
private val BrandDarkColors = darkColorScheme()

private const val USE_DYNAMIC_COLOR = true

data class FrostedUiPreferences(
    val reduceTransparency: Boolean = false,
    val increaseContrast: Boolean = false,
    val showBorders: Boolean = false,
)

val LocalFrostedUiPreferences: ProvidableCompositionLocal<FrostedUiPreferences> =
    staticCompositionLocalOf { FrostedUiPreferences() }

val LocalGlassAvailable: ProvidableCompositionLocal<Boolean> =
    compositionLocalOf { true }

/** Stable shape scale: only the five base tokens exist as public API on 1.4.0. */
val FrostedShapes = Shapes(
    extraSmall = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
    small = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    extraLarge = androidx.compose.foundation.shape.RoundedCornerShape(28.dp),
)

val FrostedTypography: Typography = Typography()

@Composable
fun rememberAppBlurStyle(): HazeBlurStyle = remember {
    HazeBlurStyle {
        blurEnabled(true)
        blurRadius(16.dp)
        noiseFactor(0.15f)
    }
}

@Composable
fun rememberAppGlassStyle(): GlassStyle {
    val dark = isSystemInDarkTheme()
    return remember(dark) {
        GlassStyle.regular.then {
            backgroundColor(Color.Transparent)
            tint(if (dark) Color.Black.copy(alpha = 0.28f) else Color.White.copy(alpha = 0.32f))
            specularIntensity(0.55f)
            ambientResponse(0.4f)
            edgeSoftness(12.dp)
        }
    }
}

@Composable
fun FrostedTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = USE_DYNAMIC_COLOR,
    preferences: FrostedUiPreferences = FrostedUiPreferences(),
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val colorScheme: ColorScheme = remember(darkTheme, dynamicColor) {
        when {
            dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
                if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)

            darkTheme -> BrandDarkColors
            else -> BrandLightColors
        }
    }

    val glassAvailable = rememberGlassAvailable()
    val performanceMode = remember {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        if (am.isLowRamDevice) HazePerformanceMode.Performance else HazePerformanceMode.Default
    }

    CompositionLocalProvider(
        LocalFrostedUiPreferences provides preferences,
        LocalGlassAvailable provides glassAvailable,
        LocalHazePerformanceMode provides performanceMode,
        LocalHazeBlurStyle provides rememberAppBlurStyle(),
        LocalGlassStyle provides rememberAppGlassStyle(),
        LocalGlassAccessibilitySettings provides GlassAccessibilitySettings(
            reduceTransparency = preferences.reduceTransparency,
            increaseContrast = preferences.increaseContrast,
            showBorders = preferences.showBorders,
        ),
    ) {
        // Plain MaterialTheme: no motionScheme parameter exists on 1.4.0, and
        // MotionScheme.expressive() is internal there.
        MaterialTheme(
            colorScheme = colorScheme,
            typography = FrostedTypography,
            shapes = FrostedShapes,
            content = content,
        )
    }
}

@Composable
fun rememberGlassAvailable(): Boolean {
    val context = LocalContext.current
    return remember {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.isCrossWindowBlurEnabled
        } else {
            false
        }
    }
}
