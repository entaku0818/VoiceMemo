package com.entaku.simpleRecord

// DurationExtensions.kt
import java.time.Duration

/**
 * Duration型の拡張関数
 */
fun Duration.formatTime(): String {
    val minutes = this.toMinutes()
    val remainingSeconds = this.seconds % 60
    return String.format("%02d:%02d", minutes, remainingSeconds)
}

fun Long.formatTime(): String {
    val minutes = this / 60
    val seconds = this % 60
    return String.format("%02d:%02d", minutes, seconds)
}