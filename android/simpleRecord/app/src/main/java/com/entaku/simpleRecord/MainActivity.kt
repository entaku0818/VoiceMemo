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
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.play.PlaybackScreen
import com.entaku.simpleRecord.play.PlaybackViewModel
import com.entaku.simpleRecord.record.RecordScreen
import com.entaku.simpleRecord.record.RecordViewModel
import com.entaku.simpleRecord.record.RecordViewModelFactory
import com.entaku.simpleRecord.record.RecordingRepositoryImpl
import com.entaku.simpleRecord.record.RecordingsViewModelFactory
import com.entaku.simpleRecord.settings.RecordingSettingsScreen
import com.entaku.simpleRecord.settings.SettingsManager

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
                    val playbackViewModel: PlaybackViewModel = viewModel()
                    val playbackState by playbackViewModel.playbackState.collectAsState()

                    selectedRecording?.let { recordingData ->
                        LaunchedEffect(recordingData.filePath) {
                            playbackViewModel.setupMediaPlayer(recordingData.filePath)
                        }
                        PlaybackScreen(
                            recordingData = recordingData,
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
            }
        }
    }
}

sealed class Screen(val route: String, val title: String) {
    object Recordings : Screen("recordings", "Recordings")
    object Record : Screen("record", "Record")
    object Playback : Screen("playback", "Playback")
    object RecordingSettings : Screen("recording_settings", "Recording Settings")
}
