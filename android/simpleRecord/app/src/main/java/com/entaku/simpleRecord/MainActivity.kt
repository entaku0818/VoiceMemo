package com.entaku.simpleRecord

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.play.PlaybackScreen
import com.entaku.simpleRecord.play.PlaybackViewModel
import com.entaku.simpleRecord.playlist.PlaylistDetailScreen
import com.entaku.simpleRecord.playlist.PlaylistDetailViewModel
import com.entaku.simpleRecord.playlist.PlaylistDetailViewModelFactory
import com.entaku.simpleRecord.playlist.PlaylistListScreen
import com.entaku.simpleRecord.playlist.PlaylistRepositoryImpl
import com.entaku.simpleRecord.playlist.PlaylistViewModel
import com.entaku.simpleRecord.playlist.PlaylistViewModelFactory
import com.entaku.simpleRecord.record.RecordScreen
import com.entaku.simpleRecord.record.RecordViewModel
import com.entaku.simpleRecord.record.RecordViewModelFactory
import com.entaku.simpleRecord.record.RecordingRepositoryImpl
import com.entaku.simpleRecord.record.RecordingsViewModelFactory
import com.entaku.simpleRecord.settings.RecordingSettingsScreen
import com.entaku.simpleRecord.settings.SettingsManager
import com.entaku.simpleRecord.cloudsync.CloudSyncScreen
import com.entaku.simpleRecord.cloudsync.CloudSyncViewModel
import com.entaku.simpleRecord.cloudsync.CloudSyncViewModelFactory
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppNavHost()
        }
    }
}

@Composable
fun AppNavHost() {
    val navController = rememberNavController()
    val context = LocalContext.current
    val sharedViewModel: SharedRecordingsViewModel = viewModel()

    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography
    ) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background
        ) { innerPadding ->
            NavHost(
                navController = navController,
                startDestination = Screen.Recordings.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.Recordings.route) {
                    val database = remember { AppDatabase.getInstance(context) }
                    val repository = remember { RecordingRepositoryImpl(database) }
                    val viewModelFactory = remember { RecordingsViewModelFactory(repository) }
                    val viewModel: RecordingsViewModel = viewModel(factory = viewModelFactory)

                    val state by viewModel.uiState.collectAsState()
                    val colorScheme = MaterialTheme.colorScheme

                    RecordingsScreen(
                        state = state,
                        onNavigateToRecordScreen = {
                            navController.navigate(Screen.Record.route)
                        },
                        onRefresh = viewModel::loadRecordings,
                        onNavigateToPlaybackScreen = { recordingData ->
                            sharedViewModel.selectRecording(recordingData)
                            navController.navigate(Screen.Playback.route)
                        },
                        onNavigateToPlaylists = {
                            navController.navigate(Screen.Playlists.route)
                        },
                        onNavigateToCloudSync = {
                            navController.navigate(Screen.CloudSync.route)
                        },
                        onDeleteClick = { uuid ->
                            viewModel.deleteRecording(uuid)
                        },
                        onEditRecordingName = { uuid,title ->
                            viewModel.updateRecordingTitle(uuid,title)
                        },
                        colorScheme = colorScheme
                    )
                }
                composable(Screen.Record.route) {
                    val database = remember { AppDatabase.getInstance(context) }
                    val repository = remember { RecordingRepositoryImpl(database) }
                    val settingsManager = remember { SettingsManager(context) }
                    val viewModelFactory = remember { RecordViewModelFactory(repository, settingsManager, sharedViewModel) }
                    val viewModel: RecordViewModel = viewModel(factory = viewModelFactory)
                    val uiStateFlow = viewModel.uiState

                    RecordScreen(
                        uiStateFlow = uiStateFlow,
                        onStartRecording = { viewModel.startRecording(context) },
                        onStopRecording = { viewModel.stopRecording() },
                        onPauseRecording = { viewModel.pauseRecording() },
                        onResumeRecording = { viewModel.resumeRecording() },
                        onNavigateBack = { navController.popBackStack() },
                        onNavigateToSettings = { 
                            // 録音中またはポーズ中でなければ設定画面に遷移
                            if (!sharedViewModel.isRecordingOrPaused()) {
                                navController.navigate(Screen.RecordingSettings.route)
                            }
                        }
                    )
                }
                composable(Screen.Playback.route) {
                    val selectedRecording by sharedViewModel.selectedRecording.collectAsState()
                    val playlistRecordings by sharedViewModel.playlistRecordings.collectAsState()
                    val playlistStartIndex by sharedViewModel.playlistStartIndex.collectAsState()
                    val isPlaylistMode by sharedViewModel.isPlaylistMode.collectAsState()
                    val playbackViewModel: PlaybackViewModel = viewModel()
                    val playbackState by playbackViewModel.playbackState.collectAsState()

                    // Get current recording from playlist or single mode
                    val currentRecording = if (playbackState.isPlaylistMode) {
                        playbackViewModel.getCurrentRecording() ?: selectedRecording
                    } else {
                        selectedRecording
                    }

                    currentRecording?.let { recordingData ->
                        LaunchedEffect(isPlaylistMode, playlistRecordings, playlistStartIndex, recordingData.filePath) {
                            if (isPlaylistMode && playlistRecordings.isNotEmpty()) {
                                playbackViewModel.setupPlaylist(playlistRecordings, playlistStartIndex)
                            } else {
                                playbackViewModel.setupMediaPlayer(recordingData.filePath)
                            }
                        }
                        PlaybackScreen(
                            recordingData = if (playbackState.isPlaylistMode) {
                                playbackViewModel.getCurrentRecording() ?: recordingData
                            } else {
                                recordingData
                            },
                            playbackState = playbackState,
                            onStop = {
                                playbackViewModel.stopPlayback()
                            },
                            onPlayPause = {
                                playbackViewModel.playOrPause()
                            },
                            onNavigateBack = { navController.popBackStack() },
                            onSpeedChange = { speed ->
                                playbackViewModel.setPlaybackSpeed(speed)
                            },
                            onToggleRepeat = {
                                playbackViewModel.toggleRepeatMode()
                            },
                            onToggleShuffle = {
                                playbackViewModel.toggleShuffle()
                            },
                            onPlayNext = {
                                playbackViewModel.playNext()
                            },
                            onPlayPrevious = {
                                playbackViewModel.playPrevious()
                            }
                        )
                    }
                }
                
                composable(Screen.RecordingSettings.route) {
                    // 録音中またはポーズ中なら録音画面に戻る
                    if (sharedViewModel.isRecordingOrPaused()) {
                        LaunchedEffect(Unit) {
                            navController.popBackStack()
                        }
                    } else {
                        val settingsManager = remember { SettingsManager(context) }
                        val currentSettings = remember { settingsManager.getRecordingSettings() }

                        RecordingSettingsScreen(
                            currentSettings = currentSettings,
                            onSettingsChanged = { newSettings ->
                                settingsManager.saveRecordingSettings(newSettings)
                            },
                            onNavigateBack = { navController.popBackStack() }
                        )
                    }
                }

                composable(Screen.Playlists.route) {
                    val database = remember { AppDatabase.getInstance(context) }
                    val playlistRepository = remember { PlaylistRepositoryImpl(database) }
                    val viewModelFactory = remember { PlaylistViewModelFactory(playlistRepository) }
                    val playlistViewModel: PlaylistViewModel = viewModel(factory = viewModelFactory)

                    val state by playlistViewModel.uiState.collectAsState()
                    val colorScheme = MaterialTheme.colorScheme

                    PlaylistListScreen(
                        state = state,
                        onRefresh = playlistViewModel::loadPlaylists,
                        onNavigateToPlaylistDetail = { playlistId ->
                            navController.navigate(Screen.PlaylistDetail.createRoute(playlistId.toString()))
                        },
                        onCreatePlaylist = playlistViewModel::createPlaylist,
                        onEditPlaylistName = playlistViewModel::updatePlaylistName,
                        onDeletePlaylist = playlistViewModel::deletePlaylist,
                        onNavigateBack = { navController.popBackStack() },
                        colorScheme = colorScheme
                    )
                }

                composable(
                    route = Screen.PlaylistDetail.route,
                    arguments = listOf(navArgument("playlistId") { type = NavType.StringType })
                ) { backStackEntry ->
                    val playlistIdString = backStackEntry.arguments?.getString("playlistId") ?: return@composable
                    val playlistId = UUID.fromString(playlistIdString)

                    val database = remember { AppDatabase.getInstance(context) }
                    val playlistRepository = remember { PlaylistRepositoryImpl(database) }
                    val recordingRepository = remember { RecordingRepositoryImpl(database) }
                    val viewModelFactory = remember { PlaylistDetailViewModelFactory(playlistRepository, playlistId) }
                    val detailViewModel: PlaylistDetailViewModel = viewModel(factory = viewModelFactory)
                    val recordingsViewModelFactory = remember { RecordingsViewModelFactory(recordingRepository) }
                    val recordingsViewModel: RecordingsViewModel = viewModel(factory = recordingsViewModelFactory)

                    val state by detailViewModel.uiState.collectAsState()
                    val recordingsState by recordingsViewModel.uiState.collectAsState()
                    val colorScheme = MaterialTheme.colorScheme

                    LaunchedEffect(Unit) {
                        recordingsViewModel.loadRecordings()
                    }

                    PlaylistDetailScreen(
                        state = state,
                        allRecordings = recordingsState.recordings,
                        onNavigateBack = { navController.popBackStack() },
                        onNavigateToPlayback = { recordingData ->
                            sharedViewModel.selectRecording(recordingData)
                            navController.navigate(Screen.Playback.route)
                        },
                        onPlayAll = { recordings, startIndex ->
                            sharedViewModel.selectPlaylist(recordings, startIndex)
                            navController.navigate(Screen.Playback.route)
                        },
                        onAddRecording = detailViewModel::addRecording,
                        onRemoveRecording = detailViewModel::removeRecording,
                        onReorder = detailViewModel::reorderRecordings,
                        colorScheme = colorScheme
                    )
                }

                composable(Screen.CloudSync.route) {
                    val viewModelFactory = remember { CloudSyncViewModelFactory(context) }
                    val cloudSyncViewModel: CloudSyncViewModel = viewModel(factory = viewModelFactory)

                    CloudSyncScreen(
                        viewModel = cloudSyncViewModel,
                        onNavigateBack = { navController.popBackStack() }
                    )
                }
            }
        }
    }
}

sealed class Screen(val route: String, val title: String) {
    object Recordings : Screen("recordings", "Recordings")
    object Record : Screen("record", "Record")
    object Playback : Screen("playback", "Playback")
    object RecordingSettings : Screen("recording_settings", "Recording Settings")
    object Playlists : Screen("playlists", "Playlists")
    object PlaylistDetail : Screen("playlist_detail/{playlistId}", "Playlist Detail") {
        fun createRoute(playlistId: String) = "playlist_detail/$playlistId"
    }
    object CloudSync : Screen("cloud_sync", "Cloud Sync")
}
