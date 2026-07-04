package com.entaku.simpleRecord.transcription

import com.entaku.simpleRecord.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

data class TranscriptionSegment(
    val time: String,
    val speaker: String?,
    val text: String
)

data class TranscriptionResult(
    val transcription: String,
    val segments: List<TranscriptionSegment>,
    val summary: String
)

data class MinutesResult(
    val summary: String,
    val todos: List<String>
)

class TranscriptionApiClient {

    private val baseUrl = BuildConfig.TRANSCRIPTION_SERVER_URL

    suspend fun getUploadUrl(idToken: String, extension: String): Pair<String, String> =
        withContext(Dispatchers.IO) {
            val url = URL("$baseUrl/upload-url")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
            }
            val body = """{"extension":"$extension"}""".toByteArray()
            conn.outputStream.use { it.write(body) }

            val status = conn.responseCode
            val responseBody = conn.inputStream.bufferedReader().readText()
            if (status !in 200..299) error("upload-url failed: $status $responseBody")

            val json = JSONObject(responseBody)
            Pair(json.getString("uploadUrl"), json.getString("blobName"))
        }

    suspend fun uploadAudio(signedUrl: String, file: File, mimeType: String) =
        withContext(Dispatchers.IO) {
            val url = URL(signedUrl)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "PUT"
                setRequestProperty("Content-Type", mimeType)
                doOutput = true
            }
            conn.outputStream.use { out -> file.inputStream().use { it.copyTo(out) } }
            val status = conn.responseCode
            if (status !in 200..299) error("upload audio failed: $status")
        }

    suspend fun transcribe(idToken: String, blobName: String, language: String): TranscriptionResult =
        withContext(Dispatchers.IO) {
            val url = URL("$baseUrl/transcribe")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 30_000
                readTimeout = 600_000
                doOutput = true
            }
            val body = """{"blobName":"$blobName","language":"$language"}""".toByteArray()
            conn.outputStream.use { it.write(body) }

            val status = conn.responseCode
            val responseBody = if (status in 200..299) {
                conn.inputStream.bufferedReader().readText()
            } else {
                conn.errorStream?.bufferedReader()?.readText() ?: ""
            }
            if (status !in 200..299) error("transcribe failed: $status $responseBody")

            val json = JSONObject(responseBody)
            val segments = mutableListOf<TranscriptionSegment>()
            json.optJSONArray("segments")?.let { arr ->
                for (i in 0 until arr.length()) {
                    val seg = arr.getJSONObject(i)
                    segments.add(
                        TranscriptionSegment(
                            time = seg.optString("time", ""),
                            speaker = seg.optString("speaker").takeIf { it.isNotEmpty() },
                            text = seg.optString("text", "")
                        )
                    )
                }
            }
            TranscriptionResult(
                transcription = json.optString("transcription", ""),
                segments = segments,
                summary = json.optString("summary", "")
            )
        }

    suspend fun generateMinutes(idToken: String, text: String, language: String): MinutesResult =
        withContext(Dispatchers.IO) {
            val url = URL("$baseUrl/minutes")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 30_000
                readTimeout = 180_000
                doOutput = true
            }
            // text には改行や引用符が含まれるため JSONObject でエスケープして組み立てる
            val body = JSONObject()
                .put("text", text)
                .put("language", language)
                .toString()
                .toByteArray()
            conn.outputStream.use { it.write(body) }

            val status = conn.responseCode
            val responseBody = if (status in 200..299) {
                conn.inputStream.bufferedReader().readText()
            } else {
                conn.errorStream?.bufferedReader()?.readText() ?: ""
            }
            if (status !in 200..299) error("minutes failed: $status $responseBody")

            val json = JSONObject(responseBody)
            val todos = mutableListOf<String>()
            json.optJSONArray("todos")?.let { arr ->
                for (i in 0 until arr.length()) {
                    todos.add(arr.getString(i))
                }
            }
            MinutesResult(
                summary = json.optString("summary", ""),
                todos = todos
            )
        }
}
