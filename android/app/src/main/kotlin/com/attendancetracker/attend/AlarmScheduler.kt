package com.attendancetracker.attend

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

object AlarmScheduler {
    private const val TAG = "AlarmScheduler"
    private const val ALARM_PREFS = "com.attendancetracker.attend.alarms"

    fun scheduleAlarm(
        context: Context,
        id: Int,
        profileId: String,
        profileName: String,
        hour: Int,
        minute: Int,
        isOneShot: Boolean = false
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("profileId", profileId)
            putExtra("profileName", profileName)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("isOneShot", isOneShot)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val triggerMs = nextTriggerMs(hour, minute)

        try {
            when {
                // Android 12+ — check if exact alarms are allowed
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    if (alarmManager.canScheduleExactAlarms()) {
                        // setAlarmClock shows in the system clock widget and is NEVER deferred
                        alarmManager.setAlarmClock(
                            AlarmManager.AlarmClockInfo(triggerMs, pendingIntent),
                            pendingIntent
                        )
                        Log.d(TAG, "setAlarmClock at ${hour}:${minute} for $profileName (id=$id)")
                    } else {
                        // Fallback: still exact-ish, fires within ~1min even in Doze
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerMs, pendingIntent
                        )
                        Log.w(TAG, "No SCHEDULE_EXACT_ALARM perm — used setExactAndAllowWhileIdle for $profileName")
                    }
                }
                // Android 6-11
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerMs, pendingIntent),
                        pendingIntent
                    )
                    Log.d(TAG, "setAlarmClock (M+) at ${hour}:${minute} for $profileName (id=$id)")
                }
                // Android < 6
                else -> {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerMs, pendingIntent)
                    Log.d(TAG, "setExact at ${hour}:${minute} for $profileName (id=$id)")
                }
            }

            // Persist so boot receiver can reschedule (only for repeating alarms)
            if (!isOneShot) {
                context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(id.toString(), "$profileId|$profileName|$hour|$minute")
                    .apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm: ${e.message}", e)
        }
    }

    fun cancelAlarm(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_MUTABLE
        )
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
        context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
            .edit().remove(id.toString()).apply()
        Log.d(TAG, "Cancelled alarm id=$id")
    }

    fun rescheduleAllAlarms(context: Context) {
        val prefs = context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
        Log.d(TAG, "Rescheduling ${prefs.all.size} alarms after boot")
        for ((key, value) in prefs.all) {
            val id    = key.toIntOrNull() ?: continue
            val data  = value as? String ?: continue
            val parts = data.split("|")
            if (parts.size < 4) continue
            val profileId   = parts[0]
            val profileName = parts[1]
            val hour        = parts[2].toIntOrNull() ?: continue
            val minute      = parts[3].toIntOrNull() ?: continue
            scheduleAlarm(context, id, profileId, profileName, hour, minute, false)
        }
    }

    /** Returns epoch millis for the next occurrence of hour:minute (today or tomorrow). */
    private fun nextTriggerMs(hour: Int, minute: Int): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        // Skip Sundays — advance to Monday
        while (cal.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }
}
