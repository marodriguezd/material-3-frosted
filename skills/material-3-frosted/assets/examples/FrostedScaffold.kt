package com.example.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeInput
import dev.chrisbanes.haze.blur.hazeBlur
import dev.chrisbanes.haze.blur.materials.HazeMaterials
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.rememberHazeState
import com.example.app.ui.theme.LocalGlassAvailable

/**
 * Edge-to-edge scaffold with a frosted top bar and a frosted bottom bar.
 *
 * THE TOPOLOGY RULE: the source is the scrolling content only. The bars are SIBLINGS of the
 * content lambda, not descendants of the source. If you mark the whole screen as a source the
 * bar samples itself and you get a recursion/empty frame.
 *
 * The opaque fallback is the default: when the platform cannot blur (or the user asked for
 * reduced transparency) the bars use `surfaceContainer` at full opacity.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FrostedScaffold(
    title: String,
    snackbarHostState: SnackbarHostState = remember { SnackbarHostState() },
    topBarActions: @Composable () -> Unit = {},
    bottomBarContent: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    val hazeState = rememberHazeState()
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    // One decision, one place. Opaque when the system cannot blur.
    val barColor: Color = if (glassAvailable) Color.Transparent else scheme.surfaceContainer

    Scaffold(
        containerColor = scheme.surface,
        contentWindowInsets = WindowInsets.safeDrawing,
        topBar = {
            TopAppBar(
                title = { Text(title, style = MaterialTheme.typography.titleLarge) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = barColor,
                    scrolledContainerColor = barColor,
                ),
                actions = { topBarActions() },
                modifier = Modifier.hazeBlur(
                    input = HazeInput.Backdrop(hazeState),
                    style = HazeMaterials.thin(),
                ),
            )
        },
        bottomBar = {
            BottomAppBar(
                containerColor = barColor,
                content = { bottomBarContent() },
                modifier = Modifier.hazeBlur(
                    input = HazeInput.Backdrop(hazeState),
                    style = HazeMaterials.thin(),
                ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                // The source is the CONTENT, and only the content.
                .hazeSource(hazeState),
        ) {
            content(PaddingValues())
        }
    }
}

/**
 * A screen whose content scrolls under a frosted bar.
 *
 * Notice the split of responsibilities:
 *  - `hazeSource` sits on the scrolling container.
 *  - `hazeBlur` sits on the bar, in a *sibling* slot of the Scaffold.
 *  - The scaffold's `contentPadding` is applied to the scrolling content, so items are not
 *    hidden behind the translucent bars while remaining reachable.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FrostedScreenWithScrollingContent(
    title: String,
    items: List<String>,
    modifier: Modifier = Modifier,
    listContent: @Composable (item: String) -> Unit,
) {
    val hazeState = rememberHazeState()
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    val barColor: Color = if (glassAvailable) Color.Transparent else scheme.surfaceContainer

    Scaffold(
        modifier = modifier,
        containerColor = scheme.surface,
        topBar = {
            TopAppBar(
                title = { Text(title) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = barColor,
                    scrolledContainerColor = barColor,
                ),
                modifier = Modifier.hazeBlur(
                    input = HazeInput.Backdrop(hazeState),
                    style = HazeMaterials.thin(),
                ),
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .hazeSource(hazeState),
            contentPadding = padding,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(items = items, key = { it }) { item ->
                Surface(
                    color = scheme.surfaceContainer,
                    shape = MaterialTheme.shapes.medium,
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth(),
                ) {
                    listContent(item)
                }
            }
        }
    }
}
