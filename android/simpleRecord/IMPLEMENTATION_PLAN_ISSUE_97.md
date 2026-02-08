# Issue #97 実装計画書
# Android: プレイリスト機能の完全実装

## 目次
1. [現状分析](#現状分析)
2. [実装計画](#実装計画)
3. [詳細設計](#詳細設計)
4. [テスト計画](#テスト計画)

---

## 現状分析

### ✅ 実装済み機能（コミット3）

#### データ層（Room Database）
**ファイル**: `app/src/main/java/com/entaku/simpleRecord/db/PlaylistDao.kt`

```kotlin
// 既存実装
@Entity(tableName = "playlists")
data class PlaylistEntity(...)

@Entity(tableName = "playlist_recording_cross_ref")
data class PlaylistRecordingCrossRef(
    val playlistUuid: UUID,
    val recordingUuid: UUID,
    val position: Int  // ✅ 並び順フィールド既に存在
)

@Dao
interface PlaylistDao {
    // ✅ 基本CRUD実装済み
    suspend fun insert(playlist: PlaylistEntity)
    suspend fun update(playlist: PlaylistEntity)
    suspend fun delete(uuid: UUID)

    // ✅ position順ソート実装済み
    fun getRecordingsForPlaylist(playlistUuid: UUID): Flow<List<RecordingEntity>>

    // ✅ 位置計算実装済み
    suspend fun getNextPosition(playlistUuid: UUID): Int
}
```

#### UI層
**ファイル**:
- `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistScreen.kt`
- `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistDetailScreen.kt`
- `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistViewModel.kt`

**実装済み:**
- プレイリスト一覧表示
- プレイリスト作成/編集/削除
- 録音の追加/削除
- 基本的なLazyColumn表示

#### 再生機能（単一トラック）
**ファイル**:
- `app/src/main/java/com/entaku/simpleRecord/play/PlaybackViewModel.kt`

```kotlin
// 既存実装
class PlaybackViewModel : ViewModel() {
    private var mediaPlayer: MediaPlayer? = null

    fun setupMediaPlayer(filePath: String)
    fun playOrPause()
    fun setPlaybackSpeed(speed: Float)  // ✅ 0.5x - 2.0x
    fun stopPlayback()
}
```

---

### ❌ 未実装機能（コミット4）

#### 1. ドラッグ&ドロップ並べ替え
- [ ] LazyColumn でのドラッグ&ドロップUI
- [ ] position更新クエリ
- [ ] 並べ替え時のアニメーション
- [ ] 並び順の永続化

#### 2. プレイリスト再生機能
- [ ] 連続再生ロジック
- [ ] 自動次トラック再生
- [ ] 前/次トラック操作
- [ ] トラック完了ハンドリング

#### 3. リピート/シャッフル機能
- [ ] リピートモード（OFF/ONE/ALL）
- [ ] シャッフルモード
- [ ] UI制御

#### 4. プレイリスト再生UI
- [ ] プレイリスト再生画面
- [ ] 現在再生中トラック表示
- [ ] プレイリストから再生開始

---

## 実装計画

### Phase 1: ドラッグ&ドロップ並べ替え（優先度: 🔴 最高）
**見積もり**: 1-2日

#### 1.1 DAO拡張
**ファイル**: `app/src/main/java/com/entaku/simpleRecord/db/PlaylistDao.kt`

```kotlin
@Dao
interface PlaylistDao {
    // 追加: position更新クエリ
    @Query("""
        UPDATE playlist_recording_cross_ref
        SET position = :newPosition
        WHERE playlist_uuid = :playlistUuid AND recording_uuid = :recordingUuid
    """)
    suspend fun updatePosition(
        playlistUuid: UUID,
        recordingUuid: UUID,
        newPosition: Int
    )

    // 追加: 複数position一括更新
    @Transaction
    suspend fun reorderRecordings(
        playlistUuid: UUID,
        reorderedRecordings: List<Pair<UUID, Int>>
    ) {
        reorderedRecordings.forEach { (recordingUuid, position) ->
            updatePosition(playlistUuid, recordingUuid, position)
        }
    }
}
```

#### 1.2 ViewModel拡張
**ファイル**: `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistViewModel.kt`

```kotlin
class PlaylistViewModel @Inject constructor(
    private val repository: PlaylistRepository
) : ViewModel() {

    // 追加: 並べ替え処理
    fun reorderRecordings(
        playlistUuid: UUID,
        fromIndex: Int,
        toIndex: Int,
        recordings: List<RecordingData>
    ) {
        viewModelScope.launch {
            val reorderedList = recordings.toMutableList().apply {
                val item = removeAt(fromIndex)
                add(toIndex, item)
            }

            val updatedPositions = reorderedList.mapIndexed { index, recording ->
                recording.uuid to index
            }

            repository.reorderRecordings(playlistUuid, updatedPositions)
        }
    }
}
```

#### 1.3 UI実装（ドラッグ&ドロップ）
**ファイル**: `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistDetailScreen.kt`

**依存関係追加** (`app/build.gradle.kts`):
```kotlin
dependencies {
    // Drag and Drop support
    implementation("org.burnoutcrew.composereorderable:reorderable:0.9.6")
}
```

**実装例**:
```kotlin
import org.burnoutcrew.reorderable.*

@Composable
fun PlaylistDetailScreen(
    // ... existing parameters
    onReorderRecordings: (Int, Int, List<RecordingData>) -> Unit
) {
    val reorderableState = rememberReorderableLazyListState(
        onMove = { from, to ->
            // リアルタイムでリスト並べ替え（UI更新）
            recordings = recordings.toMutableList().apply {
                add(to.index, removeAt(from.index))
            }
        },
        onDragEnd = { fromIndex, toIndex ->
            // ドラッグ完了時にデータベース更新
            onReorderRecordings(fromIndex, toIndex, recordings)
        }
    )

    LazyColumn(
        state = reorderableState.listState,
        modifier = Modifier
            .fillMaxSize()
            .reorderable(reorderableState)
    ) {
        items(
            items = recordings,
            key = { it.uuid }
        ) { recording ->
            ReorderableItem(
                reorderableState = reorderableState,
                key = recording.uuid
            ) { isDragging ->
                RecordingItemWithDragHandle(
                    recording = recording,
                    isDragging = isDragging,
                    onRemove = { onRemoveRecording(recording.uuid) },
                    onClick = { onNavigateToPlayback(recording) }
                )
            }
        }
    }
}

@Composable
fun RecordingItemWithDragHandle(
    recording: RecordingData,
    isDragging: Boolean,
    onRemove: () -> Unit,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp)
            .clickable(onClick = onClick),
        elevation = if (isDragging) 8.dp else 2.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // ドラッグハンドル
            Icon(
                imageVector = Icons.Default.DragHandle,
                contentDescription = "Reorder",
                modifier = Modifier
                    .padding(end = 16.dp)
                    .detectReorder(reorderableState)
            )

            // 録音情報表示
            Column(modifier = Modifier.weight(1f)) {
                Text(recording.title)
                Text(
                    text = formatTime(recording.duration),
                    style = MaterialTheme.typography.bodySmall
                )
            }

            // 削除ボタン
            IconButton(onClick = onRemove) {
                Icon(Icons.Default.Remove, contentDescription = "Remove")
            }
        }
    }
}
```

**受け入れ基準**:
- [ ] リスト項目を長押しでドラッグ開始
- [ ] ドラッグ中、視覚的フィードバック表示
- [ ] ドロップ時、positionがデータベースに保存される
- [ ] アプリ再起動後も並び順が保持される

---

### Phase 2: プレイリスト再生機能（優先度: 🔴 最高）
**見積もり**: 2-3日

#### 2.1 プレイリスト再生ViewModel作成
**新規ファイル**: `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistPlaybackViewModel.kt`

```kotlin
package com.entaku.simpleRecord.playlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.RecordingData
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

enum class RepeatMode {
    OFF,    // リピートなし
    ONE,    // 1曲リピート
    ALL     // 全曲リピート
}

data class PlaylistPlaybackState(
    val playlist: List<RecordingData> = emptyList(),
    val currentIndex: Int = 0,
    val repeatMode: RepeatMode = RepeatMode.OFF,
    val shuffleEnabled: Boolean = false,
    val isPlaying: Boolean = false
) {
    val currentRecording: RecordingData?
        get() = playlist.getOrNull(currentIndex)

    val hasNext: Boolean
        get() = when {
            shuffleEnabled -> playlist.size > 1
            repeatMode == RepeatMode.ALL -> true
            else -> currentIndex < playlist.size - 1
        }

    val hasPrevious: Boolean
        get() = when {
            shuffleEnabled -> playlist.size > 1
            repeatMode == RepeatMode.ALL -> true
            else -> currentIndex > 0
        }
}

class PlaylistPlaybackViewModel @Inject constructor() : ViewModel() {

    private val _state = MutableStateFlow(PlaylistPlaybackState())
    val state: StateFlow<PlaylistPlaybackState> = _state

    private var originalPlaylist: List<RecordingData> = emptyList()
    private val playedIndices = mutableSetOf<Int>()

    /**
     * プレイリスト再生開始
     */
    fun startPlaylistPlayback(
        recordings: List<RecordingData>,
        startIndex: Int = 0
    ) {
        originalPlaylist = recordings
        playedIndices.clear()

        _state.update {
            it.copy(
                playlist = if (it.shuffleEnabled) {
                    shufflePlaylist(recordings, startIndex)
                } else {
                    recordings
                },
                currentIndex = if (it.shuffleEnabled) 0 else startIndex,
                isPlaying = true
            )
        }
    }

    /**
     * 次のトラックへ
     */
    fun playNext() {
        val currentState = _state.value

        when {
            // シャッフル有効
            currentState.shuffleEnabled -> {
                playedIndices.add(currentState.currentIndex)

                if (playedIndices.size >= currentState.playlist.size) {
                    // 全曲再生完了
                    if (currentState.repeatMode == RepeatMode.ALL) {
                        playedIndices.clear()
                        _state.update { it.copy(currentIndex = 0) }
                    } else {
                        stopPlayback()
                    }
                } else {
                    // ランダムに次のインデックス選択
                    val unplayedIndices = currentState.playlist.indices.toSet() - playedIndices
                    val nextIndex = unplayedIndices.random()
                    _state.update { it.copy(currentIndex = nextIndex) }
                }
            }

            // 1曲リピート
            currentState.repeatMode == RepeatMode.ONE -> {
                // 同じ曲を再生
                _state.update { it }
            }

            // 最後のトラック
            currentState.currentIndex >= currentState.playlist.size - 1 -> {
                if (currentState.repeatMode == RepeatMode.ALL) {
                    _state.update { it.copy(currentIndex = 0) }
                } else {
                    stopPlayback()
                }
            }

            // 通常の次へ
            else -> {
                _state.update { it.copy(currentIndex = it.currentIndex + 1) }
            }
        }
    }

    /**
     * 前のトラックへ
     */
    fun playPrevious() {
        val currentState = _state.value

        when {
            currentState.shuffleEnabled -> {
                // シャッフル時は再生済みから選択
                if (playedIndices.isNotEmpty()) {
                    val previousIndex = playedIndices.last()
                    playedIndices.remove(previousIndex)
                    _state.update { it.copy(currentIndex = previousIndex) }
                }
            }

            currentState.currentIndex > 0 -> {
                _state.update { it.copy(currentIndex = it.currentIndex - 1) }
            }

            currentState.repeatMode == RepeatMode.ALL -> {
                _state.update { it.copy(currentIndex = it.playlist.size - 1) }
            }
        }
    }

    /**
     * リピートモード切り替え
     */
    fun toggleRepeat() {
        _state.update {
            it.copy(
                repeatMode = when (it.repeatMode) {
                    RepeatMode.OFF -> RepeatMode.ONE
                    RepeatMode.ONE -> RepeatMode.ALL
                    RepeatMode.ALL -> RepeatMode.OFF
                }
            )
        }
    }

    /**
     * シャッフル切り替え
     */
    fun toggleShuffle() {
        _state.update { currentState ->
            val newShuffleEnabled = !currentState.shuffleEnabled

            if (newShuffleEnabled) {
                // シャッフル有効化
                val currentRecording = currentState.currentRecording
                val shuffled = shufflePlaylist(originalPlaylist, currentState.currentIndex)
                playedIndices.clear()

                currentState.copy(
                    shuffleEnabled = true,
                    playlist = shuffled,
                    currentIndex = 0
                )
            } else {
                // シャッフル解除
                val currentRecording = currentState.currentRecording
                val originalIndex = originalPlaylist.indexOf(currentRecording)

                currentState.copy(
                    shuffleEnabled = false,
                    playlist = originalPlaylist,
                    currentIndex = originalIndex.takeIf { it >= 0 } ?: 0
                )
            }
        }
    }

    /**
     * トラック完了時の処理
     */
    fun onTrackComplete() {
        if (_state.value.repeatMode == RepeatMode.ONE) {
            // 1曲リピート: 同じ曲を再生
            return
        }

        if (_state.value.hasNext) {
            playNext()
        } else {
            stopPlayback()
        }
    }

    /**
     * 再生停止
     */
    fun stopPlayback() {
        _state.update {
            it.copy(
                isPlaying = false,
                currentIndex = 0
            )
        }
    }

    /**
     * プレイリストをシャッフル
     */
    private fun shufflePlaylist(
        recordings: List<RecordingData>,
        currentIndex: Int
    ): List<RecordingData> {
        val current = recordings[currentIndex]
        val others = recordings.toMutableList().apply { removeAt(currentIndex) }.shuffled()
        return listOf(current) + others
    }
}
```

#### 2.2 PlaybackViewModel拡張（完了コールバック）
**ファイル**: `app/src/main/java/com/entaku/simpleRecord/play/PlaybackViewModel.kt`

```kotlin
class PlaybackViewModel : ViewModel() {

    // 追加: 完了コールバック
    private var onCompletionCallback: (() -> Unit)? = null

    fun setupMediaPlayer(filePath: String) {
        mediaPlayer = MediaPlayer().apply {
            try {
                setDataSource(filePath)
                prepare()

                // 追加: 完了リスナー設定
                setOnCompletionListener {
                    _playbackState.update { it.copy(isPlaying = false) }
                    onCompletionCallback?.invoke()
                }
            } catch (e: IOException) {
                Log.e("MediaPlayer", "Failed to set data source", e)
            }
        }
    }

    // 追加: 完了コールバック設定
    fun setOnCompletionListener(callback: () -> Unit) {
        onCompletionCallback = callback
    }

    // 追加: コールバッククリア
    fun clearOnCompletionListener() {
        onCompletionCallback = null
    }
}
```

**受け入れ基準**:
- [ ] プレイリストから連続再生できる
- [ ] 次/前トラックボタンで移動できる
- [ ] トラック完了時、自動で次へ進む
- [ ] RepeatMode.ONEで同じ曲を繰り返す
- [ ] RepeatMode.ALLでプレイリストを繰り返す
- [ ] シャッフル有効時、ランダム順で再生される

---

### Phase 3: リピート/シャッフルUI実装（優先度: 🟡 中）
**見積もり**: 1-2日

#### 3.1 プレイリスト再生UI
**新規ファイル**: `app/src/main/java/com/entaku/simpleRecord/playlist/PlaylistPlaybackScreen.kt`

```kotlin
package com.entaku.simpleRecord.playlist

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaylistPlaybackScreen(
    playlistState: PlaylistPlaybackState,
    playbackState: PlaybackState,
    onPlayPrevious: () -> Unit,
    onPlayOrPause: () -> Unit,
    onPlayNext: () -> Unit,
    onToggleRepeat: () -> Unit,
    onToggleShuffle: () -> Unit,
    onClose: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Playlist Playback") },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(Icons.Default.Close, "Close")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // 現在再生中のトラック情報
            playlistState.currentRecording?.let { recording ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp)
                    ) {
                        Text(
                            text = recording.title,
                            style = MaterialTheme.typography.headlineSmall
                        )
                        Text(
                            text = "${playlistState.currentIndex + 1} / ${playlistState.playlist.size}",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // コントロールボタン
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // シャッフルボタン
                IconButton(onClick = onToggleShuffle) {
                    Icon(
                        imageVector = Icons.Default.Shuffle,
                        contentDescription = "Shuffle",
                        tint = if (playlistState.shuffleEnabled) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                        }
                    )
                }

                // 前へ
                IconButton(
                    onClick = onPlayPrevious,
                    enabled = playlistState.hasPrevious
                ) {
                    Icon(Icons.Default.SkipPrevious, "Previous")
                }

                // 再生/一時停止
                FloatingActionButton(onClick = onPlayOrPause) {
                    Icon(
                        imageVector = if (playbackState.isPlaying) {
                            Icons.Default.Pause
                        } else {
                            Icons.Default.PlayArrow
                        },
                        contentDescription = if (playbackState.isPlaying) "Pause" else "Play"
                    )
                }

                // 次へ
                IconButton(
                    onClick = onPlayNext,
                    enabled = playlistState.hasNext
                ) {
                    Icon(Icons.Default.SkipNext, "Next")
                }

                // リピートボタン
                IconButton(onClick = onToggleRepeat) {
                    val (icon, tint) = when (playlistState.repeatMode) {
                        RepeatMode.OFF -> Icons.Default.Repeat to MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                        RepeatMode.ONE -> Icons.Default.RepeatOne to MaterialTheme.colorScheme.primary
                        RepeatMode.ALL -> Icons.Default.Repeat to MaterialTheme.colorScheme.primary
                    }
                    Icon(
                        imageVector = icon,
                        contentDescription = "Repeat",
                        tint = tint
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // プレイリスト内容表示
            Text(
                text = "Playlist",
                style = MaterialTheme.typography.titleMedium
            )

            LazyColumn(
                modifier = Modifier.fillMaxWidth()
            ) {
                items(
                    items = playlistState.playlist,
                    key = { it.uuid }
                ) { recording ->
                    ListItem(
                        headlineContent = { Text(recording.title) },
                        supportingContent = { Text(formatTime(recording.duration)) },
                        leadingContent = {
                            if (recording == playlistState.currentRecording) {
                                Icon(
                                    Icons.Default.MusicNote,
                                    contentDescription = "Playing",
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        },
                        modifier = Modifier.clickable {
                            // トラックをクリックで再生
                        }
                    )
                }
            }
        }
    }
}
```

#### 3.2 PlaylistDetailScreenにプレイリスト再生ボタン追加

```kotlin
// PlaylistDetailScreen.kt に追加
@Composable
fun PlaylistDetailScreen(
    // ... existing parameters
    onPlayPlaylist: () -> Unit  // 追加
) {
    Scaffold(
        // ... existing code
        floatingActionButton = {
            Column {
                // 既存の追加ボタン
                if (availableRecordings.isNotEmpty()) {
                    FloatingActionButton(
                        onClick = { showAddRecordingSheet = true }
                    ) {
                        Icon(Icons.Default.Add, "Add Recording")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 新規: プレイリスト再生ボタン
                if (state.recordings.isNotEmpty()) {
                    FloatingActionButton(
                        onClick = onPlayPlaylist,
                        containerColor = colorScheme.secondary
                    ) {
                        Icon(Icons.Default.PlayArrow, "Play Playlist")
                    }
                }
            }
        }
    ) {
        // ... existing content
    }
}
```

**受け入れ基準**:
- [ ] プレイリスト詳細画面から「プレイリスト再生」ボタンが表示される
- [ ] ボタンタップでプレイリスト再生画面に遷移
- [ ] 再生中トラックがハイライト表示される
- [ ] リピート/シャッフルボタンが正常に動作
- [ ] 前/次ボタンが適切に有効/無効になる

---

## テスト計画

### ユニットテスト

#### PlaylistDaoTest
```kotlin
@RunWith(AndroidJUnit4::class)
class PlaylistDaoTest {

    @Test
    fun testReorderRecordings() = runBlocking {
        // Given: プレイリストに3つの録音
        val playlist = createTestPlaylist()
        val recordings = listOf(
            createRecording("A", 0),
            createRecording("B", 1),
            createRecording("C", 2)
        )

        // When: BとCを入れ替え
        playlistDao.reorderRecordings(
            playlist.uuid,
            listOf(
                recordings[0].uuid to 0,
                recordings[2].uuid to 1,  // C
                recordings[1].uuid to 2   // B
            )
        )

        // Then: 並び順が [A, C, B] になる
        val result = playlistDao.getRecordingsForPlaylist(playlist.uuid).first()
        assertEquals("A", result[0].title)
        assertEquals("C", result[1].title)
        assertEquals("B", result[2].title)
    }
}
```

#### PlaylistPlaybackViewModelTest
```kotlin
@Test
fun testPlayNext_withRepeatAll() {
    // Given: 3曲のプレイリスト、RepeatMode.ALL
    viewModel.startPlaylistPlayback(testRecordings)
    viewModel.toggleRepeat() // OFF -> ONE
    viewModel.toggleRepeat() // ONE -> ALL

    // When: 最後の曲で次へ
    viewModel._state.update { it.copy(currentIndex = 2) }
    viewModel.playNext()

    // Then: 最初の曲に戻る
    assertEquals(0, viewModel.state.value.currentIndex)
    assertTrue(viewModel.state.value.isPlaying)
}

@Test
fun testToggleShuffle() {
    // Given: 5曲のプレイリスト
    viewModel.startPlaylistPlayback(testRecordings)

    // When: シャッフル有効化
    viewModel.toggleShuffle()

    // Then: プレイリスト順序が変更され、シャッフル有効
    assertTrue(viewModel.state.value.shuffleEnabled)
    assertNotEquals(testRecordings, viewModel.state.value.playlist)
}
```

### UIテスト（Espresso）

```kotlin
@RunWith(AndroidJUnit4::class)
class PlaylistPlaybackScreenTest {

    @Test
    fun testPlaylistPlayback_playNextButton() {
        // Given: プレイリスト再生画面表示
        launchPlaylistPlaybackScreen()

        // When: 次へボタンをタップ
        onView(withContentDescription("Next")).perform(click())

        // Then: 次のトラックに移動
        onView(withText("2 / 5")).check(matches(isDisplayed()))
    }

    @Test
    fun testDragAndDrop_reorderRecording() {
        // Given: プレイリスト詳細画面
        launchPlaylistDetailScreen()

        // When: 1番目の項目を3番目にドラッグ
        onView(withId(R.id.recording_list))
            .perform(dragAndDrop(0, 2))

        // Then: 並び順が変更される
        // 実装後に検証ロジック追加
    }
}
```

---

## 実装スケジュール

| Phase | タスク | 見積もり | 担当 | 開始日 | 完了日 |
|-------|--------|----------|------|--------|--------|
| 1 | DAO拡張 | 0.5日 | | | |
| 1 | ViewModel拡張 | 0.5日 | | | |
| 1 | ドラッグ&ドロップUI | 1日 | | | |
| 1 | テスト実装 | 0.5日 | | | |
| 2 | PlaylistPlaybackViewModel | 1.5日 | | | |
| 2 | PlaybackViewModel拡張 | 0.5日 | | | |
| 2 | テスト実装 | 1日 | | | |
| 3 | プレイリスト再生UI | 1.5日 | | | |
| 3 | UIテスト実装 | 0.5日 | | | |
| - | バッファ | 1日 | | | |
| **合計** | | **8-9日** | | | |

---

## iOS版との機能比較

### iOS実装参考
**ファイル**: `ios/VoiLog/Playlist/PlaylistListFeature.swift`

iOS版で実装されている機能:
- ✅ プレイリストCRUD
- ✅ ドラッグ&ドロップ並べ替え (SwiftUI)
- ✅ プレイリスト再生
- ✅ 自動次トラック再生

この実装計画により、Android版がiOS版と同等の機能を持つことになります。

---

## 参考リンク

- [Jetpack Compose Drag & Drop](https://github.com/aclassen/ComposeReorderable)
- [Android MediaPlayer](https://developer.android.com/guide/topics/media/mediaplayer)
- [Room Database](https://developer.android.com/training/data-storage/room)
- [iOS PlaylistListFeature](https://github.com/entaku0818/VoiceMemo/blob/main/ios/VoiLog/Playlist/PlaylistListFeature.swift)

---

## 更新履歴
- 2026-02-09: 初版作成（Issue #97 作成時）
