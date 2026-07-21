package com.entaku.simpleRecord.record

import android.util.Log
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.db.RecordingEntity
import com.entaku.simpleRecord.db.RecordingTagCrossRef
import com.entaku.simpleRecord.db.TagEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
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
    suspend fun updateTranscription(uuid: UUID, text: String)
    suspend fun getRecording(uuid: UUID): RecordingData?
    suspend fun updateMeetingMinutes(uuid: UUID, text: String)
    suspend fun addTagToRecording(recordingUuid: UUID, tagName: String)
    suspend fun removeTagFromRecording(recordingUuid: UUID, tagName: String)
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
        return combine(
            database.recordingDao().getAllRecordings(),
            database.tagDao().getAllRecordingTagNames()
        ) { entities, tagRows ->
            val tagsByRecording = tagRows.groupBy({ it.recordingUuid }, { it.tagName })
            entities
                .map { it.toRecordingData(tagsByRecording[it.uuid] ?: emptyList()) }
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

    override suspend fun updateTranscription(uuid: UUID, text: String) {
        withContext(Dispatchers.IO) {
            database.recordingDao().updateTranscription(uuid, text)
        }
    }

    override suspend fun getRecording(uuid: UUID): RecordingData? {
        return withContext(Dispatchers.IO) {
            val entity = database.recordingDao().getRecordingById(uuid) ?: return@withContext null
            val tags = database.tagDao().getTagsForRecordingSync(uuid).map { it.name }
            entity.toRecordingData(tags)
        }
    }

    override suspend fun updateMeetingMinutes(uuid: UUID, text: String) {
        withContext(Dispatchers.IO) {
            database.recordingDao().updateMeetingMinutes(uuid, text)
        }
    }

    override suspend fun addTagToRecording(recordingUuid: UUID, tagName: String) {
        withContext(Dispatchers.IO) {
            val trimmed = tagName.trim()
            if (trimmed.isEmpty()) return@withContext
            try {
                val existingTag = database.tagDao().getTagByName(trimmed)
                val tag = existingTag ?: TagEntity(uuid = UUID.randomUUID(), name = trimmed).also {
                    database.tagDao().insert(it)
                }
                database.tagDao().insertCrossRef(RecordingTagCrossRef(recordingUuid, tag.uuid))
                Log.d(TAG, "Tag '$trimmed' added to recording $recordingUuid")
            } catch (e: Exception) {
                Log.e(TAG, "Error adding tag to recording: ${e.message}", e)
                throw e
            }
        }
    }

    override suspend fun removeTagFromRecording(recordingUuid: UUID, tagName: String) {
        withContext(Dispatchers.IO) {
            val tag = database.tagDao().getTagByName(tagName.trim()) ?: return@withContext
            database.tagDao().removeCrossRef(recordingUuid, tag.uuid)
            // Clean up tags that are no longer referenced by any recording.
            if (database.tagDao().getUsageCount(tag.uuid) == 0) {
                database.tagDao().deleteTag(tag.uuid)
            }
            Log.d(TAG, "Tag '${tag.name}' removed from recording $recordingUuid")
        }
    }

    private fun RecordingEntity.toRecordingData(tags: List<String> = emptyList()): RecordingData {
        return RecordingData(
            uuid = this.uuid,
            title = this.title,
            creationDate = LocalDateTime.ofEpochSecond(this.creationDate, 0, ZoneOffset.UTC),
            fileExtension = this.fileExtension,
            khz = this.khz,
            bitRate = this.bitRate,
            channels = this.channels,
            duration = this.duration,
            filePath = this.filePath,
            transcriptionText = this.transcriptionText,
            meetingMinutesText = this.meetingMinutesText,
            tags = tags
        )
    }
}