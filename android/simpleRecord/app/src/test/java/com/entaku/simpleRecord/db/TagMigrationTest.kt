package com.entaku.simpleRecord.db

import android.content.Context
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Issue #203: adding a tags table + recording<->tag join table must not destroy
 * pre-existing recordings data. This drives [MIGRATION_4_5] directly against a real
 * SQLite database (via the same [SupportSQLiteOpenHelper] machinery Room uses under the
 * hood), independent of the [AppDatabase] Room class, so it exercises exactly the SQL
 * that runs against real user databases on upgrade.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class TagMigrationTest {

    private lateinit var context: Context
    private val dbName = "tag-migration-test.db"

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        context.deleteDatabase(dbName)
    }

    @After
    fun tearDown() {
        context.deleteDatabase(dbName)
    }

    @Test
    fun `migration 4 to 5 preserves existing recordings and adds tag tables`() {
        // 1. Simulate a pre-existing v4 database (as shipped before this issue) with one
        // recording already stored.
        createVersion4DatabaseWithSampleRecording()

        // 2. Open it again declaring version 5, so onUpgrade triggers MIGRATION_4_5.
        val upgradedDb = openDatabase(targetVersion = 5) { db, oldVersion, _ ->
            if (oldVersion < 5) {
                MIGRATION_4_5.migrate(db)
            }
        }

        try {
            // Existing recording data must survive untouched.
            upgradedDb.query("SELECT title FROM recordings").use { cursor ->
                assertTrue(cursor.moveToFirst())
                assertEquals("既存の録音", cursor.getString(0))
                assertEquals(1, cursor.count)
            }

            // New tag tables must exist and start out empty.
            upgradedDb.query("SELECT COUNT(*) FROM tags").use { cursor ->
                assertTrue(cursor.moveToFirst())
                assertEquals(0, cursor.getInt(0))
            }
            upgradedDb.query("SELECT COUNT(*) FROM recording_tag_cross_ref").use { cursor ->
                assertTrue(cursor.moveToFirst())
                assertEquals(0, cursor.getInt(0))
            }

            // The join table must actually be usable (foreign keys point at real columns).
            upgradedDb.execSQL(
                "INSERT INTO tags (uuid, name) VALUES (randomblob(16), '会議')"
            )
            upgradedDb.query("SELECT COUNT(*) FROM tags").use { cursor ->
                cursor.moveToFirst()
                assertEquals(1, cursor.getInt(0))
            }
        } finally {
            upgradedDb.close()
        }
    }

    private fun createVersion4DatabaseWithSampleRecording() {
        val db = openDatabase(targetVersion = 4) { _, _, _ -> }
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `recordings` (
                `uuid` BLOB NOT NULL, `title` TEXT NOT NULL, `creation_date` INTEGER NOT NULL,
                `file_extension` TEXT NOT NULL, `khz` TEXT NOT NULL, `bit_rate` INTEGER NOT NULL,
                `channels` INTEGER NOT NULL, `duration` INTEGER NOT NULL, `file_path` TEXT NOT NULL,
                `transcription_text` TEXT, `meeting_minutes_text` TEXT, PRIMARY KEY(`uuid`)
            )
            """.trimIndent()
        )
        db.execSQL(
            "INSERT INTO recordings (uuid, title, creation_date, file_extension, khz, bit_rate, " +
                "channels, duration, file_path) VALUES (randomblob(16), '既存の録音', 1700000000, " +
                "'m4a', '44.1', 128000, 2, 90, '/path/existing.m4a')"
        )
        db.close()
    }

    private fun openDatabase(
        targetVersion: Int,
        onUpgrade: (SupportSQLiteDatabase, Int, Int) -> Unit
    ): SupportSQLiteDatabase {
        val factory = FrameworkSQLiteOpenHelperFactory()
        val configuration = SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(dbName)
            .callback(object : SupportSQLiteOpenHelper.Callback(targetVersion) {
                override fun onCreate(db: SupportSQLiteDatabase) = Unit
                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {
                    onUpgrade(db, oldVersion, newVersion)
                }
            })
            .build()
        return factory.create(configuration).writableDatabase
    }
}
