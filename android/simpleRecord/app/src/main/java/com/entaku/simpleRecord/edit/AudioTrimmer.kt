package com.entaku.simpleRecord.edit

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer

/**
 * Thrown when the source audio track cannot be re-muxed into the output container.
 *
 * MediaMuxer's MPEG_4 output only officially supports AAC audio (plus a handful of video
 * codecs). Recordings made with the legacy "MEMO" preset (3gp / AMR-NB) cannot be trimmed
 * with this implementation; callers should surface a clear error rather than crash.
 */
class UnsupportedTrimFormatException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Trims an audio file to a [startMs, endMs) range.
 *
 * Issue #201 (Android audio editing): this is the "trim" slice of the broader feature.
 * Split / merge / volume adjustment are intentionally out of scope for this implementation.
 */
interface AudioTrimmer {
    /**
     * Copies the compressed samples between [startMs] and [endMs] from [sourceFilePath] into a
     * new file at [outputFilePath]. No re-encoding is performed, so audio quality is preserved
     * and the operation is fast even for long recordings. Runs on [Dispatchers.IO].
     *
     * @throws UnsupportedTrimFormatException if the source codec isn't supported by the muxer.
     * @throws IllegalArgumentException if [endMs] <= [startMs] or [startMs] is negative.
     * @throws IllegalStateException if no audio track is found in the source file.
     */
    suspend fun trim(sourceFilePath: String, startMs: Long, endMs: Long, outputFilePath: String)
}

class AudioTrimmerImpl : AudioTrimmer {

    override suspend fun trim(sourceFilePath: String, startMs: Long, endMs: Long, outputFilePath: String) =
        withContext(Dispatchers.IO) {
            trimBlocking(sourceFilePath, startMs, endMs, outputFilePath)
        }

    private fun trimBlocking(sourceFilePath: String, startMs: Long, endMs: Long, outputFilePath: String) {
        require(startMs >= 0) { "startMs ($startMs) must not be negative" }
        require(endMs > startMs) { "endMs ($endMs) must be greater than startMs ($startMs)" }

        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(sourceFilePath)
            val trackIndex = (0 until extractor.trackCount).firstOrNull { i ->
                extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw IllegalStateException("No audio track found in $sourceFilePath")

            val format = extractor.getTrackFormat(trackIndex)
            extractor.selectTrack(trackIndex)

            muxer = MediaMuxer(outputFilePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxerTrackIndex = try {
                muxer.addTrack(format)
            } catch (e: IllegalArgumentException) {
                throw UnsupportedTrimFormatException(
                    "Audio format ${format.getString(MediaFormat.KEY_MIME)} is not supported for trimming",
                    e
                )
            }
            muxer.start()

            val startUs = startMs * 1_000L
            val endUs = endMs * 1_000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            val bufferSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                DEFAULT_BUFFER_SIZE
            }
            val buffer = ByteBuffer.allocate(bufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                val sampleTimeUs = extractor.sampleTime
                if (sampleTimeUs < 0 || sampleTimeUs >= endUs) break

                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break

                val isSyncSample = (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0

                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = sampleTimeUs - startUs
                // MediaExtractor.SAMPLE_FLAG_* and MediaCodec.BUFFER_FLAG_* are distinct constant
                // spaces; translate rather than pass extractor.sampleFlags through directly.
                bufferInfo.flags = if (isSyncSample) MediaCodec.BUFFER_FLAG_SYNC_FRAME else 0

                if (bufferInfo.presentationTimeUs >= 0) {
                    muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                }
                extractor.advance()
            }
        } finally {
            runCatching { muxer?.stop() }.onFailure { Log.e(TAG, "Error stopping muxer", it) }
            runCatching { muxer?.release() }.onFailure { Log.e(TAG, "Error releasing muxer", it) }
            extractor.release()
        }
    }

    companion object {
        private const val TAG = "AudioTrimmer"
        private const val DEFAULT_BUFFER_SIZE = 1 shl 20 // 1MB fallback when format lacks KEY_MAX_INPUT_SIZE
    }
}
