package com.entaku.simpleRecord.playlist

import android.util.Log
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.db.AppDatabase
import com.entaku.simpleRecord.db.PlaylistEntity
import com.entaku.simpleRecord.db.PlaylistRecordingCrossRef
import com.entaku.simpleRecord.db.RecordingEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.UUID

interface PlaylistRepository {
    suspend fun createPlaylist(name: String): UUID
    fun getAllPlaylists(): Flow<List<PlaylistData>>
    suspend fun getPlaylistById(uuid: UUID): PlaylistData?
    fun getRecordingsForPlaylist(playlistUuid: UUID): Flow<List<RecordingData>>
    suspend fun updatePlaylistName(uuid: UUID, newName: String)
    suspend fun deletePlaylist(uuid: UUID)
    suspend fun addRecordingToPlaylist(playlistUuid: UUID, recordingUuid: UUID)
    suspend fun removeRecordingFromPlaylist(playlistUuid: UUID, recordingUuid: UUID)
    suspend fun reorderRecordings(playlistUuid: UUID, reorderedRecordings: List<Pair<UUID, Int>>)
}

class PlaylistRepositoryImpl(private val database: AppDatabase) : PlaylistRepository {
    companion object {
        private const val TAG = "PlaylistRepositoryImpl"
    }

    override suspend fun createPlaylist(name: String): UUID {
        return withContext(Dispatchers.IO) {
            try {
                val uuid = UUID.randomUUID()
                val now = System.currentTimeMillis() / 1000
                val entity = PlaylistEntity(
                    uuid = uuid,
                    name = name,
                    creationDate = now,
                    updatedDate = now
                )
                database.playlistDao().insert(entity)
                Log.d(TAG, "Playlist created: $name with UUID: $uuid")
                uuid
            } catch (e: Exception) {
                Log.e(TAG, "Error creating playlist: ${e.message}", e)
                throw e
            }
        }
    }

    override fun getAllPlaylists(): Flow<List<PlaylistData>> {
        return database.playlistDao().getAllPlaylistsWithCount().map { playlistsWithCount ->
            playlistsWithCount.map { it.toPlaylistData() }
        }
    }

    override suspend fun getPlaylistById(uuid: UUID): PlaylistData? {
        return withContext(Dispatchers.IO) {
            database.playlistDao().getPlaylistById(uuid)?.toPlaylistData()
        }
    }

    override fun getRecordingsForPlaylist(playlistUuid: UUID): Flow<List<RecordingData>> {
        return database.playlistDao().getRecordingsForPlaylist(playlistUuid).map { entities ->
            entities.map { it.toRecordingData() }
        }
    }

    override suspend fun updatePlaylistName(uuid: UUID, newName: String) {
        withContext(Dispatchers.IO) {
            val now = System.currentTimeMillis() / 1000
            database.playlistDao().updateName(uuid, newName, now)
            Log.d(TAG, "Playlist name updated: $newName")
        }
    }

    override suspend fun deletePlaylist(uuid: UUID) {
        withContext(Dispatchers.IO) {
            database.playlistDao().delete(uuid)
            Log.d(TAG, "Playlist deleted: $uuid")
        }
    }

    override suspend fun addRecordingToPlaylist(playlistUuid: UUID, recordingUuid: UUID) {
        withContext(Dispatchers.IO) {
            try {
                val position = database.playlistDao().getNextPosition(playlistUuid)
                val crossRef = PlaylistRecordingCrossRef(
                    playlistUuid = playlistUuid,
                    recordingUuid = recordingUuid,
                    position = position
                )
                database.playlistDao().insertCrossRef(crossRef)
                val now = System.currentTimeMillis() / 1000
                val playlist = database.playlistDao().getPlaylistById(playlistUuid)
                if (playlist != null) {
                    database.playlistDao().update(playlist.copy(updatedDate = now))
                }
                Log.d(TAG, "Recording $recordingUuid added to playlist $playlistUuid at position $position")
            } catch (e: Exception) {
                Log.e(TAG, "Error adding recording to playlist: ${e.message}", e)
                throw e
            }
        }
    }

    override suspend fun removeRecordingFromPlaylist(playlistUuid: UUID, recordingUuid: UUID) {
        withContext(Dispatchers.IO) {
            database.playlistDao().removeCrossRef(playlistUuid, recordingUuid)
            val now = System.currentTimeMillis() / 1000
            val playlist = database.playlistDao().getPlaylistById(playlistUuid)
            if (playlist != null) {
                database.playlistDao().update(playlist.copy(updatedDate = now))
            }
            Log.d(TAG, "Recording $recordingUuid removed from playlist $playlistUuid")
        }
    }

    override suspend fun reorderRecordings(
        playlistUuid: UUID,
        reorderedRecordings: List<Pair<UUID, Int>>
    ) {
        withContext(Dispatchers.IO) {
            try {
                database.playlistDao().reorderRecordings(playlistUuid, reorderedRecordings)
                val now = System.currentTimeMillis() / 1000
                val playlist = database.playlistDao().getPlaylistById(playlistUuid)
                if (playlist != null) {
                    database.playlistDao().update(playlist.copy(updatedDate = now))
                }
                Log.d(TAG, "Playlist $playlistUuid reordered with ${reorderedRecordings.size} recordings")
            } catch (e: Exception) {
                Log.e(TAG, "Error reordering recordings: ${e.message}", e)
                throw e
            }
        }
    }

    private fun com.entaku.simpleRecord.db.PlaylistWithCount.toPlaylistData(): PlaylistData {
        return PlaylistData(
            uuid = this.playlist.uuid,
            name = this.playlist.name,
            creationDate = LocalDateTime.ofEpochSecond(this.playlist.creationDate, 0, ZoneOffset.UTC),
            updatedDate = LocalDateTime.ofEpochSecond(this.playlist.updatedDate, 0, ZoneOffset.UTC),
            recordingCount = this.recordingCount
        )
    }

    private fun PlaylistEntity.toPlaylistData(): PlaylistData {
        return PlaylistData(
            uuid = this.uuid,
            name = this.name,
            creationDate = LocalDateTime.ofEpochSecond(this.creationDate, 0, ZoneOffset.UTC),
            updatedDate = LocalDateTime.ofEpochSecond(this.updatedDate, 0, ZoneOffset.UTC),
            recordingCount = 0
        )
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
