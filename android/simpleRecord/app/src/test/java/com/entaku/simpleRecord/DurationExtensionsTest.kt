package com.entaku.simpleRecord

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Duration

class DurationExtensionsTest {

    // Duration.formatTime() tests

    @Test
    fun `formatTime with zero duration returns 00 00`() {
        val duration = Duration.ZERO
        assertEquals("00:00", duration.formatTime())
    }

    @Test
    fun `formatTime with 30 seconds returns 00 30`() {
        val duration = Duration.ofSeconds(30)
        assertEquals("00:30", duration.formatTime())
    }

    @Test
    fun `formatTime with 1 minute returns 01 00`() {
        val duration = Duration.ofMinutes(1)
        assertEquals("01:00", duration.formatTime())
    }

    @Test
    fun `formatTime with 1 minute 30 seconds returns 01 30`() {
        val duration = Duration.ofSeconds(90)
        assertEquals("01:30", duration.formatTime())
    }

    @Test
    fun `formatTime with 5 minutes 45 seconds returns 05 45`() {
        val duration = Duration.ofSeconds(345)
        assertEquals("05:45", duration.formatTime())
    }

    @Test
    fun `formatTime with 10 minutes returns 10 00`() {
        val duration = Duration.ofMinutes(10)
        assertEquals("10:00", duration.formatTime())
    }

    @Test
    fun `formatTime with 59 minutes 59 seconds returns 59 59`() {
        val duration = Duration.ofSeconds(3599)
        assertEquals("59:59", duration.formatTime())
    }

    @Test
    fun `formatTime with 60 minutes returns 60 00`() {
        val duration = Duration.ofMinutes(60)
        assertEquals("60:00", duration.formatTime())
    }

    // Long.formatTime() tests

    @Test
    fun `Long formatTime with 0 returns 00 00`() {
        assertEquals("00:00", 0L.formatTime())
    }

    @Test
    fun `Long formatTime with 30 seconds returns 00 30`() {
        assertEquals("00:30", 30L.formatTime())
    }

    @Test
    fun `Long formatTime with 60 seconds returns 01 00`() {
        assertEquals("01:00", 60L.formatTime())
    }

    @Test
    fun `Long formatTime with 90 seconds returns 01 30`() {
        assertEquals("01:30", 90L.formatTime())
    }

    @Test
    fun `Long formatTime with 345 seconds returns 05 45`() {
        assertEquals("05:45", 345L.formatTime())
    }

    @Test
    fun `Long formatTime with 600 seconds returns 10 00`() {
        assertEquals("10:00", 600L.formatTime())
    }

    @Test
    fun `Long formatTime with 3599 seconds returns 59 59`() {
        assertEquals("59:59", 3599L.formatTime())
    }

    @Test
    fun `Long formatTime with 3600 seconds returns 60 00`() {
        assertEquals("60:00", 3600L.formatTime())
    }
}
