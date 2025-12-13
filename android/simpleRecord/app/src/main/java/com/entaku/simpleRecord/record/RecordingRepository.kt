package com.entaku.simpleRecord.record

import android.util.Log
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.db.RecordingEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.UUID

interface RecordingRepository {
    suspend fun saveRecordingData(recordingData: RecordingData)
    fun getAllRecordings(): Flow<List<RecordingData>>
    suspend fun deleteRecording(uuid: UUID)
    suspend fun updateRecordingTitle(uuid: UUID, newTitle: String)
}
class RecordingRepositoryImpl(private val database: AppDatabase) : RecordingRepository {
    companion object {
        private const val TAG = "RecordingRepositoryImpl"
    }

    override suspend fun saveRecordingData(recordingData: RecordingData) {
        return withContext(Dispatchers.IO) {
            try {
                val uuid = UUID.randomUUID()
                val recordingWithUuid = recordingData.copy(uuid = uuid)
                val recordingEntity = RecordingEntity(
                    uuid = uuid,
                    title = recordingWithUuid.title,
                    creationDate = recordingWithUuid.creationDate.toEpochSecond(ZoneOffset.UTC),
                    fileExtension = recordingWithUuid.fileExtension,
                    khz = recordingWithUuid.khz,
                    bitRate = recordingWithUuid.bitRate,
                    channels = recordingWithUuid.channels,
                    duration = recordingWithUuid.duration,
                    filePath = recordingWithUuid.filePath
                )
                database.recordingDao().insert(recordingEntity)
                Log.d(TAG, "Recording data saved successfully: ${recordingWithUuid.title} with UUID: $uuid")
            } catch (e: Exception) {
                Log.e(TAG, "Error saving recording data: ${e.message}", e)
                throw e
            }
        }
    }
    override fun getAllRecordings(): Flow<List<RecordingData>> {
        return database.recordingDao().getAllRecordings().map { entities ->
            entities
                .map { it.toRecordingData() }
                .sortedByDescending { it.creationDate }
        }
    }

    override suspend fun deleteRecording(uuid: UUID) {
        withContext(Dispatchers.IO) {
            database.recordingDao().delete(uuid)
        }
    }

    override suspend fun updateRecordingTitle(uuid: UUID, newTitle: String) {
        withContext(Dispatchers.IO) {
            database.recordingDao().updateTitle(uuid, newTitle)
        }
    }

    private fun RecordingEntity.toRecordingData(): RecordingData {
        return RecordingData(
            uuid = this.uuid,
            title = this.title,
            creationDate = LocalDateTime.ofEpochSecond(this.creationDate, 0, ZoneOffset.UTC),
            fileExtension = this.fileExtension,
            khz = this.khz,
            bitRate = this.bitRate,
            channels = this.channels,
            duration = this.duration,
            filePath = this.filePath
        )
    }
}