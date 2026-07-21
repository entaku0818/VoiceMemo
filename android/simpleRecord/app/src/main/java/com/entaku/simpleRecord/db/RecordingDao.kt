package com.entaku.simpleRecord.db

import android.content.Context
import androidx.room.*
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Entity(tableName = "recordings")
data class RecordingEntity(
    @PrimaryKey val uuid: UUID,
    @ColumnInfo(name = "title") val title: String,
    @ColumnInfo(name = "creation_date") val creationDate: Long,
    @ColumnInfo(name = "file_extension") val fileExtension: String,
    @ColumnInfo(name = "khz") val khz: String,
    @ColumnInfo(name = "bit_rate") val bitRate: Int,
    @ColumnInfo(name = "channels") val channels: Int,
    @ColumnInfo(name = "duration") val duration: Long,
    @ColumnInfo(name = "file_path") val filePath: String,
    @ColumnInfo(name = "transcription_text") val transcriptionText: String? = null,
    @ColumnInfo(name = "meeting_minutes_text") val meetingMinutesText: String? = null
)

@Dao
interface RecordingDao {
    @Insert
    suspend fun insert(recording: RecordingEntity)
    @Query("SELECT * FROM recordings")
    fun getAllRecordings(): Flow<List<RecordingEntity>>
    @Query("SELECT * FROM recordings")
    suspend fun getAllRecordingsSync(): List<RecordingEntity>
    @Query("SELECT * FROM recordings WHERE uuid = :uuid")
    suspend fun getRecordingById(uuid: UUID): RecordingEntity?
    @Query("DELETE FROM recordings WHERE uuid = :uuid")
    suspend fun delete(uuid: UUID)
    @Query("UPDATE recordings SET title = :newTitle WHERE uuid = :uuid")
    suspend fun updateTitle(uuid: UUID, newTitle: String)
    @Query("UPDATE recordings SET transcription_text = :text WHERE uuid = :uuid")
    suspend fun updateTranscription(uuid: UUID, text: String)
    @Query("UPDATE recordings SET meeting_minutes_text = :text WHERE uuid = :uuid")
    suspend fun updateMeetingMinutes(uuid: UUID, text: String)
}

val MIGRATION_2_3 = object : androidx.room.migration.Migration(2, 3) {
    override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE recordings ADD COLUMN transcription_text TEXT")
    }
}

val MIGRATION_3_4 = object : androidx.room.migration.Migration(3, 4) {
    override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE recordings ADD COLUMN meeting_minutes_text TEXT")
    }
}

// Issue #203: tag support. Adds a tags table and a recording<->tag join table without
// touching the existing recordings/playlists data.
val MIGRATION_4_5 = object : androidx.room.migration.Migration(4, 5) {
    override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS `tags` (`uuid` BLOB NOT NULL, `name` TEXT NOT NULL, PRIMARY KEY(`uuid`))"
        )
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS `recording_tag_cross_ref` (" +
                "`recording_uuid` BLOB NOT NULL, `tag_uuid` BLOB NOT NULL, " +
                "PRIMARY KEY(`recording_uuid`, `tag_uuid`), " +
                "FOREIGN KEY(`recording_uuid`) REFERENCES `recordings`(`uuid`) ON DELETE CASCADE, " +
                "FOREIGN KEY(`tag_uuid`) REFERENCES `tags`(`uuid`) ON DELETE CASCADE)"
        )
        database.execSQL(
            "CREATE INDEX IF NOT EXISTS `index_recording_tag_cross_ref_recording_uuid` " +
                "ON `recording_tag_cross_ref` (`recording_uuid`)"
        )
        database.execSQL(
            "CREATE INDEX IF NOT EXISTS `index_recording_tag_cross_ref_tag_uuid` " +
                "ON `recording_tag_cross_ref` (`tag_uuid`)"
        )
    }
}

@Database(
    entities = [
        RecordingEntity::class,
        PlaylistEntity::class,
        PlaylistRecordingCrossRef::class,
        TagEntity::class,
        RecordingTagCrossRef::class
    ],
    version = 5
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun recordingDao(): RecordingDao
    abstract fun playlistDao(): PlaylistDao
    abstract fun tagDao(): TagDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "app_database"
                )
                    .addMigrations(MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5)
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
