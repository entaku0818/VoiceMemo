package com.entaku.simpleRecord.db

import androidx.room.*
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Entity(tableName = "playlists")
data class PlaylistEntity(
    @PrimaryKey val uuid: UUID,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "creation_date") val creationDate: Long,
    @ColumnInfo(name = "updated_date") val updatedDate: Long
)

@Entity(
    tableName = "playlist_recording_cross_ref",
    primaryKeys = ["playlist_uuid", "recording_uuid"],
    foreignKeys = [
        ForeignKey(
            entity = PlaylistEntity::class,
            parentColumns = ["uuid"],
            childColumns = ["playlist_uuid"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = RecordingEntity::class,
            parentColumns = ["uuid"],
            childColumns = ["recording_uuid"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["playlist_uuid"]),
        Index(value = ["recording_uuid"])
    ]
)
data class PlaylistRecordingCrossRef(
    @ColumnInfo(name = "playlist_uuid") val playlistUuid: UUID,
    @ColumnInfo(name = "recording_uuid") val recordingUuid: UUID,
    @ColumnInfo(name = "position") val position: Int
)

data class PlaylistWithRecordings(
    @Embedded val playlist: PlaylistEntity,
    @Relation(
        parentColumn = "uuid",
        entityColumn = "uuid",
        associateBy = Junction(
            value = PlaylistRecordingCrossRef::class,
            parentColumn = "playlist_uuid",
            entityColumn = "recording_uuid"
        )
    )
    val recordings: List<RecordingEntity>
)

data class PlaylistWithCount(
    @Embedded val playlist: PlaylistEntity,
    @ColumnInfo(name = "recording_count") val recordingCount: Int
)

@Dao
interface PlaylistDao {
    @Insert
    suspend fun insert(playlist: PlaylistEntity)

    @Update
    suspend fun update(playlist: PlaylistEntity)

    @Query("SELECT * FROM playlists ORDER BY updated_date DESC")
    fun getAllPlaylists(): Flow<List<PlaylistEntity>>

    @Query("""
        SELECT p.*, COUNT(cr.recording_uuid) as recording_count
        FROM playlists p
        LEFT JOIN playlist_recording_cross_ref cr ON p.uuid = cr.playlist_uuid
        GROUP BY p.uuid
        ORDER BY p.updated_date DESC
    """)
    fun getAllPlaylistsWithCount(): Flow<List<PlaylistWithCount>>

    @Query("SELECT * FROM playlists WHERE uuid = :uuid")
    suspend fun getPlaylistById(uuid: UUID): PlaylistEntity?

    @Transaction
    @Query("SELECT * FROM playlists WHERE uuid = :uuid")
    fun getPlaylistWithRecordings(uuid: UUID): Flow<PlaylistWithRecordings?>

    @Query("DELETE FROM playlists WHERE uuid = :uuid")
    suspend fun delete(uuid: UUID)

    @Query("UPDATE playlists SET name = :newName, updated_date = :updatedDate WHERE uuid = :uuid")
    suspend fun updateName(uuid: UUID, newName: String, updatedDate: Long)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCrossRef(crossRef: PlaylistRecordingCrossRef)

    @Query("DELETE FROM playlist_recording_cross_ref WHERE playlist_uuid = :playlistUuid AND recording_uuid = :recordingUuid")
    suspend fun removeCrossRef(playlistUuid: UUID, recordingUuid: UUID)

    @Query("SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_recording_cross_ref WHERE playlist_uuid = :playlistUuid")
    suspend fun getNextPosition(playlistUuid: UUID): Int

    @Query("""
        SELECT r.* FROM recordings r
        INNER JOIN playlist_recording_cross_ref cr ON r.uuid = cr.recording_uuid
        WHERE cr.playlist_uuid = :playlistUuid
        ORDER BY cr.position ASC
    """)
    fun getRecordingsForPlaylist(playlistUuid: UUID): Flow<List<RecordingEntity>>

    // Reordering support
    @Query("""
        UPDATE playlist_recording_cross_ref
        SET position = :newPosition
        WHERE playlist_uuid = :playlistUuid AND recording_uuid = :recordingUuid
    """)
    suspend fun updatePosition(
        playlistUuid: UUID,
        recordingUuid: UUID,
        newPosition: Int
    )

    @Transaction
    suspend fun reorderRecordings(
        playlistUuid: UUID,
        reorderedRecordings: List<Pair<UUID, Int>>
    ) {
        reorderedRecordings.forEach { (recordingUuid, position) ->
            updatePosition(playlistUuid, recordingUuid, position)
        }
    }
}
