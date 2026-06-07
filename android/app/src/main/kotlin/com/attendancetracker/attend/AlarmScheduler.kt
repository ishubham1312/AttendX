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
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // If time is in the past, add 1 day
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        val alarmInfo = AlarmManager.AlarmClockInfo(calendar.timeInMillis, pendingIntent)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setAlarmClock(alarmInfo, pendingIntent)
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setAlarmClock(alarmInfo, pendingIntent)
            }
            Log.d(TAG, "Scheduled alarm for profile $profileName (id: $id) at $hour:$minute (oneShot: $isOneShot)")

            // Save alarm configuration for rescheduling on boot (only if NOT one-shot test)
            if (!isOneShot) {
                val prefs = context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
                prefs.edit().putString(id.toString(), "$profileId|$profileName|$hour|$minute").apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm: ${e.message}", e)
        }
    }

    fun cancelAlarm(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_MUTABLE
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }

        // Remove from persistent store
        val prefs = context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove(id.toString()).apply()
        Log.d(TAG, "Cancelled alarm for id: $id")
    }

    fun rescheduleAllAlarms(context: Context) {
        val prefs = context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
        val all = prefs.all
        Log.d(TAG, "Rescheduling all alarms. Count: ${all.size}")
        for ((key, value) in all) {
            val id = key.toIntOrNull() ?: continue
            val data = value as? String ?: continue
            val parts = data.split("|")
            if (parts.size >= 4) {
                val profileId = parts[0]
                val profileName = parts[1]
                val hour = parts[2].toIntOrNull() ?: continue
                val minute = parts[3].toIntOrNull() ?: continue
                scheduleAlarm(context, id, profileId, profileName, hour, minute, false)
            }
        }
    }
}
