package com.entaku.simpleRecord.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

/**
 * Audio waveform visualization component
 * Displays amplitude history as a waveform graph
 */
@Composable
fun WaveformView(
    amplitudes: List<Float>,
    modifier: Modifier = Modifier,
    waveformColor: Color = MaterialTheme.colorScheme.primary,
    backgroundColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    strokeWidth: Float = 3f,
    showMirror: Boolean = true
) {
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(120.dp)
    ) {
        val width = size.width
        val height = size.height
        val centerY = height / 2

        // Draw background
        drawRect(color = backgroundColor)

        // Draw center line
        drawLine(
            color = waveformColor.copy(alpha = 0.3f),
            start = Offset(0f, centerY),
            end = Offset(width, centerY),
            strokeWidth = 1f
        )

        if (amplitudes.isEmpty()) return@Canvas

        val barWidth = width / MAX_AMPLITUDE_SAMPLES
        val maxAmplitudeHeight = height / 2 * 0.9f

        // Draw waveform bars
        amplitudes.forEachIndexed { index, amplitude ->
            val x = index * barWidth + barWidth / 2
            val barHeight = amplitude * maxAmplitudeHeight

            // Upper bar
            drawLine(
                color = getAmplitudeColor(amplitude, waveformColor),
                start = Offset(x, centerY),
                end = Offset(x, centerY - barHeight),
                strokeWidth = barWidth * 0.6f
            )

            // Mirror bar (lower)
            if (showMirror) {
                drawLine(
                    color = getAmplitudeColor(amplitude, waveformColor).copy(alpha = 0.5f),
                    start = Offset(x, centerY),
                    end = Offset(x, centerY + barHeight),
                    strokeWidth = barWidth * 0.6f
                )
            }
        }
    }
}

/**
 * Waveform view with line style instead of bars
 */
@Composable
fun WaveformLineView(
    amplitudes: List<Float>,
    modifier: Modifier = Modifier,
    waveformColor: Color = MaterialTheme.colorScheme.primary,
    backgroundColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    strokeWidth: Float = 2f
) {
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(100.dp)
    ) {
        val width = size.width
        val height = size.height
        val centerY = height / 2

        // Draw background
        drawRect(color = backgroundColor)

        // Draw center line
        drawLine(
            color = waveformColor.copy(alpha = 0.2f),
            start = Offset(0f, centerY),
            end = Offset(width, centerY),
            strokeWidth = 1f
        )

        if (amplitudes.size < 2) return@Canvas

        val stepX = width / (MAX_AMPLITUDE_SAMPLES - 1)
        val maxAmplitudeHeight = height / 2 * 0.85f

        // Create path for upper waveform
        val upperPath = Path().apply {
            moveTo(0f, centerY - amplitudes.first() * maxAmplitudeHeight)
            amplitudes.forEachIndexed { index, amplitude ->
                val x = index * stepX
                val y = centerY - amplitude * maxAmplitudeHeight
                lineTo(x, y)
            }
        }

        // Create path for lower waveform (mirror)
        val lowerPath = Path().apply {
            moveTo(0f, centerY + amplitudes.first() * maxAmplitudeHeight)
            amplitudes.forEachIndexed { index, amplitude ->
                val x = index * stepX
                val y = centerY + amplitude * maxAmplitudeHeight
                lineTo(x, y)
            }
        }

        // Draw paths
        drawPath(
            path = upperPath,
            color = waveformColor,
            style = Stroke(width = strokeWidth)
        )

        drawPath(
            path = lowerPath,
            color = waveformColor.copy(alpha = 0.5f),
            style = Stroke(width = strokeWidth)
        )
    }
}

/**
 * Simple real-time amplitude indicator (for recording)
 */
@Composable
fun AmplitudeIndicator(
    currentAmplitude: Float,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    backgroundColor: Color = MaterialTheme.colorScheme.surfaceVariant
) {
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(60.dp)
    ) {
        val width = size.width
        val height = size.height
        val centerY = height / 2

        // Draw background
        drawRect(color = backgroundColor)

        // Draw amplitude bars from center
        val barCount = 40
        val barWidth = width / barCount
        val maxBarHeight = height / 2 * 0.9f

        for (i in 0 until barCount) {
            val distance = kotlin.math.abs(i - barCount / 2).toFloat() / (barCount / 2)
            val amplitudeFactor = (1f - distance * 0.5f) * currentAmplitude
            val barHeight = amplitudeFactor * maxBarHeight

            val x = i * barWidth + barWidth / 2
            val barColor = getAmplitudeColor(amplitudeFactor, color)

            // Upper bar
            drawLine(
                color = barColor,
                start = Offset(x, centerY),
                end = Offset(x, centerY - barHeight),
                strokeWidth = barWidth * 0.5f
            )

            // Lower bar
            drawLine(
                color = barColor.copy(alpha = 0.5f),
                start = Offset(x, centerY),
                end = Offset(x, centerY + barHeight),
                strokeWidth = barWidth * 0.5f
            )
        }
    }
}

private fun getAmplitudeColor(amplitude: Float, baseColor: Color): Color {
    return when {
        amplitude > 0.8f -> Color(0xFFE53935) // Red for high amplitude
        amplitude > 0.6f -> Color(0xFFFFA726) // Orange for medium-high
        amplitude > 0.4f -> Color(0xFFFFEB3B) // Yellow for medium
        else -> baseColor
    }
}

const val MAX_AMPLITUDE_SAMPLES = 100

@Preview(showBackground = true)
@Composable
fun PreviewWaveformView() {
    val sampleAmplitudes = List(50) { index ->
        val progress = index.toFloat() / 50
        (kotlin.math.sin(progress * 10) * 0.5f + 0.5f).toFloat() *
            (0.3f + kotlin.random.Random.nextFloat() * 0.4f)
    }
    WaveformView(
        amplitudes = sampleAmplitudes,
        modifier = Modifier.fillMaxWidth()
    )
}

@Preview(showBackground = true)
@Composable
fun PreviewWaveformLineView() {
    val sampleAmplitudes = List(50) { index ->
        val progress = index.toFloat() / 50
        (kotlin.math.sin(progress * 10) * 0.5f + 0.5f).toFloat() *
            (0.3f + kotlin.random.Random.nextFloat() * 0.4f)
    }
    WaveformLineView(
        amplitudes = sampleAmplitudes,
        modifier = Modifier.fillMaxWidth()
    )
}

/**
 * Playback waveform with progress indicator.
 * Uses real amplitude data from audio decoding when available.
 */
@Composable
fun PlaybackWaveformView(
    progress: Float,
    modifier: Modifier = Modifier,
    waveformData: List<Float> = emptyList(),
    playedColor: Color = MaterialTheme.colorScheme.primary,
    unplayedColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    backgroundColor: Color = MaterialTheme.colorScheme.surface
) {
    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        val centerY = height / 2
        val progressX = width * progress.coerceIn(0f, 1f)

        drawRect(color = backgroundColor)

        val barCount = 80
        val barWidth = width / barCount
        val maxBarHeight = height / 2 * 0.85f

        for (i in 0 until barCount) {
            val x = i * barWidth + barWidth / 2
            val amplitude = if (waveformData.isNotEmpty()) {
                val dataIndex = (i.toFloat() / barCount * waveformData.size).toInt()
                    .coerceIn(0, waveformData.size - 1)
                waveformData[dataIndex].coerceIn(0.05f, 1f)
            } else {
                0.15f  // データなし: 細いフラットライン
            }
            val barHeight = amplitude * maxBarHeight
            val color = if (x < progressX) playedColor else unplayedColor

            drawLine(
                color = color,
                start = Offset(x, centerY - barHeight),
                end = Offset(x, centerY + barHeight),
                strokeWidth = (barWidth * 0.5f).coerceAtLeast(2f)
            )
        }

        // 再生位置インジケーター
        drawLine(
            color = playedColor,
            start = Offset(progressX, 0f),
            end = Offset(progressX, height),
            strokeWidth = 2f
        )
    }
}

@Preview(showBackground = true)
@Composable
fun PreviewAmplitudeIndicator() {
    AmplitudeIndicator(
        currentAmplitude = 0.6f,
        modifier = Modifier.fillMaxWidth()
    )
}

@Preview(showBackground = true)
@Composable
fun PreviewPlaybackWaveformView() {
    PlaybackWaveformView(
        progress = 0.4f,
        modifier = Modifier.fillMaxWidth()
    )
}
