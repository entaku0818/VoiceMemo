package com.entaku.simpleRecord.cloudsync

import android.content.Context
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.db.RecordingEntity
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.api.client.googleapis.extensions.android.gms.auth.GoogleAccountCredential
import com.google.api.client.http.FileContent
import com.google.api.client.http.javanet.NetHttpTransport
import com.google.api.client.json.gson.GsonFactory
import com.google.api.services.drive.Drive
import com.google.api.services.drive.DriveScopes
import com.google.api.services.drive.model.File as DriveFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.time.LocalDateTime
import java.util.UUID

class DriveBackupService(
    private val context: Context,
    private val account: GoogleSignInAccount
) {
    private val driveService: Drive by lazy {
        val credential = GoogleAccountCredential.usingOAuth2(
            context, listOf(DriveScopes.DRIVE_APPDATA)
        ).apply {
            selectedAccount = account.account
        }

        Drive.Builder(
            NetHttpTransport(),
            GsonFactory.getDefaultInstance(),
            credential
        )
            .setApplicationName("SimpleRecord")
            .build()
    }

    private val database: AppDatabase by lazy {
        AppDatabase.getInstance(context)
    }

    companion object {
        private const val BACKUP_FOLDER_NAME = "SimpleRecord_Backup"
        private const val METADATA_FILE_NAME = "recordings_metadata.json"
    }

    suspend fun backup(onProgress: (String) -> Unit): Result<Int> = withContext(Dispatchers.IO) {
        try {
            onProgress("Preparing backup...")

            val recordings = database.recordingDao().getAllRecordingsSync()
            if (recordings.isEmpty()) {
                return@withContext Result.success(0)
            }

            onProgress("Finding backup folder...")
            val folderId = getOrCreateBackupFolder()

            var uploadedCount = 0
            for (recording in recordings) {
                onProgress("Uploading ${recording.title}...")

                val audioFile = File(recording.filePath)
                if (audioFile.exists()) {
                    uploadAudioFile(folderId, recording, audioFile)
                    uploadedCount++
                }
            }

            onProgress("Saving metadata...")
            uploadMetadata(folderId, recordings)

            onProgress("Backup complete!")
            Result.success(uploadedCount)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun restore(onProgress: (String) -> Unit): Result<Int> = withContext(Dispatchers.IO) {
        try {
            onProgress("Finding backup folder...")

            val folderId = findBackupFolder()
                ?: return@withContext Result.failure(Exception("No backup found"))

            onProgress("Reading metadata...")
            val metadata = downloadMetadata(folderId)
                ?: return@withContext Result.failure(Exception("No metadata found"))

            val recordingsDir = context.getExternalFilesDir(null)
                ?: context.filesDir

            var restoredCount = 0
            val jsonArray = JSONArray(metadata)

            for (i in 0 until jsonArray.length()) {
                val json = jsonArray.getJSONObject(i)
                val uuid = UUID.fromString(json.getString("uuid"))
                val title = json.getString("title")
                val fileName = json.getString("fileName")

                onProgress("Restoring $title...")

                val existingRecording = database.recordingDao().getRecordingById(uuid)
                if (existingRecording != null) {
                    continue
                }

                val audioFileId = findAudioFile(folderId, fileName)
                if (audioFileId != null) {
                    val localFile = File(recordingsDir, fileName)
                    downloadFile(audioFileId, localFile)

                    val recording = RecordingEntity(
                        uuid = uuid,
                        title = title,
                        filePath = localFile.absolutePath,
                        creationDate = json.getLong("creationDate"),
                        duration = json.getLong("duration"),
                        fileExtension = json.optString("fileExtension", "3gp"),
                        khz = json.optString("khz", "44"),
                        bitRate = json.optInt("bitRate", 16),
                        channels = json.optInt("channels", 1)
                    )
                    database.recordingDao().insert(recording)
                    restoredCount++
                }
            }

            onProgress("Restore complete!")
            Result.success(restoredCount)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun getOrCreateBackupFolder(): String {
        val existingFolder = findBackupFolder()
        if (existingFolder != null) {
            return existingFolder
        }

        val folderMetadata = DriveFile().apply {
            name = BACKUP_FOLDER_NAME
            mimeType = "application/vnd.google-apps.folder"
            parents = listOf("appDataFolder")
        }

        val folder = driveService.files().create(folderMetadata)
            .setFields("id")
            .execute()

        return folder.id
    }

    private fun findBackupFolder(): String? {
        val result = driveService.files().list()
            .setSpaces("appDataFolder")
            .setQ("name = '$BACKUP_FOLDER_NAME' and mimeType = 'application/vnd.google-apps.folder' and trashed = false")
            .setFields("files(id)")
            .execute()

        return result.files.firstOrNull()?.id
    }

    private fun uploadAudioFile(folderId: String, recording: RecordingEntity, audioFile: File) {
        val fileName = audioFile.name

        val existingFileId = findAudioFile(folderId, fileName)
        if (existingFileId != null) {
            val mediaContent = FileContent("audio/*", audioFile)
            driveService.files().update(existingFileId, null, mediaContent).execute()
        } else {
            val fileMetadata = DriveFile().apply {
                name = fileName
                parents = listOf(folderId)
            }
            val mediaContent = FileContent("audio/*", audioFile)
            driveService.files().create(fileMetadata, mediaContent)
                .setFields("id")
                .execute()
        }
    }

    private fun findAudioFile(folderId: String, fileName: String): String? {
        val result = driveService.files().list()
            .setSpaces("appDataFolder")
            .setQ("'$folderId' in parents and name = '$fileName' and trashed = false")
            .setFields("files(id)")
            .execute()

        return result.files.firstOrNull()?.id
    }

    private fun uploadMetadata(folderId: String, recordings: List<RecordingEntity>) {
        val jsonArray = JSONArray()

        for (recording in recordings) {
            val json = JSONObject().apply {
                put("uuid", recording.uuid.toString())
                put("title", recording.title)
                put("fileName", File(recording.filePath).name)
                put("creationDate", recording.creationDate)
                put("duration", recording.duration)
                put("fileExtension", recording.fileExtension)
                put("khz", recording.khz)
                put("bitRate", recording.bitRate)
                put("channels", recording.channels)
            }
            jsonArray.put(json)
        }

        val metadataContent = jsonArray.toString()
        val tempFile = File(context.cacheDir, METADATA_FILE_NAME)
        tempFile.writeText(metadataContent)

        val existingFileId = findMetadataFile(folderId)
        if (existingFileId != null) {
            val mediaContent = FileContent("application/json", tempFile)
            driveService.files().update(existingFileId, null, mediaContent).execute()
        } else {
            val fileMetadata = DriveFile().apply {
                name = METADATA_FILE_NAME
                parents = listOf(folderId)
            }
            val mediaContent = FileContent("application/json", tempFile)
            driveService.files().create(fileMetadata, mediaContent)
                .setFields("id")
                .execute()
        }

        tempFile.delete()
    }

    private fun findMetadataFile(folderId: String): String? {
        val result = driveService.files().list()
            .setSpaces("appDataFolder")
            .setQ("'$folderId' in parents and name = '$METADATA_FILE_NAME' and trashed = false")
            .setFields("files(id)")
            .execute()

        return result.files.firstOrNull()?.id
    }

    private fun downloadMetadata(folderId: String): String? {
        val fileId = findMetadataFile(folderId) ?: return null

        val outputStream = ByteArrayOutputStream()
        driveService.files().get(fileId).executeMediaAndDownloadTo(outputStream)
        return outputStream.toString()
    }

    private fun downloadFile(fileId: String, destination: File) {
        destination.parentFile?.mkdirs()
        destination.outputStream().use { outputStream ->
            driveService.files().get(fileId).executeMediaAndDownloadTo(outputStream)
        }
    }

    suspend fun getBackupInfo(): BackupInfo? = withContext(Dispatchers.IO) {
        try {
            val folderId = findBackupFolder() ?: return@withContext null
            val metadata = downloadMetadata(folderId) ?: return@withContext null

            val jsonArray = JSONArray(metadata)
            BackupInfo(
                recordingCount = jsonArray.length(),
                lastBackupDate = null
            )
        } catch (e: Exception) {
            null
        }
    }
}

data class BackupInfo(
    val recordingCount: Int,
    val lastBackupDate: LocalDateTime?
)
