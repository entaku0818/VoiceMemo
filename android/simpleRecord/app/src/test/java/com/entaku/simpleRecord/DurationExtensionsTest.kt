package com.entaku.simpleRecord

import org.junit.Assert.*
import org.junit.Test
import java.time.Duration

class DurationExtensionsTest {

    @Test
    fun `formatTime with Duration - zero duration`() {
        val duration = Duration.ZERO
        assertEquals("00:00", duration.formatTime())
    }

    @Test
    fun `formatTime with Duration - 30 seconds`() {
        val duration = Duration.ofSeconds(30)
        assertEquals("00:30", duration.formatTime())
    }

    @Test
    fun `formatTime with Duration - 1 minute`() {
        val duration = Duration.ofMinutes(1)
        assertEquals("01:00", duration.formatTime())
    }

    @Test
    fun `formatTime with Duration - 1 minute 30 seconds`() {
        val duration = Duration.ofSeconds(90)
        assertEquals("01:30", duration.formatTime())
    }

    @Test
    fun `formatTime with Duration - 10 minutes 5 seconds`() {
        val duration = Duration.ofSeconds(605)
        assertEquals("10:05", duration.formatTime())
    }

    @Test
    fun `formatTime with Long - zero`() {
        assertEquals("00:00", 0L.formatTime())
    }

    @Test
    fun `formatTime with Long - 30 seconds`() {
        assertEquals("00:30", 30L.formatTime())
    }

    @Test
    fun `formatTime with Long - 1 minute`() {
        assertEquals("01:00", 60L.formatTime())
    }

    @Test
    fun `formatTime with Long - 1 minute 30 seconds`() {
        assertEquals("01:30", 90L.formatTime())
    }

    @Test
    fun `formatTime with Long - 10 minutes 5 seconds`() {
        assertEquals("10:05", 605L.formatTime())
    }

    @Test
    fun `formatTime with Long - large value 99 minutes 59 seconds`() {
        assertEquals("99:59", 5999L.formatTime())
    }
}
