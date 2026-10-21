package com.example.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeInput
import dev.chrisbanes.haze.blur.hazeBlur
import dev.chrisbanes.haze.blur.materials.HazeMaterials
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.glass.GlassStyle
import dev.chrisbanes.haze.glass.hazeGlass
import dev.chrisbanes.haze.glass.hazeGlassContainer
import com.example.app.ui.theme.LocalGlassAvailable

/**
 * Tier-1 glass chrome: the four surfaces that are allowed to be frosted.
 *
 * Rules encoded here:
 *  - The bar is transparent and the *modifier* carries the blur. Setting the bar's
 *    `containerColor` to an opaque colour would hide the blur.
 *  - When glass is unavailable, the bar falls back to `surfaceContainer` — fully legible.
 *  - The FAB keeps its own M3 colour semantics; the glass is the surrounding chrome.
 *  - Nearby glass surfaces are merged with `hazeGlassContainer` so they read as one object.
 */

/** Glass top app bar. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun GlassTopAppBar(
    title: String,
    hazeState: HazeState,
    modifier: Modifier = Modifier,
    scrollBehavior: androidx.compose.material3.TopAppBarScrollBehavior? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    TopAppBar(
        title = { Text(title, style = MaterialTheme.typography.titleLarge) },
        scrollBehavior = scrollBehavior,
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = if (glassAvailable) Color.Transparent else scheme.surfaceContainer,
            scrolledContainerColor = if (glassAvailable) Color.Transparent else scheme.surfaceContainer,
        ),
        actions = actions,
        modifier = modifier.hazeBlur(
            input = HazeInput.Backdrop(hazeState),
            style = HazeMaterials.thin(),
        ),
    )
}

/** Glass navigation bar. Labels are kept — never strip them for "cleanliness". */
@Composable
fun GlassNavigationBar(
    hazeState: HazeState,
    destinations: List<NavDestination>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    NavigationBar(
        containerColor = if (glassAvailable) Color.Transparent else scheme.surfaceContainer,
        modifier = modifier.hazeBlur(
            input = HazeInput.Backdrop(hazeState),
            style = HazeMaterials.thin(),
        ),
    ) {
        destinations.forEachIndexed { index, destination ->
            NavigationBarItem(
                selected = index == selectedIndex,
                onClick = { onSelect(index) },
                icon = { Icon(destination.icon, contentDescription = null) },
                label = { Text(destination.label) },
                alwaysShowLabel = true,
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = scheme.onSecondaryContainer,
                    selectedTextColor = scheme.onSurface,
                    indicatorColor = scheme.secondaryContainer,
                    unselectedIconColor = scheme.onSurfaceVariant,
                    unselectedTextColor = scheme.onSurfaceVariant,
                ),
            )
        }
    }
}

data class NavDestination(
    val label: String,
    val icon: ImageVector,
)

/**
 * A floating action button over a frosted "dock".
 *
 * The dock is the glass surface; the FAB itself keeps the M3 `primaryContainer` colour so the
 * primary action stays prominent. A glass CTA loses its hierarchy.
 */
@Composable
fun GlassFabDock(
    hazeState: HazeState,
    fabIcon: ImageVector,
    fabContentDescription: String,
    onFabClick: () -> Unit,
    modifier: Modifier = Modifier,
    secondaryActions: @Composable RowScope.() -> Unit = {},
) {
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        secondaryActions()
        Box(
            modifier = Modifier
                .weight(1f)
                .hazeGlass(
                    input = HazeInput.Backdrop(hazeState),
                    style = GlassStyle.regular,
                ),
            contentAlignment = Alignment.Center,
        ) {
            FloatingActionButton(
                onClick = onFabClick,
                containerColor = scheme.primaryContainer,
                contentColor = scheme.onPrimaryContainer,
            ) {
                Icon(fabIcon, contentDescription = fabContentDescription)
            }
        }
    }
}

/**
 * A merged group of glass controls (a segmented control / button group).
 *
 * `hazeGlassContainer(spacing = …)` merges the members into a single glass cluster: one render
 * layer, and visually one object instead of a pile of separate panes.
 */
@Composable
fun GlassControlGroup(
    hazeState: HazeState,
    modifier: Modifier = Modifier,
    content: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier = modifier
            .hazeGlassContainer(spacing = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        content()
    }
}

/** A single glass member of a [GlassControlGroup]. */
@Composable
fun GlassIconButton(
    hazeState: HazeState,
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    FilledTonalIconButton(
        onClick = onClick,
        modifier = modifier.hazeGlass(
            input = HazeInput.Backdrop(hazeState),
            style = GlassStyle.regular,
        ),
    ) {
        Icon(icon, contentDescription = contentDescription)
    }
}

/**
 * A frosted surface that ALWAYS has an opaque fallback.
 *
 * Use this for cards that sit over imagery. `GlassStyle.clear` keeps the background visible, so
 * you must guarantee contrast yourself — hence the scrim.
 */
@Composable
fun FrostedMediaOverlay(
    hazeState: HazeState,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    // Do not attach the blur at all when the platform cannot produce one: a no-op effect
    // still costs a render layer. Swap the whole modifier chain instead.
    val surfaceModifier = if (glassAvailable) {
        modifier.hazeBlur(
            input = HazeInput.Backdrop(hazeState),
            style = HazeMaterials.regular(),
        )
    } else {
        modifier.background(scheme.surfaceContainer.copy(alpha = 0.92f))
    }

    Box(modifier = surfaceModifier) {
        content()
    }
}
