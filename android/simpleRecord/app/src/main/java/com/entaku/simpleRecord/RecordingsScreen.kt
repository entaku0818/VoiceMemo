package com.entaku.simpleRecord

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordingsScreen(
    state: RecordingsUiState,
    onNavigateToRecordScreen: () -> Unit = {},
    onRefresh: () -> Unit,
    onNavigateToPlaybackScreen: (RecordingData) -> Unit,
    onNavigateToPlaylists: () -> Unit = {},
    onNavigateToCloudSync: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToTranscription: (RecordingData) -> Unit = {},
    onDeleteClick: (UUID) -> Unit,
    onEditRecordingName: (UUID, String) -> Unit,
    onSearchQueryChange: (String) -> Unit = {},
    onSortOptionSelected: (SortOption) -> Unit = {},
    onDurationFilterSelected: (DurationFilter) -> Unit = {},
    colorScheme: ColorScheme
) {
    LaunchedEffect(key1 = Unit) {
        onRefresh()
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.recordings_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onNavigateToCloudSync) {
                    Icon(Icons.Default.Cloud, contentDescription = stringResource(R.string.cloud_sync))
                }
            }
        },
        bottomBar = {
            BannerAdView(modifier = Modifier.fillMaxWidth())
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            RecordingsSearchAndFilterBar(
                searchQuery = state.searchQuery,
                onSearchQueryChange = onSearchQueryChange,
                sortOption = state.sortOption,
                onSortOptionSelected = onSortOptionSelected,
                durationFilter = state.durationFilter,
                onDurationFilterSelected = onDurationFilterSelected
            )

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
                            Icons.Default.Mic,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        val isFiltered = state.searchQuery.isNotBlank() || state.durationFilter != DurationFilter.ALL
                        Text(
                            text = stringResource(
                                if (isFiltered) R.string.no_search_results else R.string.no_recordings
                            ),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (!isFiltered) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = stringResource(R.string.tap_mic_to_record),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp)
                ) {
                    items(state.recordings) { recording ->
                        RecordingListItem(
                            recording = recording,
                            onItemClick = { onNavigateToPlaybackScreen(recording) },
                            onDeleteClick = { recording.uuid?.let { onDeleteClick(it) } },
                            onEditNameClick = { newTitle ->
                                recording.uuid?.let { onEditRecordingName(it, newTitle) }
                            },
                            onTranscribeClick = { onNavigateToTranscription(recording) }
                        )
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun SortOption.displayName(): String = stringResource(
    when (this) {
        SortOption.DATE_DESCENDING -> R.string.sort_date_descending
        SortOption.DATE_ASCENDING -> R.string.sort_date_ascending
        SortOption.TITLE_ASCENDING -> R.string.sort_title_ascending
        SortOption.TITLE_DESCENDING -> R.string.sort_title_descending
        SortOption.DURATION_DESCENDING -> R.string.sort_duration_descending
        SortOption.DURATION_ASCENDING -> R.string.sort_duration_ascending
    }
)

@Composable
private fun DurationFilter.displayName(): String = stringResource(
    when (this) {
        DurationFilter.ALL -> R.string.duration_filter_all
        DurationFilter.SHORT -> R.string.duration_filter_short
        DurationFilter.MEDIUM -> R.string.duration_filter_medium
        DurationFilter.LONG -> R.string.duration_filter_long
    }
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecordingsSearchAndFilterBar(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    sortOption: SortOption,
    onSortOptionSelected: (SortOption) -> Unit,
    durationFilter: DurationFilter,
    onDurationFilterSelected: (DurationFilter) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            placeholder = { Text(stringResource(R.string.search_recordings_placeholder)) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            trailingIcon = {
                if (searchQuery.isNotEmpty()) {
                    IconButton(onClick = { onSearchQueryChange("") }) {
                        Icon(Icons.Default.Clear, contentDescription = stringResource(R.string.clear_search))
                    }
                }
            }
        )

        Spacer(modifier = Modifier.height(8.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            var sortMenuExpanded by remember { mutableStateOf(false) }
            Box {
                IconButton(onClick = { sortMenuExpanded = true }) {
                    Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = stringResource(R.string.sort_by))
                }
                DropdownMenu(
                    expanded = sortMenuExpanded,
                    onDismissRequest = { sortMenuExpanded = false }
                ) {
                    SortOption.entries.forEach { option ->
                        DropdownMenuItem(
                            onClick = {
                                sortMenuExpanded = false
                                onSortOptionSelected(option)
                            },
                            text = { Text(option.displayName()) }
                        )
                    }
                }
            }
            Text(
                text = sortOption.displayName(),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(DurationFilter.entries) { filter ->
                FilterChip(
                    selected = filter == durationFilter,
                    onClick = { onDurationFilterSelected(filter) },
                    label = { Text(filter.displayName()) }
                )
            }
        }
    }
}

@Composable
fun RecordingListItem(
    recording: RecordingData,
    onItemClick: () -> Unit,
    onDeleteClick: () -> Unit,
    onEditNameClick: (String) -> Unit,
    onTranscribeClick: () -> Unit = {}
) {
    val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd")
    val formattedDate = recording.creationDate.format(formatter)

    var expanded by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showEditNameDialog by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 再生ボタン (iOS と同様に左端)
        IconButton(onClick = onItemClick) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp)
            )
        }

        Spacer(modifier = Modifier.width(4.dp))

        // タイトル + 日付
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = recording.title.ifEmpty { stringResource(R.string.untitled_recording) },
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = formattedDate,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // 再生時間
        Text(
            text = recording.duration.formatTime(),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.width(4.dp))

        // メニュー
        Box {
            IconButton(onClick = { expanded = true }) {
                Icon(
                    imageVector = Icons.Default.MoreVert,
                    contentDescription = stringResource(R.string.more_options),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                DropdownMenuItem(
                    onClick = { expanded = false; showEditNameDialog = true },
                    text = { Text(stringResource(R.string.edit_name)) },
                    leadingIcon = { Icon(Icons.Default.Edit, contentDescription = null) }
                )
                DropdownMenuItem(
                    onClick = { expanded = false; onTranscribeClick() },
                    text = { Text(stringResource(R.string.transcription_title)) },
                    leadingIcon = { Icon(Icons.Default.TextFields, contentDescription = null) }
                )
                DropdownMenuItem(
                    onClick = { expanded = false; showDeleteDialog = true },
                    text = { Text(stringResource(R.string.delete)) },
                    leadingIcon = { Icon(Icons.Default.Delete, contentDescription = null) }
                )
            }
        }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text(stringResource(R.string.delete_confirm_title)) },
            text = { Text(stringResource(R.string.delete_confirm_message)) },
            confirmButton = {
                Button(onClick = { onDeleteClick(); showDeleteDialog = false }) {
                    Text(stringResource(R.string.yes))
                }
            },
            dismissButton = {
                Button(onClick = { showDeleteDialog = false }) {
                    Text(stringResource(R.string.no))
                }
            }
        )
    }

    if (showEditNameDialog) {
        EditNameDialog(
            currentName = recording.title,
            onConfirm = { newName -> onEditNameClick(newName) },
            onDismiss = { showEditNameDialog = false }
        )
    }
}

@Composable
fun EditNameDialog(
    currentName: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var newName by remember { mutableStateOf(currentName) }

    AlertDialog(
        onDismissRequest = { onDismiss() },
        title = { Text(stringResource(R.string.edit_name_title)) },
        text = {
            Column {
                Text(stringResource(R.string.edit_name_prompt))
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = newName,
                    onValueChange = { newName = it },
                    label = { Text(stringResource(R.string.edit_name_label)) },
                    singleLine = true
                )
            }
        },
        confirmButton = {
            Button(onClick = { onConfirm(newName); onDismiss() }) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = {
            Button(onClick = { onDismiss() }) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Preview(showBackground = true)
@Composable
fun PreviewRecordingsScreen() {
    val sampleRecordings = List(5) { index ->
        RecordingData(
            uuid = UUID.randomUUID(),
            title = "録音 ${index + 1}",
            creationDate = LocalDateTime.now().minusDays(index.toLong()),
            fileExtension = "m4a",
            khz = "44",
            bitRate = 16,
            channels = 1,
            duration = 120,
            filePath = "/path/to/recording${index + 1}.m4a"
        )
    }
    RecordingsScreen(
        state = RecordingsUiState(recordings = sampleRecordings, isLoading = false, error = null),
        onNavigateToRecordScreen = {},
        onRefresh = {},
        onNavigateToPlaybackScreen = {},
        onNavigateToPlaylists = {},
        onNavigateToCloudSync = {},
        onNavigateToSettings = {},
        onDeleteClick = {},
        onEditRecordingName = { _, _ -> },
        colorScheme = LightColorScheme
    )
}
