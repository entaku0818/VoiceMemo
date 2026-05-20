package com.entaku.simpleRecord.store

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class PremiumRepositoryTest {

    private lateinit var context: Context
    private lateinit var repository: PremiumRepository

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        // Use a unique prefs name per test to avoid state leakage
        repository = PremiumRepository(context)
    }

    @Test
    fun `initial isPremium is false`() = runTest {
        assertFalse(repository.isPremium.first())
    }

    @Test
    fun `setPremium true updates isPremium to true`() = runTest {
        repository.setPremium(true)
        assertTrue(repository.isPremium.first())
    }

    @Test
    fun `setPremium false updates isPremium to false`() = runTest {
        repository.setPremium(true)
        repository.setPremium(false)
        assertFalse(repository.isPremium.first())
    }

    @Test
    fun `setPremium true persists across repository instances`() = runTest {
        repository.setPremium(true)
        val anotherInstance = PremiumRepository(context)
        assertTrue(anotherInstance.isPremium.first())
    }

    @Test
    fun `setPremium false persists across repository instances`() = runTest {
        repository.setPremium(true)
        repository.setPremium(false)
        val anotherInstance = PremiumRepository(context)
        assertFalse(anotherInstance.isPremium.first())
    }

    @Test
    fun `isPremium StateFlow emits updated value after setPremium`() = runTest {
        assertFalse(repository.isPremium.value)
        repository.setPremium(true)
        assertTrue(repository.isPremium.value)
        repository.setPremium(false)
        assertFalse(repository.isPremium.value)
    }
}
