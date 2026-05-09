package com.entaku.simpleRecord.screenshot

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// MARK: - Screenshot page layout (iOS の ScreenshotPageView 相当)

@Composable
fun ScreenshotPage(
    language: ScreenshotLanguage,
    screen: ScreenshotScreen,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1C1C1E)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Spacer(modifier = Modifier.height(48.dp))

        Text(
            text = language.caption(screen),
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            textAlign = TextAlign.Center,
            lineHeight = 44.sp,
            modifier = Modifier.padding(horizontal = 32.dp)
        )

        Spacer(modifier = Modifier.height(24.dp))

        Box(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center
        ) {
            PhoneFrame { content() }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = language.subtitle(),
            fontSize = 18.sp,
            color = Color.White.copy(alpha = 0.7f),
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(48.dp))
    }
}

// iOS の PhoneFrameView 相当
@Composable
fun PhoneFrame(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .aspectRatio(9f / 19.5f)
            .clip(RoundedCornerShape(40.dp))
            .background(Color(0xFF1A1A1A))
            .padding(3.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(38.dp))
                .background(Color.White)
        ) {
            content()
        }
    }
}

// MARK: - Mock Screens

@Composable
fun MockRecordingsScreen(language: ScreenshotLanguage) {
    val recordings = listOf(
        Triple("Morning Meeting", "3:24", "May 8, 2026"),
        Triple("Voice Memo", "1:05", "May 7, 2026"),
        Triple("Interview Notes", "12:48", "May 6, 2026"),
        Triple("Idea Recording", "0:42", "May 5, 2026"),
        Triple("Lecture", "45:12", "May 4, 2026"),
    )

    Scaffold(
        topBar = {
            @OptIn(ExperimentalMaterial3Api::class)
            TopAppBar(
                title = { Text(when (language) {
                    ScreenshotLanguage.JAPANESE -> "録音一覧"
                    ScreenshotLanguage.GERMAN   -> "Aufnahmen"
                    ScreenshotLanguage.FRENCH   -> "Enregistrements"
                    else                        -> "Recordings"
                }) }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {}, containerColor = MaterialTheme.colorScheme.primary) {
                Icon(Icons.Default.Mic, contentDescription = null)
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(recordings.size) { i ->
                val (title, duration, date) = recordings[i]
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Mic, contentDescription = null,
                                tint = MaterialTheme.colorScheme.onPrimaryContainer)
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(title, fontWeight = FontWeight.Medium)
                            Text("$date · $duration",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Icon(Icons.Default.MoreVert, contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
fun MockRecordingScreen(language: ScreenshotLanguage) {
    Scaffold(
        topBar = {
            @OptIn(ExperimentalMaterial3Api::class)
            TopAppBar(
                title = { Text(when (language) {
                    ScreenshotLanguage.JAPANESE -> "録音"
                    ScreenshotLanguage.GERMAN   -> "Aufnahme"
                    ScreenshotLanguage.FRENCH   -> "Enregistrement"
                    else                        -> "Record"
                }) }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier.padding(padding).fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "00:03:24",
                fontSize = 48.sp,
                fontWeight = FontWeight.Light,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Waveform placeholder
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp)
                    .padding(horizontal = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(3.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val heights = listOf(20, 35, 55, 40, 70, 50, 30, 65, 45, 25, 60, 35, 50, 70, 40, 30, 55, 45, 65, 35)
                heights.forEach { h ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(h.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.7f))
                    )
                }
            }

            Spacer(modifier = Modifier.height(48.dp))

            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(CircleShape)
                    .background(Color.Red),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Stop, contentDescription = null,
                    tint = Color.White, modifier = Modifier.size(36.dp))
            }

            Spacer(modifier = Modifier.height(16.dp))
            Text(when (language) {
                ScreenshotLanguage.JAPANESE -> "録音中..."
                ScreenshotLanguage.GERMAN   -> "Aufnahme läuft..."
                ScreenshotLanguage.FRENCH   -> "Enregistrement..."
                else                        -> "Recording..."
            }, color = Color.Red, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
fun MockPlaybackScreen(language: ScreenshotLanguage) {
    Scaffold(
        topBar = {
            @OptIn(ExperimentalMaterial3Api::class)
            TopAppBar(
                title = { Text("Morning Meeting") },
                navigationIcon = {
                    IconButton(onClick = {}) {
                        Icon(Icons.Default.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier.padding(padding).fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Morning Meeting", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(8.dp))
            Text("3:24", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.height(32.dp))

            // Waveform
            Row(
                modifier = Modifier.fillMaxWidth().height(60.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val heights = listOf(15, 30, 50, 35, 65, 45, 25, 60, 40, 20, 55, 30, 45, 65, 35, 50, 40, 60, 30, 45)
                heights.forEachIndexed { idx, h ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(h.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(
                                if (idx < 8) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)
                            )
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("1:05", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("3:24", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            Spacer(modifier = Modifier.height(32.dp))

            Row(
                horizontalArrangement = Arrangement.spacedBy(32.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = {}) {
                    Icon(Icons.Default.SkipPrevious, contentDescription = null, modifier = Modifier.size(36.dp))
                }
                Box(
                    modifier = Modifier.size(64.dp).clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Pause, contentDescription = null,
                        tint = Color.White, modifier = Modifier.size(32.dp))
                }
                IconButton(onClick = {}) {
                    Icon(Icons.Default.SkipNext, contentDescription = null, modifier = Modifier.size(36.dp))
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("0.5x", "1.0x", "1.5x", "2.0x").forEach { speed ->
                    val selected = speed == "1.0x"
                    FilterChip(
                        selected = selected,
                        onClick = {},
                        label = { Text(speed, fontSize = 12.sp) }
                    )
                }
            }
        }
    }
}

@Composable
fun MockPlaylistScreen(language: ScreenshotLanguage) {
    val playlists = listOf(
        Pair("Work Meetings", 8),
        Pair("Lectures", 12),
        Pair("Personal Notes", 5),
        Pair("Ideas", 3),
    )

    Scaffold(
        topBar = {
            @OptIn(ExperimentalMaterial3Api::class)
            TopAppBar(
                title = { Text(when (language) {
                    ScreenshotLanguage.JAPANESE -> "プレイリスト"
                    ScreenshotLanguage.GERMAN   -> "Playlists"
                    ScreenshotLanguage.FRENCH   -> "Playlists"
                    else                        -> "Playlists"
                }) }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {}) {
                Icon(Icons.Default.Add, contentDescription = null)
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(playlists.size) { i ->
                val (name, count) = playlists[i]
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(MaterialTheme.colorScheme.secondaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.QueueMusic, contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSecondaryContainer)
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(name, fontWeight = FontWeight.Medium)
                            Text("$count ${when (language) {
                                ScreenshotLanguage.JAPANESE -> "件"
                                else -> "recordings"
                            }}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Icon(Icons.Default.ChevronRight, contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}
