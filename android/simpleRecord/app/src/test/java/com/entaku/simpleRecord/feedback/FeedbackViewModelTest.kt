package com.entaku.simpleRecord.feedback

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FeedbackViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var fakeRepository: FakeFeedbackRepository
    private lateinit var viewModel: FeedbackViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        fakeRepository = FakeFeedbackRepository()
        viewModel = FeedbackViewModel(fakeRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `default state has FEATURE category and empty fields`() {
        val state = viewModel.state.value
        assertEquals(FeedbackCategory.FEATURE, state.category)
        assertEquals("", state.message)
        assertEquals("", state.email)
        assertFalse(state.isSending)
        assertFalse(state.showSuccess)
        assertNull(state.errorMessage)
    }

    @Test
    fun `setCategory updates category`() {
        viewModel.setCategory(FeedbackCategory.BUG)
        assertEquals(FeedbackCategory.BUG, viewModel.state.value.category)
    }

    @Test
    fun `setMessage updates message`() {
        viewModel.setMessage("test feedback")
        assertEquals("test feedback", viewModel.state.value.message)
    }

    @Test
    fun `setEmail updates email`() {
        viewModel.setEmail("user@example.com")
        assertEquals("user@example.com", viewModel.state.value.email)
    }

    @Test
    fun `clearError sets errorMessage to null`() {
        viewModel.clearError()
        assertNull(viewModel.state.value.errorMessage)
    }

    @Test
    fun `submit does nothing when message is blank`() {
        viewModel.setMessage("  ")
        viewModel.submit("1.0", "14", "Pixel 8")
        assertFalse(viewModel.state.value.isSending)
    }

    @Test
    fun `submit on success sets showSuccess true`() = runTest {
        viewModel.setMessage("Great app!")
        viewModel.submit("1.0", "14", "Pixel 8")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.state.value.showSuccess)
        assertFalse(viewModel.state.value.isSending)
        assertEquals(1, fakeRepository.submittedData.size)
    }

    @Test
    fun `submit on failure sets errorMessage`() = runTest {
        fakeRepository.shouldThrow = true
        viewModel.setMessage("crash test")
        viewModel.submit("1.0", "14", "Pixel 8")
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.state.value.isSending)
        assertTrue(viewModel.state.value.errorMessage != null)
    }

    @Test
    fun `submitted data contains platform android`() = runTest {
        viewModel.setMessage("hello")
        viewModel.submit("2.0", "13", "Pixel 7")
        testDispatcher.scheduler.advanceUntilIdle()

        val data = fakeRepository.submittedData.first()
        assertEquals("android", data["platform"])
    }

    @Test
    fun `all FeedbackCategory entries have positive label resources`() {
        FeedbackCategory.entries.forEach { cat ->
            assertTrue("labelRes for $cat should be positive", cat.labelRes > 0)
        }
    }

    @Test
    fun `FeedbackCategory has three entries`() {
        assertEquals(3, FeedbackCategory.entries.size)
    }
}

class FakeFeedbackRepository : FeedbackRepository {
    val submittedData = mutableListOf<Map<String, Any>>()
    var shouldThrow = false

    override suspend fun submit(data: Map<String, Any>) {
        if (shouldThrow) throw RuntimeException("network error")
        submittedData.add(data)
    }
}
