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
    fun `Duration formatTime returns correct format for double digit minutes`() {
        val duration = Duration.ofMinutes(12).plusSeconds(5)
        assertEquals("12:05", duration.formatTime())
    }

    @Test
    fun `Duration formatTime returns correct format for over one hour`() {
        val duration = Duration.ofMinutes(75).plusSeconds(30)
        assertEquals("75:30", duration.formatTime())
    }

    @Test
    fun `Duration formatTime handles 59 seconds correctly`() {
        val duration = Duration.ofSeconds(59)
        assertEquals("00:59", duration.formatTime())
    }

    @Test
    fun `Duration formatTime handles 60 seconds as one minute`() {
        val duration = Duration.ofSeconds(60)
        assertEquals("01:00", duration.formatTime())
    }

    // Long.formatTime() tests

    @Test
    fun `Long formatTime returns 00_00 for zero`() {
        assertEquals("00:00", 0L.formatTime())
    }

    @Test
    fun `Long formatTime returns correct format for seconds only`() {
        assertEquals("00:45", 45L.formatTime())
    }

    @Test
    fun `Long formatTime returns correct format for minutes and seconds`() {
        assertEquals("05:30", 330L.formatTime()) // 5 * 60 + 30 = 330
    }

    @Test
    fun `Long formatTime returns correct format for double digit minutes`() {
        assertEquals("12:05", 725L.formatTime()) // 12 * 60 + 5 = 725
    }

    @Test
    fun `Long formatTime returns correct format for over one hour`() {
        assertEquals("75:30", 4530L.formatTime()) // 75 * 60 + 30 = 4530
    }

    @Test
    fun `Long formatTime handles 59 seconds correctly`() {
        assertEquals("00:59", 59L.formatTime())
    }

    @Test
    fun `Long formatTime handles 60 seconds as one minute`() {
        assertEquals("01:00", 60L.formatTime())
    }

    @Test
    fun `Long formatTime handles large values`() {
        assertEquals("100:00", 6000L.formatTime()) // 100 * 60 = 6000
    }
}
