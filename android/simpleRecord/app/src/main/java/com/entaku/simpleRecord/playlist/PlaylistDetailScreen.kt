package com.entaku.simpleRecord.playlist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.formatTime
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaylistDetailScreen(
    state: PlaylistDetailUiState,
    allRecordings: List<RecordingData>,
    onNavigateBack: () -> Unit,
    onNavigateToPlayback: (RecordingData) -> Unit,
    onPlayAll: (List<RecordingData>, Int) -> Unit,
    onAddRecording: (UUID) -> Unit,
    onRemoveRecording: (UUID) -> Unit,
    onReorder: (Int, Int) -> Unit,
    colorScheme: ColorScheme
) {
    var showAddRecordingSheet by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState()
    val scope = rememberCoroutineScope()

    val recordingsInPlaylist = state.recordings.map { it.uuid }.toSet()
    val availableRecordings = allRecordings.filter { it.uuid !in recordingsInPlaylist }

    // Drag and drop state
    var draggedItemIndex by remember { mutableIntStateOf(-1) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    val listState = rememberLazyListState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.playlist?.name ?: "Playlist") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (state.recordings.isNotEmpty()) {
                        IconButton(onClick = { onPlayAll(state.recordings, 0) }) {
                            Icon(Icons.Default.PlayArrow, contentDescription = "Play All")
                        }
                    }
                }
            )
        },
        floatingActionButton = {
            if (availableRecordings.isNotEmpty()) {
                FloatingActionButton(
                    onClick = { showAddRecordingSheet = true },
                    containerColor = colorScheme.primary
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Add Recording")
                }
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (state.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (state.recordings.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.MusicNote,
                            contentDescription = null,
                            tint = colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(16.dp)
                        )
                        Text(
                            text = "No recordings in this playlist",
                            style = MaterialTheme.typography.bodyLarge,
                            color = colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "Tap + to add recordings",
                            style = MaterialTheme.typography.bodyMedium,
                            color = colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    itemsIndexed(state.recordings, key = { _, item -> item.uuid ?: item.title }) { index, recording ->
                        val isDragging = draggedItemIndex == index
                        DraggablePlaylistRecordingItem(
                            recording = recording,
                            index = index,
                            isDragging = isDragging,
                            dragOffset = if (isDragging) dragOffset else 0f,
                            onItemClick = { onPlayAll(state.recordings, index) },
                            onRemoveClick = { recording.uuid?.let { onRemoveRecording(it) } },
                            onDragStart = { draggedItemIndex = index },
                            onDrag = { delta ->
                                dragOffset += delta
                                // Calculate target index based on drag offset
                                val itemHeight = 80.dp.value // Approximate item height
                                val targetIndex = (index + (dragOffset / itemHeight).roundToInt())
                                    .coerceIn(0, state.recordings.size - 1)
                                if (targetIndex != draggedItemIndex && targetIndex != index) {
                                    onReorder(draggedItemIndex, targetIndex)
                                    draggedItemIndex = targetIndex
                                    dragOffset = 0f
                                }
                            },
                            onDragEnd = {
                                draggedItemIndex = -1
                                dragOffset = 0f
                            }
                        )
                    }
                }
            }
        }
    }

    if (showAddRecordingSheet) {
        ModalBottomSheet(
            onDismissRequest = { showAddRecordingSheet = false },
            sheetState = sheetState
        ) {
            AddRecordingSheet(
                recordings = availableRecordings,
                onAddRecording = { uuid ->
                    onAddRecording(uuid)
                    scope.launch {
                        sheetState.hide()
                        showAddRecordingSheet = false
                    }
                }
            )
        }
    }
}

@Composable
fun DraggablePlaylistRecordingItem(
    recording: RecordingData,
    index: Int,
    isDragging: Boolean,
    dragOffset: Float,
    onItemClick: () -> Unit,
    onRemoveClick: () -> Unit,
    onDragStart: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit
) {
    val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd")
    val formattedDate = recording.creationDate.format(formatter)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .offset { IntOffset(0, dragOffset.roundToInt()) }
            .zIndex(if (isDragging) 1f else 0f)
            .graphicsLayer {
                shadowElevation = if (isDragging) 8f else 0f
            }
            .background(
                if (isDragging) MaterialTheme.colorScheme.surfaceVariant
                else MaterialTheme.colorScheme.surface
            )
            .clickable { onItemClick() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Drag handle
            Icon(
                imageVector = Icons.Default.DragHandle,
                contentDescription = "Drag to reorder",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .padding(end = 8.dp)
                    .pointerInput(Unit) {
                        detectDragGesturesAfterLongPress(
                            onDragStart = { onDragStart() },
                            onDrag = { change, dragAmount ->
                                change.consume()
                                onDrag(dragAmount.y)
                            },
                            onDragEnd = { onDragEnd() },
                            onDragCancel = { onDragEnd() }
                        )
                    }
            )

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = recording.title,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = formattedDate,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "•",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = recording.duration.formatTime(),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            IconButton(onClick = onRemoveClick) {
                Icon(
                    imageVector = Icons.Default.Remove,
                    contentDescription = "Remove from playlist",
                    tint = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

@Composable
fun PlaylistRecordingItem(
    recording: RecordingData,
    onItemClick: () -> Unit,
    onRemoveClick: () -> Unit
) {
    val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd")
    val formattedDate = recording.creationDate.format(formatter)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onItemClick() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = recording.title,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = formattedDate,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "•",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = recording.duration.formatTime(),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            IconButton(onClick = onRemoveClick) {
                Icon(
                    imageVector = Icons.Default.Remove,
                    contentDescription = "Remove from playlist",
                    tint = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

@Composable
fun AddRecordingSheet(
    recordings: List<RecordingData>,
    onAddRecording: (UUID) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "Add Recording",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (recordings.isEmpty()) {
            Text(
                text = "All recordings are already in this playlist",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(recordings) { recording ->
                    AddRecordingItem(
                        recording = recording,
                        onAddClick = { recording.uuid?.let { onAddRecording(it) } }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
fun AddRecordingItem(
    recording: RecordingData,
    onAddClick: () -> Unit
) {
    val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd")
    val formattedDate = recording.creationDate.format(formatter)

    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = recording.title,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = formattedDate,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "•",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = recording.duration.formatTime(),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            IconButton(onClick = onAddClick) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Add to playlist",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}
