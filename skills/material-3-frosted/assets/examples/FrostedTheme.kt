package com.example.app.ui.theme

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.view.WindowManager
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.chrisbanes.haze.HazePerformanceMode
import dev.chrisbanes.haze.LocalHazePerformanceMode
import dev.chrisbanes.haze.blur.HazeBlurStyle
import dev.chrisbanes.haze.blur.LocalHazeBlurStyle
import dev.chrisbanes.haze.glass.GlassAccessibilitySettings
import dev.chrisbanes.haze.glass.GlassStyle
import dev.chrisbanes.haze.glass.LocalGlassAccessibilitySettings
import dev.chrisbanes.haze.glass.LocalGlassStyle

/**
 * Reference implementation of the app's design-system entry point.
 *
 * ADAPT THIS FILE to the target app's own package and tokens. Do not paste it in parallel with
 * an existing theme — the point of the upgrade is a single source of truth.
 *
 * Requires:
 *   androidx.compose.material3:material3:1.5.0-beta01+   <-- NOT 1.4.0: MaterialExpressiveTheme
 *                                                           and MotionScheme.expressive() are
 *                                                           `internal` there and will not compile.
 *   dev.chrisbanes.haze:haze-glass:2.0.1
 *   dev.chrisbanes.haze:haze-blur:2.0.1
 *
 * FALLBACK: if the project cannot take a beta dependency, delete MaterialExpressiveTheme and
 * `motionScheme = MotionScheme.expressive()` below and use MaterialTheme instead. Everything else
 * in this file — the tokens, the glass styles, the accessibility wiring — still applies.
 */

// ---------------------------------------------------------------------------
// Brand fallback — only used when dynamic colour is unavailable (API < 31)
// or turned off by the product.
// ---------------------------------------------------------------------------

private val BrandLightColors = lightColorScheme(
    primary = Color(0xFF00639B),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFCDE5FF),
    onPrimaryContainer = Color(0xFF001D33),
    secondary = Color(0xFF51606F),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFD4E4F6),
    onSecondaryContainer = Color(0xFF0D1D2A),
    tertiary = Color(0xFF695779),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFF0DBFF),
    onTertiaryContainer = Color(0xFF231533),
    error = Color(0xFFBA1A1A),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFFCFCFF),
    onBackground = Color(0xFF1A1C1E),
    surface = Color(0xFFFCFCFF),
    onSurface = Color(0xFF1A1C1E),
    surfaceVariant = Color(0xFFDEE3EB),
    onSurfaceVariant = Color(0xFF42474E),
    outline = Color(0xFF72777F),
    outlineVariant = Color(0xFFC2C7CF),
)

private val BrandDarkColors = darkColorScheme(
    primary = Color(0xFF95CCFF),
    onPrimary = Color(0xFF003354),
    primaryContainer = Color(0xFF004A75),
    onPrimaryContainer = Color(0xFFCDE5FF),
    secondary = Color(0xFFB8C8DA),
    onSecondary = Color(0xFF233240),
    secondaryContainer = Color(0xFF3A4857),
    onSecondaryContainer = Color(0xFFD4E4F6),
    tertiary = Color(0xFFD4BEE4),
    onTertiary = Color(0xFF392A49),
    tertiaryContainer = Color(0xFF504060),
    onTertiaryContainer = Color(0xFFF0DBFF),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF1A1C1E),
    onBackground = Color(0xFFE2E2E6),
    surface = Color(0xFF1A1C1E),
    onSurface = Color(0xFFE2E2E6),
    surfaceVariant = Color(0xFF42474E),
    onSurfaceVariant = Color(0xFFC2C7CF),
    outline = Color(0xFF8C9199),
    outlineVariant = Color(0xFF42474E),
)

/** Set to false to keep the brand palette on every device. */
private const val USE_DYNAMIC_COLOR = true

// ---------------------------------------------------------------------------
// Glass configuration
// ---------------------------------------------------------------------------

/** User-facing preference: reduce transparency. Persist it in DataStore. */
data class FrostedUiPreferences(
    val reduceTransparency: Boolean = false,
    val increaseContrast: Boolean = false,
    val showBorders: Boolean = false,
)

val LocalFrostedUiPreferences: ProvidableCompositionLocal<FrostedUiPreferences> =
    staticCompositionLocalOf { FrostedUiPreferences() }

/**
 * Glass availability. When the system cannot blur (low-end device, battery saver, the user's
 * "Reduce blur effects" toggle) the whole layer falls back to opaque M3 surfaces.
 */
val LocalGlassAvailable: ProvidableCompositionLocal<Boolean> =
    compositionLocalOf { true }

/** The single blur style used by every frosted surface in the app. */
@Composable
fun rememberAppBlurStyle(): HazeBlurStyle = remember {
    HazeBlurStyle {
        blurEnabled(true)
        blurRadius(16.dp)
        noiseFactor(0.15f)
    }
}

/** The single glass style used by every prominent glass surface in the app. */
@Composable
fun rememberAppGlassStyle(): GlassStyle {
    val dark = isSystemInDarkTheme()
    return remember(dark) {
        GlassStyle.regular.then {
            // A tinted surface keeps text legible. Derive it from the theme, never hardcode.
            backgroundColor(Color.Transparent)
            tint(if (dark) Color.Black.copy(alpha = 0.28f) else Color.White.copy(alpha = 0.32f))
            specularIntensity(0.55f)
            ambientResponse(0.4f)
            edgeSoftness(12.dp)
        }
    }
}

// ---------------------------------------------------------------------------
// Type & shape
// ---------------------------------------------------------------------------

/**
 * The expressive shape scale.
 *
 * `largeIncreased` / `extraLargeIncreased` / `extraExtraLarge` are public from material3
 * 1.5.0-beta01. On 1.4.0 they are `internal` — see
 * `assets/examples/stable/FrostedThemeStable.kt` for that path.
 */
val FrostedShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(28.dp),
    largeIncreased = RoundedCornerShape(20.dp),
    extraLargeIncreased = RoundedCornerShape(32.dp),
    extraExtraLarge = RoundedCornerShape(48.dp),
)

/**
 * Expressive typography. The single most effective change is an emphasized `titleLarge`;
 * everything else stays on the stock scale so the app does not drift.
 */
val FrostedTypography: Typography = Typography().let { base ->
    base.copy(
        titleLarge = base.titleLarge.copy(
            fontSize = 22.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.SemiBold,
        ),
    )
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

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

    // Performance: low-RAM devices get the cheapest profile.
    val performanceMode = remember {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        if (am.isLowRamDevice) HazePerformanceMode.Performance else HazePerformanceMode.Default
    }

    val blurStyle = rememberAppBlurStyle()
    val glassStyle = rememberAppGlassStyle()

    CompositionLocalProvider(
        LocalFrostedUiPreferences provides preferences,
        LocalGlassAvailable provides glassAvailable,
        LocalHazePerformanceMode provides performanceMode,
        LocalHazeBlurStyle provides blurStyle,
        LocalGlassStyle provides glassStyle,
        LocalGlassAccessibilitySettings provides GlassAccessibilitySettings(
            reduceTransparency = preferences.reduceTransparency,
            increaseContrast = preferences.increaseContrast,
            showBorders = preferences.showBorders,
        ),
    ) {
        MaterialExpressiveTheme(
            colorScheme = colorScheme,
            motionScheme = MotionScheme.expressive(),
            typography = FrostedTypography,
            shapes = FrostedShapes,
            content = content,
        )
    }
}

/**
 * Whether the platform can currently produce a blur. Combine with the app's own
 * "reduce transparency" preference to decide whether to draw glass at all.
 */
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
