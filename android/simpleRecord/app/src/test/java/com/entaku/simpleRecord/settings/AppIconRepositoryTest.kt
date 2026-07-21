package com.entaku.simpleRecord.settings

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class AppIconRepositoryTest {

    private lateinit var context: Context
    private lateinit var repository: AppIconRepository

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        repository = AppIconRepository(context)
    }

    @Test
    fun `initial current icon is default`() {
        assertEquals(AppIcon.DEFAULT, repository.getCurrentIcon())
    }

    @Test
    fun `setIcon updates current icon`() {
        repository.setIcon(AppIcon.BLUE)
        assertEquals(AppIcon.BLUE, repository.getCurrentIcon())
    }

    @Test
    fun `setIcon persists across repository instances`() {
        repository.setIcon(AppIcon.PURPLE)
        val anotherInstance = AppIconRepository(context)
        assertEquals(AppIcon.PURPLE, anotherInstance.getCurrentIcon())
    }

    @Test
    fun `setIcon enables only the selected alias component`() {
        repository.setIcon(AppIcon.BLUE)

        val packageManager = context.packageManager
        AppIcon.entries.forEach { icon ->
            val expectedState = if (icon == AppIcon.BLUE) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            val actualState = packageManager.getComponentEnabledSetting(
                ComponentName(context.packageName, icon.aliasName)
            )
            assertEquals("state for ${icon.aliasName}", expectedState, actualState)
        }
    }

    @Test
    fun `switching icon disables the previous alias`() {
        repository.setIcon(AppIcon.BLUE)
        repository.setIcon(AppIcon.PURPLE)

        val packageManager = context.packageManager
        val blueState = packageManager.getComponentEnabledSetting(
            ComponentName(context.packageName, AppIcon.BLUE.aliasName)
        )
        val purpleState = packageManager.getComponentEnabledSetting(
            ComponentName(context.packageName, AppIcon.PURPLE.aliasName)
        )
        assertEquals(PackageManager.COMPONENT_ENABLED_STATE_DISABLED, blueState)
        assertEquals(PackageManager.COMPONENT_ENABLED_STATE_ENABLED, purpleState)
    }
}
