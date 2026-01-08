package com.entaku.simpleRecord

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Duration

class DurationExtensionsTest {

    // Duration.formatTime() tests
    @Test
    fun `Duration formatTime returns 00_00 for zero duration`() {
        val duration = Duration.ZERO
        assertEquals("00:00", duration.formatTime())
    }

    @Test
    fun `Duration formatTime returns correct format for seconds only`() {
        val duration = Duration.ofSeconds(45)
        assertEquals("00:45", duration.formatTime())
    }

    @Test
    fun `Duration formatTime returns correct format for minutes and seconds`() {
        val duration = Duration.ofMinutes(5).plusSeconds(30)
        assertEquals("05:30", duration.formatTime())
    }

    @Test
    fun `Duration formatTime returns correct format for exact minutes`() {
        val duration = Duration.ofMinutes(10)
        assertEquals("10:00", duration.formatTime())
    }

    @Test
    fun `Duration formatTime handles hours correctly as minutes`() {
        val duration = Duration.ofHours(1).plusMinutes(30).plusSeconds(45)
        assertEquals("90:45", duration.formatTime())
    }

    @Test
    fun `Duration formatTime pads single digit seconds`() {
        val duration = Duration.ofMinutes(1).plusSeconds(5)
        assertEquals("01:05", duration.formatTime())
    }

    @Test
    fun `Duration formatTime pads single digit minutes`() {
        val duration = Duration.ofMinutes(3).plusSeconds(22)
        assertEquals("03:22", duration.formatTime())
    }

    @Test
    fun `Duration formatTime handles large durations`() {
        val duration = Duration.ofMinutes(120).plusSeconds(59)
        assertEquals("120:59", duration.formatTime())
    }

    // Long.formatTime() tests
    @Test
    fun `Long formatTime returns 00_00 for zero`() {
        val seconds = 0L
        assertEquals("00:00", seconds.formatTime())
    }

    @Test
    fun `Long formatTime returns correct format for seconds only`() {
        val seconds = 45L
        assertEquals("00:45", seconds.formatTime())
    }

    @Test
    fun `Long formatTime returns correct format for minutes and seconds`() {
        val seconds = 330L // 5 minutes 30 seconds
        assertEquals("05:30", seconds.formatTime())
    }

    @Test
    fun `Long formatTime returns correct format for exact minutes`() {
        val seconds = 600L // 10 minutes
        assertEquals("10:00", seconds.formatTime())
    }

    @Test
    fun `Long formatTime handles hours correctly as minutes`() {
        val seconds = 5445L // 90 minutes 45 seconds
        assertEquals("90:45", seconds.formatTime())
    }

    @Test
    fun `Long formatTime pads single digit seconds`() {
        val seconds = 65L // 1 minute 5 seconds
        assertEquals("01:05", seconds.formatTime())
    }

    @Test
    fun `Long formatTime pads single digit minutes`() {
        val seconds = 202L // 3 minutes 22 seconds
        assertEquals("03:22", seconds.formatTime())
    }

    @Test
    fun `Long formatTime handles large durations`() {
        val seconds = 7259L // 120 minutes 59 seconds
        assertEquals("120:59", seconds.formatTime())
    }
}
