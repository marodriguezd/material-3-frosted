package com.example.app.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ModalBottomSheetDefaults
import androidx.compose.material3.SheetState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeInput
import dev.chrisbanes.haze.blur.hazeBlur
import dev.chrisbanes.haze.blur.materials.HazeMaterials
import com.example.app.ui.theme.LocalGlassAvailable

/**
 * Modal bottom sheet with a frosted header.
 *
 * The rule: **the sheet body stays opaque**. Only the header (and the scrim) carry the frosted
 * treatment. A full-screen glass sheet is both unreadable and the single most expensive glass
 * surface you can draw.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlassBottomSheet(
    title: String,
    onDismissRequest: () -> Unit,
    sheetState: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false),
    content: @Composable () -> Unit,
) {
    val glassAvailable = LocalGlassAvailable.current
    val scheme = MaterialTheme.colorScheme

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        sheetState = sheetState,
        containerColor = scheme.surfaceContainerLow,
        // The drag handle and the header live above the opaque body.
        dragHandle = { ModalBottomSheetDefaults.DragHandle() },
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // Frosted header: the page behind the sheet shows through the strip above the body.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .hazeBlur(
                        input = HazeInput.Backdrop(),
                        style = HazeMaterials.thin(),
                    )
                    .padding(horizontal = 24.dp, vertical = 8.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineSmall,
                    color = scheme.onSurface,
                )
            }

            // Opaque body.
            Surface(
                color = scheme.surfaceContainerLow,
                shape = MaterialTheme.shapes.extraLarge,
                modifier = Modifier.fillMaxWidth(),
            ) {
                content()
            }
        }
    }
}

/**
 * A modal sheet whose header is frosted and whose body is a scrolling list.
 *
 * The header is a *sibling* of the scrolling body, never inside the haze source, so the source
 * (the list) and the effect (the header) do not overlap.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlassBottomSheetWithList(
    title: String,
    onDismissRequest: () -> Unit,
    items: List<String>,
    modifier: Modifier = Modifier,
    listContent: @Composable (item: String) -> Unit,
) {
    val scheme = MaterialTheme.colorScheme

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        containerColor = scheme.surfaceContainerLow,
        modifier = modifier,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
                color = scheme.onSurface,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(
                    start = 24.dp, end = 24.dp, bottom = 32.dp,
                ),
            ) {
                items(items = items, key = { it }) { item ->
                    listContent(item)
                }
            }
        }
    }
}
