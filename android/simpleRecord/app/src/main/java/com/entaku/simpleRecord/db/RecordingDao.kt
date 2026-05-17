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
    @ColumnInfo(name = "transcription_text") val transcriptionText: String? = null
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
}

val MIGRATION_2_3 = object : androidx.room.migration.Migration(2, 3) {
    override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE recordings ADD COLUMN transcription_text TEXT")
    }
}

@Database(
    entities = [RecordingEntity::class, PlaylistEntity::class, PlaylistRecordingCrossRef::class],
    version = 3
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun recordingDao(): RecordingDao
    abstract fun playlistDao(): PlaylistDao

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
                    .addMigrations(MIGRATION_2_3)
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
