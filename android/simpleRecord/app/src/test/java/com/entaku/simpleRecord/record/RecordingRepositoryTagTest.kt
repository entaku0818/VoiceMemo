package com.entaku.simpleRecord.record

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.db.AppDatabase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDateTime
import java.util.UUID

/**
 * Issue #203: verifies the tag add/remove/filter logic in [RecordingRepositoryImpl]
 * against a real (in-memory) Room database, complementing the pure-Kotlin
 * [RecordingsViewModelTest] which uses a fake repository.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class RecordingRepositoryTagTest {

    private lateinit var database: AppDatabase
    private lateinit var repository: RecordingRepositoryImpl

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        repository = RecordingRepositoryImpl(database)
    }

    @After
    fun tearDown() {
        database.close()
    }

    private suspend fun insertRecording(title: String): UUID {
        repository.saveRecordingData(
            RecordingData(
                title = title,
                creationDate = LocalDateTime.now(),
                fileExtension = "m4a",
                khz = "44.1",
                bitRate = 128000,
                channels = 2,
                duration = 60,
                filePath = "/path/$title.m4a"
            )
        )
        return repository.getAllRecordings().first().first { it.title == title }.uuid!!
    }

    @Test
    fun `addTagToRecording attaches the tag and it is visible via getAllRecordings`() = runTest {
        val uuid = insertRecording("meeting")

        repository.addTagToRecording(uuid, "重要")

        val recording = repository.getAllRecordings().first().first { it.uuid == uuid }
        assertEquals(listOf("重要"), recording.tags)
    }

    @Test
    fun `addTagToRecording reuses an existing tag by name instead of duplicating it`() = runTest {
        val first = insertRecording("meeting")
        val second = insertRecording("interview")

        repository.addTagToRecording(first, "重要")
        repository.addTagToRecording(second, "重要")

        val allTagNames = database.tagDao().getAllTags().first().map { it.name }
        assertEquals(listOf("重要"), allTagNames)
    }

    @Test
    fun `removeTagFromRecording detaches the tag and deletes it once unused`() = runTest {
        val uuid = insertRecording("meeting")
        repository.addTagToRecording(uuid, "重要")

        repository.removeTagFromRecording(uuid, "重要")

        val recording = repository.getAllRecordings().first().first { it.uuid == uuid }
        assertTrue(recording.tags.isEmpty())
        assertTrue(database.tagDao().getAllTags().first().isEmpty())
    }

    @Test
    fun `removeTagFromRecording keeps the tag alive if another recording still uses it`() = runTest {
        val first = insertRecording("meeting")
        val second = insertRecording("interview")
        repository.addTagToRecording(first, "重要")
        repository.addTagToRecording(second, "重要")

        repository.removeTagFromRecording(first, "重要")

        val firstRecording = repository.getAllRecordings().first().first { it.uuid == first }
        val secondRecording = repository.getAllRecordings().first().first { it.uuid == second }
        assertTrue(firstRecording.tags.isEmpty())
        assertEquals(listOf("重要"), secondRecording.tags)
    }

    @Test
    fun `getRecording returns the tags attached to that recording`() = runTest {
        val uuid = insertRecording("meeting")
        repository.addTagToRecording(uuid, "重要")
        repository.addTagToRecording(uuid, "会議")

        val recording = repository.getRecording(uuid)

        assertEquals(listOf("会議", "重要"), recording?.tags?.sorted())
    }

    @Test
    fun `addTagToRecording ignores blank tag names`() = runTest {
        val uuid = insertRecording("meeting")

        repository.addTagToRecording(uuid, "   ")

        val recording = repository.getAllRecordings().first().first { it.uuid == uuid }
        assertTrue(recording.tags.isEmpty())
    }
}
