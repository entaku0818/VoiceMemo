package com.entaku.simpleRecord.screenshot

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val SCREENS = listOf(
    ScreenshotScreen.RECORDINGS_LIST,
    ScreenshotScreen.RECORDING,
    ScreenshotScreen.PLAYBACK,
    ScreenshotScreen.PLAYLIST,
)

private val LANGUAGES = ScreenshotLanguage.values().toList()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScreenshotPreviewScreen(onNavigateBack: () -> Unit) {
    var selectedLanguage by remember { mutableStateOf(ScreenshotLanguage.JAPANESE) }
    val pagerState = rememberPagerState(pageCount = { SCREENS.size })

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Screenshot Preview") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {

            LazyRow(
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                items(LANGUAGES) { lang ->
                    FilterChip(
                        selected = lang == selectedLanguage,
                        onClick = { selectedLanguage = lang },
                        label = { Text(lang.code, fontSize = 12.sp) }
                    )
                }
            }

            ScrollableTabRow(
                selectedTabIndex = pagerState.currentPage,
                edgePadding = 0.dp
            ) {
                SCREENS.forEachIndexed { index, screen ->
                    Tab(
                        selected = pagerState.currentPage == index,
                        onClick = { },
                        text = { Text(screen.name.lowercase().replace("_", " "), fontSize = 11.sp) }
                    )
                }
            }

            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { page ->
                Box(
                    modifier = Modifier.fillMaxSize().background(Color(0xFF1C1C1E)),
                    contentAlignment = Alignment.Center
                ) {
                    ScreenshotPagePreview(selectedLanguage, SCREENS[page])
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(SCREENS.size) { i ->
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 3.dp)
                            .size(if (i == pagerState.currentPage) 8.dp else 6.dp)
                            .clip(CircleShape)
                            .background(
                                if (i == pagerState.currentPage) MaterialTheme.colorScheme.primary
                                else Color.Gray.copy(alpha = 0.5f)
                            )
                    )
                }
            }
        }
    }
}

@Composable
private fun ScreenshotPagePreview(language: ScreenshotLanguage, screen: ScreenshotScreen) {
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = language.caption(screen),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp)
        )

        Box(
            modifier = Modifier.weight(1f).padding(vertical = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .aspectRatio(9f / 19.5f)
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color.White)
            ) {
                when (screen) {
                    ScreenshotScreen.RECORDINGS_LIST -> MockRecordingsScreen(language)
                    ScreenshotScreen.RECORDING       -> MockRecordingScreen(language)
                    ScreenshotScreen.PLAYBACK        -> MockPlaybackScreen(language)
                    ScreenshotScreen.PLAYLIST        -> MockPlaylistScreen(language)
                }
            }
        }

        Text(
            text = language.subtitle(),
            fontSize = 14.sp,
            color = Color.White.copy(alpha = 0.7f),
            modifier = Modifier.padding(bottom = 8.dp)
        )
    }
}
