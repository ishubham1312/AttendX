package com.attendancetracker.attend

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class AlarmSchedulerTest {
    private fun time(day: Int, hour: Int, minute: Int = 0): Long = Calendar.getInstance().apply {
        clear(); set(2026, Calendar.SEPTEMBER, day, hour, minute)
    }.timeInMillis

    @Test fun schedulesTodayWhenTimeIsAhead() {
        assertEquals(time(7, 9), AlarmScheduler.nextTriggerMs(9, 0, listOf(1), time(7, 8)))
    }
    @Test fun respectsRepeatDaysRatherThanSchedulingDaily() {
        assertEquals(time(14, 9), AlarmScheduler.nextTriggerMs(9, 0, listOf(1), time(7, 10)))
    }
    @Test fun sundayIsAvailableForCustomAlarms() {
        assertEquals(time(13, 9), AlarmScheduler.nextTriggerMs(9, 0, listOf(7), time(12, 10)))
    }
    @Test fun exactTimeNeverSchedulesInThePast() {
        assertEquals(time(8, 9), AlarmScheduler.nextTriggerMs(9, 0, (1..7).toList(), time(7, 9)))
    }
    @Test(expected = IllegalArgumentException::class) fun emptyRepeatDaysAreRejected() {
        AlarmScheduler.nextTriggerMs(9, 0, emptyList(), time(7, 8))
    }
    @Test(expected = IllegalArgumentException::class) fun invalidRepeatDayCannotLoopForever() {
        AlarmScheduler.nextTriggerMs(9, 0, listOf(8), time(7, 8))
    }
    @Test fun followUpIsStrictlyAfterMainDelivery() {
        assertEquals(time(7, 9, 30), AlarmScheduler.nextFollowUpMs(time(7, 9), 30))
    }
    @Test fun followUpCanBeDisabled() {
        assertNull(AlarmScheduler.nextFollowUpMs(time(7, 9), 0))
    }
    @Test fun followUpNeverSpillsIntoTomorrow() {
        assertNull(AlarmScheduler.nextFollowUpMs(time(7, 23, 50), 30))
    }
    @Test fun localWallClockSurvivesDaylightSavingTransition() {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
            val before = Calendar.getInstance().apply { clear(); set(2026, Calendar.MARCH, 7, 10, 0) }
            val expected = Calendar.getInstance().apply { clear(); set(2026, Calendar.MARCH, 8, 9, 0) }
            assertEquals(expected.timeInMillis, AlarmScheduler.nextTriggerMs(9, 0, (1..7).toList(), before.timeInMillis))
        } finally { TimeZone.setDefault(original) }
    }
}
