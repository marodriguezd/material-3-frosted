package com.example.app.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import java.util.function.Consumer

/**
 * Platform window blur — the mechanism that blurs the app *behind* a window (another app, the
 * launcher). It is the right tool for dialogs and floating windows, and the wrong tool for
 * in-app chrome (use Haze for that).
 *
 * AOSP guidance: 80 px background blur for frosted glass, 20 px blur behind for depth of field,
 * never above 150 px — the GPU samples a proportionally larger area, so the cost explodes.
 *
 * The window must be TRANSLUCENT for the blur to be visible, and the window background drawable
 * (set in the theme) defines the rounded outline of the blurred region.
 *
 * Theme XML for a dialog:
 *   <style name="Theme.App.Dialog" parent="Theme.Material3.DayNight.Dialog">
 *       <item name="android:windowIsTranslucent">true</item>
 *       <item name="android:windowBackground">@drawable/dialog_background</item>
 *       <item name="android:windowBackgroundBlurRadius">80</item>
 *       <item name="android:windowBlurBehindEnabled">true</item>
 *       <item name="android:windowBlurBehindRadius">20</item>
 *   </style>
 */
/**
 * Walks the ContextWrapper chain to the hosting Activity.
 *
 * `LocalView.current.context` is frequently a ContextThemeWrapper, not the Activity, so a
 * plain `as? Activity` cast silently does nothing — the blur never gets applied and the
 * screen just looks wrong. Always unwrap.
 */
tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

object WindowBlurDefaults {
    const val BACKGROUND_BLUR_RADIUS_PX = 80
    const val BLUR_BEHIND_RADIUS_PX = 20
    const val MAX_BLUR_RADIUS_PX = 150
}

/**
 * Applies cross-window blur to the host activity's window and keeps it in sync with the
 * platform's blur availability.
 *
 * @param backgroundRadiusPx blur radius of the window's own background.
 * @param blurBehindRadiusPx blur radius applied to the content behind the window.
 * @param opaqueDimAmount dim amount used when blur is unavailable (the window is translucent
 *        and would otherwise be unreadable over the content behind it).
 */
@Composable
fun WindowBlurEffect(
    backgroundRadiusPx: Int = WindowBlurDefaults.BACKGROUND_BLUR_RADIUS_PX,
    blurBehindRadiusPx: Int = WindowBlurDefaults.BLUR_BEHIND_RADIUS_PX,
    opaqueDimAmount: Float = 0.4f,
) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

    val view = LocalView.current
    val context = LocalContext.current

    DisposableEffect(view, backgroundRadiusPx, blurBehindRadiusPx, opaqueDimAmount) {
        val window = context.findActivity()?.window
        if (window == null) {
            onDispose { }
        } else {
            val windowManager =
                context.getSystemService(android.content.Context.WINDOW_SERVICE) as WindowManager

            fun apply(blursEnabled: Boolean) {
                val radius = backgroundRadiusPx.coerceAtMost(WindowBlurDefaults.MAX_BLUR_RADIUS_PX)
                window.setBackgroundBlurRadius(if (blursEnabled) radius else 0)

                if (blursEnabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                }

                window.attributes = window.attributes.apply {
                    blurBehindRadius = if (blursEnabled) blurBehindRadiusPx else 0
                }

                // When blur is off, the translucent window sits directly over the content behind
                // it and becomes unreadable — so raise the dim amount instead.
                window.setDimAmount(if (blursEnabled) 0.1f else opaqueDimAmount)
            }

            apply(windowManager.isCrossWindowBlurEnabled)

            val listener = Consumer<Boolean> { enabled -> apply(enabled) }
            windowManager.addCrossWindowBlurEnabledListener(listener)

            onDispose {
                windowManager.removeCrossWindowBlurEnabledListener(listener)
                window.setBackgroundBlurRadius(0)
                window.clearFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                window.attributes = window.attributes.apply { blurBehindRadius = 0 }
            }
        }
    }
}

/**
 * Tracks whether the platform can currently blur, so the UI can swap to an opaque fallback.
 *
 * Combine with the user's "reduce transparency" preference: the platform flag covers battery
 * saver, low-end hardware and the system-level setting; the app preference covers the rest.
 */
@Composable
fun rememberCrossWindowBlurEnabled(): Boolean {
    val context = LocalContext.current
    var enabled by remember { mutableStateOf(false) }

    DisposableEffect(context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enabled = false
            onDispose { }
        } else {
            val windowManager =
                context.getSystemService(android.content.Context.WINDOW_SERVICE) as WindowManager
            enabled = windowManager.isCrossWindowBlurEnabled
            val listener = Consumer<Boolean> { value -> enabled = value }
            windowManager.addCrossWindowBlurEnabledListener(listener)
            onDispose { windowManager.removeCrossWindowBlurEnabledListener(listener) }
        }
    }

    return enabled
}

/**
 * Edge-to-edge setup for a Compose activity.
 *
 * `enableEdgeToEdge()` (from androidx.activity) is the modern replacement for manually setting
 * `WindowCompat.setDecorFitsSystemWindows(window, false)`. It handles status/navigation bar
 * transparency and applies the correct system-bar icon appearance for the current theme.
 */
@Composable
fun EdgeToEdgeSetup() {
    val view = LocalView.current
    if (view.isInEditMode) return

    val context = LocalContext.current

    DisposableEffect(view, context) {
        val window = context.findActivity()?.window
        if (window != null) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        onDispose { }
    }
}
