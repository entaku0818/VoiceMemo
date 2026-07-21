package com.entaku.simpleRecord.db

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Entity(tableName = "tags")
data class TagEntity(
    @PrimaryKey val uuid: UUID,
    @ColumnInfo(name = "name") val name: String
)

@Entity(
    tableName = "recording_tag_cross_ref",
    primaryKeys = ["recording_uuid", "tag_uuid"],
    foreignKeys = [
        ForeignKey(
            entity = RecordingEntity::class,
            parentColumns = ["uuid"],
            childColumns = ["recording_uuid"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = TagEntity::class,
            parentColumns = ["uuid"],
            childColumns = ["tag_uuid"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["recording_uuid"]),
        Index(value = ["tag_uuid"])
    ]
)
data class RecordingTagCrossRef(
    @ColumnInfo(name = "recording_uuid") val recordingUuid: UUID,
    @ColumnInfo(name = "tag_uuid") val tagUuid: UUID
)

/** Flat projection of tag names per recording, used to attach tags to [RecordingData] in bulk. */
data class RecordingTagNameRow(
    @ColumnInfo(name = "recording_uuid") val recordingUuid: UUID,
    @ColumnInfo(name = "name") val tagName: String
)

@Dao
interface TagDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(tag: TagEntity)

    @Query("SELECT * FROM tags WHERE name = :name LIMIT 1")
    suspend fun getTagByName(name: String): TagEntity?

    @Query("SELECT * FROM tags ORDER BY name ASC")
    fun getAllTags(): Flow<List<TagEntity>>

    @Query("DELETE FROM tags WHERE uuid = :uuid")
    suspend fun deleteTag(uuid: UUID)

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertCrossRef(crossRef: RecordingTagCrossRef)

    @Query("DELETE FROM recording_tag_cross_ref WHERE recording_uuid = :recordingUuid AND tag_uuid = :tagUuid")
    suspend fun removeCrossRef(recordingUuid: UUID, tagUuid: UUID)

    @Query("SELECT COUNT(*) FROM recording_tag_cross_ref WHERE tag_uuid = :tagUuid")
    suspend fun getUsageCount(tagUuid: UUID): Int

    @Query(
        """
        SELECT cr.recording_uuid AS recording_uuid, t.name AS name
        FROM recording_tag_cross_ref cr
        INNER JOIN tags t ON t.uuid = cr.tag_uuid
        """
    )
    fun getAllRecordingTagNames(): Flow<List<RecordingTagNameRow>>

    @Query(
        """
        SELECT t.* FROM tags t
        INNER JOIN recording_tag_cross_ref cr ON t.uuid = cr.tag_uuid
        WHERE cr.recording_uuid = :recordingUuid
        ORDER BY t.name ASC
        """
    )
    fun getTagsForRecording(recordingUuid: UUID): Flow<List<TagEntity>>

    @Query(
        """
        SELECT t.* FROM tags t
        INNER JOIN recording_tag_cross_ref cr ON t.uuid = cr.tag_uuid
        WHERE cr.recording_uuid = :recordingUuid
        ORDER BY t.name ASC
        """
    )
    suspend fun getTagsForRecordingSync(recordingUuid: UUID): List<TagEntity>
}
