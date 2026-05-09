package com.entaku.simpleRecord.screenshot

import androidx.navigation.NavController
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable

const val SCREENSHOT_PREVIEW_ROUTE = "screenshot_preview"

fun NavGraphBuilder.addDebugNavigation(navController: NavController) {
    composable(SCREENSHOT_PREVIEW_ROUTE) {
        ScreenshotPreviewScreen(onNavigateBack = { navController.popBackStack() })
    }
}
