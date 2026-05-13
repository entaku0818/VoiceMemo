package com.entaku.simpleRecord.analytics

import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.ktx.Firebase

object FirebaseHelper {

    private var analyticsEnabled = false
    private var crashlyticsEnabled = false

    fun initialize() {
        try {
            Firebase.analytics
            analyticsEnabled = true
        } catch (_: Exception) {
            // google-services.json not yet configured
        }

        try {
            FirebaseCrashlytics.getInstance()
            crashlyticsEnabled = true
        } catch (_: Exception) {
            // google-services.json not yet configured
        }
    }

    fun logEvent(name: String, params: Map<String, String> = emptyMap()) {
        if (!analyticsEnabled) return
        try {
            val bundle = Bundle().apply {
                params.forEach { (k, v) -> putString(k, v) }
            }
            Firebase.analytics.logEvent(name, bundle)
        } catch (_: Exception) {
        }
    }

    fun recordException(throwable: Throwable) {
        if (!crashlyticsEnabled) return
        try {
            FirebaseCrashlytics.getInstance().recordException(throwable)
        } catch (_: Exception) {
        }
    }

    fun setUserId(userId: String) {
        if (!analyticsEnabled) return
        try {
            Firebase.analytics.setUserId(userId)
        } catch (_: Exception) {
        }
    }

    // --- Predefined events ---

    fun logRecordingStarted() = logEvent("recording_started")

    fun logRecordingSaved(durationSeconds: Int) =
        logEvent("recording_saved", mapOf("duration_seconds" to durationSeconds.toString()))

    fun logPlaybackStarted() = logEvent("playback_started")

    fun logSettingsChanged(key: String, value: String) =
        logEvent("settings_changed", mapOf("key" to key, "value" to value))

    fun logScreenView(screenName: String) =
        logEvent(FirebaseAnalytics.Event.SCREEN_VIEW, mapOf(FirebaseAnalytics.Param.SCREEN_NAME to screenName))
}
