package com.entaku.simpleRecord.transcription

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MeetingMinutesFormatterTest {

    @Test
    fun `format with todos produces summary and todo sections`() {
        val result = MinutesResult(summary = "会議の要約です。", todos = listOf("資料を送付", "日程調整"))
        val text = MeetingMinutesFormatter.format(result)
        assertEquals(
            "# 要約\n会議の要約です。\n\n# TODO\n- 資料を送付\n- 日程調整",
            text
        )
    }

    @Test
    fun `format without todos omits todo section`() {
        val result = MinutesResult(summary = "要約のみ", todos = emptyList())
        assertEquals("# 要約\n要約のみ", MeetingMinutesFormatter.format(result))
    }

    @Test
    fun `parse roundtrips formatted output`() {
        val original = MinutesResult(summary = "議論の内容", todos = listOf("TODO1", "TODO2"))
        val parsed = MeetingMinutesFormatter.parse(MeetingMinutesFormatter.format(original))
        assertEquals(original, parsed)
    }

    @Test
    fun `parse roundtrips summary-only output`() {
        val original = MinutesResult(summary = "要約だけ", todos = emptyList())
        val parsed = MeetingMinutesFormatter.parse(MeetingMinutesFormatter.format(original))
        assertEquals(original, parsed)
    }

    @Test
    fun `parse returns null for non-minutes text`() {
        assertNull(MeetingMinutesFormatter.parse("ただのメモ"))
        assertNull(MeetingMinutesFormatter.parse(""))
    }

    @Test
    fun `parse returns null when summary is empty`() {
        assertNull(MeetingMinutesFormatter.parse("# 要約\n\n\n# TODO\n- x"))
    }
}
