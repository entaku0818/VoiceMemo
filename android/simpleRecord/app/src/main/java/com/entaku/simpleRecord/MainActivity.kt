package com.entaku.simpleRecord

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.entaku.simpleRecord.cloudsync.CloudSyncScreen
import com.entaku.simpleRecord.cloudsync.CloudSyncViewModel
import com.entaku.simpleRecord.cloudsync.CloudSyncViewModelFactory
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.feedback.FeedbackScreen
import com.entaku.simpleRecord.feedback.FeedbackViewModel
import com.entaku.simpleRecord.play.PlaybackActionListener
import com.entaku.simpleRecord.play.PlaybackNotificationService
import com.entaku.simpleRecord.play.PlaybackScreen
import com.entaku.simpleRecord.play.PlaybackViewModel
import com.entaku.simpleRecord.playlist.PlaylistDetailScreen
import com.entaku.simpleRecord.playlist.PlaylistDetailViewModel
import com.entaku.simpleRecord.playlist.PlaylistDetailViewModelFactory
import com.entaku.simpleRecord.playlist.PlaylistListScreen
import com.entaku.simpleRecord.playlist.PlaylistPlaybackScreen
import com.entaku.simpleRecord.playlist.PlaylistPlaybackViewModel
import com.entaku.simpleRecord.playlist.PlaylistRepositoryImpl
import com.entaku.simpleRecord.playlist.PlaylistViewModel
import com.entaku.simpleRecord.playlist.PlaylistViewModelFactory
import com.entaku.simpleRecord.record.RecordScreen
import com.entaku.simpleRecord.record.RecordViewModel
import com.entaku.simpleRecord.record.RecordViewModelFactory
import com.entaku.simpleRecord.record.RecordingRepositoryImpl
import com.entaku.simpleRecord.record.RecordingsViewModelFactory
import com.entaku.simpleRecord.screenshot.SCREENSHOT_PREVIEW_ROUTE
import com.entaku.simpleRecord.screenshot.addDebugNavigation
import com.entaku.simpleRecord.settings.RecordingSettingsScreen
import com.entaku.simpleRecord.settings.SettingsRepository
import com.entaku.simpleRecord.settings.TutorialScreen
import com.entaku.simpleRecord.store.BillingRepository
import com.entaku.simpleRecord.store.PaywallScreen
import com.entaku.simpleRecord.store.PremiumRepository
import com.entaku.simpleRecord.transcription.MeetingMinutesScreen
import com.entaku.simpleRecord.transcription.TranscriptionScreen
import com.entaku.simpleRecord.transcription.TranscriptionViewModelFactory
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

// Bottom navigation destinations
sealed class TopLevelRoute(
    val route: String,
    val icon: ImageVector,
    val labelRes: Int
) {
    object Record : TopLevelRoute(Screen.Record.route, Icons.Default.Mic, R.string.tab_record)
    object Recordings : TopLevelRoute(Screen.Recordings.route, Icons.Default.PlayArrow, R.string.tab_recordings)
    object Playlists : TopLevelRoute(Screen.Playlists.route, Icons.Default.MusicNote, R.string.tab_playlists)
    object Settings : TopLevelRoute(Screen.RecordingSettings.route, Icons.Default.Settings, R.string.tab_settings)
}

val topLevelRoutes = listOf(
    TopLevelRoute.Record,
    TopLevelRoute.Recordings,
    TopLevelRoute.Playlists,
    TopLevelRoute.Settings
)

class MainActivity : ComponentActivity() {
    private var showingAd = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppOpenAdController.getInstance(this).incrementLaunchCount()
        showSplashAndAd()
    }

    private fun showSplashAndAd() {
        showingAd = true
        setContent { SplashScreen() }
        AppOpenAdController.getInstance(this).showAdIfNeeded(this) {
            showingAd = false
            setContent { AppNavHost() }
        }
    }
}

@Composable
fun SplashScreen() {
    MaterialTheme(colorScheme = LightColorScheme, typography = Typography) {
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background),
            contentAlignment = androidx.compose.ui.Alignment.Center
        ) {
            androidx.compose.foundation.layout.Column(
                horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally
            ) {
                Text(
                    text = "シンプル録音",
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onBackground
                )
            }
        }
    }
}

@Composable
fun AppNavHost() {
    val navController = rememberNavController()
    val context = LocalContext.current
    val sharedViewModel: SharedRecordingsViewModel = viewModel()

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Routes that show the bottom nav bar
    val topLevelRouteStrings = topLevelRoutes.map { it.route }.toSet()
    val showBottomBar = currentRoute in topLevelRouteStrings

    MaterialTheme(colorScheme = LightColorScheme, typography = Typography) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            bottomBar = {
                if (showBottomBar) {
                    NavigationBar {
                        topLevelRoutes.forEach { dest ->
                            NavigationBarItem(
                                selected = currentRoute == dest.route,
                                onClick = {
                                    navController.navigate(dest.route) {
                                        popUpTo(navController.graph.findStartDestination().id) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                },
                                icon = { Icon(dest.icon, contentDescription = null) },
                                label = { Text(stringResource(dest.labelRes)) }
                            )
                        }
                    }
                }
            }
        ) { innerPadding ->
            NavHost(
                navController = navController,
                startDestination = Screen.Record.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                // Tab 0: 録音
                composable(Screen.Record.route) {
                    val database = remember { AppDatabase.getInstance(context) }
                    val repository = remember { RecordingRepositoryImpl(database) }
                    val settingsManager = remember { SettingsRepository(context) }
                    val viewModelFactory = remember { RecordViewModelFactory(repository, settingsManager, sharedViewModel) }
                    val viewModel: RecordViewModel = viewModel(factory = viewModelFactory)

                    RecordScreen(
                        uiStateFlow = viewModel.uiState,
                        onStartRecording = { viewModel.startRecording(context) },
                        onStopRecording = { viewModel.stopRecording() },
                        onPauseRecording = { viewModel.pauseRecording() },
                        onResumeRecording = { viewModel.resumeRecording() },
                        onNavigateBack = {
                            navController.navigate(Screen.Recordings.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }

                // Tab 1: 再生（録音一覧）
                composable(Screen.Recordings.route) {
                    val database = remember { AppDatabase.getInstance(context) }
                    val repository = remember { RecordingRepositoryImpl(database) }
                    val viewModelFactory = remember { RecordingsViewModelFactory(repository) }
                    val viewModel: RecordingsViewModel = viewModel(factory = viewModelFactory)
                    val state by viewModel.uiState.collectAsState()
                    val colorScheme = MaterialTheme.colorScheme

                    RecordingsScreen(
                        state = state,
                        onRefresh = viewModel::loadRecordings,
                        onNavigateToPlaybackScreen = { recordingData ->
                            sharedViewModel.selectRecording(recordingData)
                            navController.navigate(Screen.Playback.route)
                        },
                        onNavigateToCloudSync = { navController.navigate(Screen.CloudSync.route) },
                        onNavigateToTranscription = { recordingData ->
                            val uuid = recordingData.uuid?.toString() ?: return@RecordingsScreen
                            navController.navigate(Screen.Transcription.createRoute(recordingData.filePath, uuid))
                        },
                        onDeleteClick = { uuid -> viewModel.deleteRecording(uuid) },
                        onEditRecordingName = { uuid, title -> viewModel.updateRecordingTitle(uuid, title) },
                        colorScheme = colorScheme
                    )
                }

                // Tab 2: プレイリスト
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
                        onNavigateBack = { /* top-level: no back */ },
                        colorScheme = colorScheme
                    )
                }

                // Tab 3: 設定
                composable(Screen.RecordingSettings.route) {
                    val settingsManager = remember { SettingsRepository(context) }
                    val currentSettings = remember { settingsManager.getRecordingSettings() }

                    RecordingSettingsScreen(
                        currentSettings = currentSettings,
                        onSettingsChanged = { newSettings -> settingsManager.saveRecordingSettings(newSettings) },
                        onNavigateBack = { /* top-level: no back */ },
                        onNavigateToFeedback = { navController.navigate(Screen.Feedback.route) },
                        onNavigateToTutorial = { navController.navigate(Screen.Tutorial.route) },
                        onNavigateToPaywall = { navController.navigate(Screen.Paywall.route) },
                        onNavigateToScreenshotPreview = if (BuildConfig.DEBUG) {
                            { navController.navigate(SCREENSHOT_PREVIEW_ROUTE) }
                        } else null
                    )
                }

                // Detail screens (no bottom nav)
                composable(Screen.Playback.route) {
                    val selectedRecording by sharedViewModel.selectedRecording.collectAsState()
                    val playbackViewModel: PlaybackViewModel = viewModel()
                    val playbackState by playbackViewModel.playbackState.collectAsState()

                    selectedRecording?.let { recordingData ->
                        val notificationTitle = recordingData.title.ifEmpty {
                            context.getString(R.string.untitled_recording)
                        }

                        // ロック画面/通知・Bluetooth・Android Autoからの操作をPlaybackViewModelに転送する (issue #200)
                        DisposableEffect(playbackViewModel) {
                            PlaybackNotificationService.actionListener = object : PlaybackActionListener {
                                override fun onPlayPauseRequested() {
                                    playbackViewModel.playOrPause()
                                    val state = playbackViewModel.playbackState.value
                                    PlaybackNotificationService.updateState(
                                        context, notificationTitle, state.isPlaying,
                                        state.currentPosition.toLong(), playbackViewModel.getDuration().toLong()
                                    )
                                }

                                override fun onSeekToRequested(positionMs: Long) {
                                    playbackViewModel.seekTo(positionMs.toInt())
                                    PlaybackNotificationService.updateState(
                                        context, notificationTitle, playbackViewModel.playbackState.value.isPlaying,
                                        positionMs, playbackViewModel.getDuration().toLong()
                                    )
                                }

                                override fun onStopRequested() {
                                    playbackViewModel.stopPlayback()
                                    PlaybackNotificationService.stop(context)
                                }
                            }
                            onDispose {
                                PlaybackNotificationService.actionListener = null
                                PlaybackNotificationService.stop(context)
                            }
                        }

                        LaunchedEffect(recordingData.filePath) {
                            playbackViewModel.setupMediaPlayer(recordingData.filePath)
                        }
                        PlaybackScreen(
                            recordingData = recordingData,
                            playbackState = playbackState,
                            onStop = {
                                playbackViewModel.stopPlayback()
                                PlaybackNotificationService.stop(context)
                            },
                            onPlayPause = {
                                playbackViewModel.playOrPause()
                                val state = playbackViewModel.playbackState.value
                                PlaybackNotificationService.updateState(
                                    context, notificationTitle, state.isPlaying,
                                    state.currentPosition.toLong(), playbackViewModel.getDuration().toLong()
                                )
                            },
                            onNavigateBack = { navController.popBackStack() },
                            onSpeedChange = { speed -> playbackViewModel.setPlaybackSpeed(speed) },
                            onSeekTo = { pos ->
                                playbackViewModel.seekTo(pos)
                                PlaybackNotificationService.updateState(
                                    context, notificationTitle, playbackState.isPlaying,
                                    pos.toLong(), playbackViewModel.getDuration().toLong()
                                )
                            },
                            onToggleRepeat = { playbackViewModel.toggleRepeatOne() },
                            onSetAbLoopStart = { playbackViewModel.setAbLoopStart() },
                            onSetAbLoopEnd = { playbackViewModel.setAbLoopEnd() },
                            onClearAbLoop = { playbackViewModel.clearAbLoop() },
                            onVolumeBoostChange = { boost -> playbackViewModel.setVolumeBoost(boost) },
                        )
                    }
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

                    LaunchedEffect(Unit) { recordingsViewModel.loadRecordings() }

                    PlaylistDetailScreen(
                        state = state,
                        allRecordings = recordingsState.recordings,
                        onNavigateBack = { navController.popBackStack() },
                        onNavigateToPlayback = { recordingData ->
                            sharedViewModel.selectRecording(recordingData)
                            navController.navigate(Screen.Playback.route)
                        },
                        onNavigateToPlaylistPlayback = { startIndex ->
                            navController.navigate(Screen.PlaylistPlayback.createRoute(playlistIdString, startIndex))
                        },
                        onAddRecording = detailViewModel::addRecording,
                        onRemoveRecording = detailViewModel::removeRecording,
                        onReorderRecordings = detailViewModel::reorderRecordings,
                        colorScheme = colorScheme
                    )
                }

                composable(
                    route = Screen.PlaylistPlayback.route,
                    arguments = listOf(
                        navArgument("playlistId") { type = NavType.StringType },
                        navArgument("startIndex") { type = NavType.IntType; defaultValue = 0 }
                    )
                ) { backStackEntry ->
                    val playlistIdString = backStackEntry.arguments?.getString("playlistId") ?: return@composable
                    val startIndex = backStackEntry.arguments?.getInt("startIndex") ?: 0
                    val playlistId = UUID.fromString(playlistIdString)
                    val database = remember { AppDatabase.getInstance(context) }
                    val playlistRepository = remember { PlaylistRepositoryImpl(database) }
                    val viewModelFactory = remember { PlaylistDetailViewModelFactory(playlistRepository, playlistId) }
                    val detailViewModel: PlaylistDetailViewModel = viewModel(factory = viewModelFactory)
                    val playlistPlaybackViewModel: PlaylistPlaybackViewModel = viewModel()
                    val playbackViewModel: PlaybackViewModel = viewModel()
                    val detailState by detailViewModel.uiState.collectAsState()
                    val playbackState by playlistPlaybackViewModel.state.collectAsState()
                    val audioPlaybackState by playbackViewModel.playbackState.collectAsState()

                    LaunchedEffect(detailState.recordings) {
                        if (detailState.recordings.isNotEmpty()) {
                            playlistPlaybackViewModel.startPlaylistPlayback(
                                recordings = detailState.recordings,
                                startIndex = startIndex
                            )
                        }
                    }
                    LaunchedEffect(playbackState.currentRecording) {
                        playbackState.currentRecording?.let { recording ->
                            playbackViewModel.setupMediaPlayer(recording.filePath)
                            playbackViewModel.setOnCompletionListener { playlistPlaybackViewModel.onTrackComplete() }
                            if (playbackState.isPlaying) playbackViewModel.playOrPause()
                        }
                    }

                    PlaylistPlaybackScreen(
                        playlistName = detailState.playlist?.name ?: "Playlist",
                        playbackState = playbackState,
                        audioPlaybackState = audioPlaybackState,
                        onPlayPauseClick = {
                            playbackViewModel.playOrPause()
                            playlistPlaybackViewModel.setPlaying(audioPlaybackState.isPlaying.not())
                        },
                        onNextClick = { playbackViewModel.stopPlayback(); playlistPlaybackViewModel.playNext() },
                        onPreviousClick = { playbackViewModel.stopPlayback(); playlistPlaybackViewModel.playPrevious() },
                        onRepeatClick = playlistPlaybackViewModel::toggleRepeat,
                        onShuffleClick = playlistPlaybackViewModel::toggleShuffle,
                        onTrackClick = { index -> playbackViewModel.stopPlayback(); playlistPlaybackViewModel.jumpToTrack(index) },
                        onSeekTo = playbackViewModel::seekTo,
                        onBackClick = {
                            playbackViewModel.stopPlayback()
                            playlistPlaybackViewModel.stopPlayback()
                            navController.popBackStack()
                        }
                    )
                }

                composable(Screen.CloudSync.route) {
                    val viewModelFactory = remember { CloudSyncViewModelFactory(context) }
                    val cloudSyncViewModel: CloudSyncViewModel = viewModel(factory = viewModelFactory)
                    CloudSyncScreen(viewModel = cloudSyncViewModel, onNavigateBack = { navController.popBackStack() })
                }

                composable(Screen.Feedback.route) {
                    val feedbackViewModel: FeedbackViewModel = viewModel()
                    FeedbackScreen(viewModel = feedbackViewModel, onNavigateBack = { navController.popBackStack() })
                }

                composable(Screen.Tutorial.route) {
                    TutorialScreen(onNavigateBack = { navController.popBackStack() })
                }

                composable(
                    route = Screen.Transcription.route,
                    arguments = listOf(
                        navArgument("filePath") { type = NavType.StringType },
                        navArgument("uuid") { type = NavType.StringType }
                    )
                ) { backStackEntry ->
                    val encodedPath = backStackEntry.arguments?.getString("filePath") ?: return@composable
                    val filePath = java.net.URLDecoder.decode(encodedPath, "UTF-8")
                    val uuidString = backStackEntry.arguments?.getString("uuid") ?: return@composable
                    val uuid = runCatching { UUID.fromString(uuidString) }.getOrNull()
                    val database = remember { AppDatabase.getInstance(context) }
                    val repository = remember { RecordingRepositoryImpl(database) }
                    val scope = rememberCoroutineScope()

                    TranscriptionScreen(
                        audioFilePath = filePath,
                        recordingUuid = uuid,
                        onNavigateBack = { navController.popBackStack() },
                        onTranscriptionSaved = { id, text ->
                            scope.launch(Dispatchers.IO) {
                                repository.updateTranscription(id, text)
                            }
                        },
                        onNavigateToMeetingMinutes = { id, text ->
                            // 議事録画面はDBの transcription_text を読むため、保存完了を待ってから遷移する
                            scope.launch {
                                withContext(Dispatchers.IO) {
                                    repository.updateTranscription(id, text)
                                }
                                navController.navigate(Screen.MeetingMinutes.createRoute(id.toString()))
                            }
                        }
                    )
                }

                composable(
                    route = Screen.MeetingMinutes.route,
                    arguments = listOf(navArgument("uuid") { type = NavType.StringType })
                ) { backStackEntry ->
                    val uuidString = backStackEntry.arguments?.getString("uuid") ?: return@composable
                    val uuid = runCatching { UUID.fromString(uuidString) }.getOrNull() ?: return@composable
                    val database = remember { AppDatabase.getInstance(context) }
                    val repository = remember { RecordingRepositoryImpl(database) }

                    MeetingMinutesScreen(
                        recordingUuid = uuid,
                        repository = repository,
                        onNavigateBack = { navController.popBackStack() },
                        onNavigateToPaywall = { navController.navigate(Screen.Paywall.route) }
                    )
                }

                composable(Screen.Paywall.route) {
                    PaywallScreen(onNavigateBack = { navController.popBackStack() })
                }

                addDebugNavigation(navController)
            }
        }
    }
}

sealed class Screen(val route: String, val title: String) {
    object Record : Screen("record", "Record")
    object Recordings : Screen("recordings", "Recordings")
    object Playback : Screen("playback", "Playback")
    object RecordingSettings : Screen("recording_settings", "Settings")
    object Playlists : Screen("playlists", "Playlists")
    object PlaylistDetail : Screen("playlist_detail/{playlistId}", "Playlist Detail") {
        fun createRoute(playlistId: String) = "playlist_detail/$playlistId"
    }
    object PlaylistPlayback : Screen("playlist_playback/{playlistId}/{startIndex}", "Playlist Playback") {
        fun createRoute(playlistId: String, startIndex: Int = 0) = "playlist_playback/$playlistId/$startIndex"
    }
    object CloudSync : Screen("cloud_sync", "Cloud Sync")
    object Feedback : Screen("feedback", "Feedback")
    object Tutorial : Screen("tutorial", "Tutorial")
    object Transcription : Screen("transcription/{filePath}/{uuid}", "Transcription") {
        fun createRoute(filePath: String, uuid: String) =
            "transcription/${java.net.URLEncoder.encode(filePath, "UTF-8")}/$uuid"
    }
    object MeetingMinutes : Screen("meeting_minutes/{uuid}", "Meeting Minutes") {
        fun createRoute(uuid: String) = "meeting_minutes/$uuid"
    }
    object Paywall : Screen("paywall", "Premium")
}
