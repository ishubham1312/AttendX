package com.attendancetracker.attend

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    private val TAG = "AlarmReceiver"
    private val CHANNEL_ID = "attendance_alarm_channel"

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 88888)
        val profileId = intent.getStringExtra("profileId") ?: ""
        val profileName = intent.getStringExtra("profileName") ?: "Me"
        val hour = intent.getIntExtra("hour", 9)
        val minute = intent.getIntExtra("minute", 0)
        val isOneShot = intent.getBooleanExtra("isOneShot", false)

        Log.d(TAG, "Alarm triggered! profileId: $profileId, id: $id, oneShot: $isOneShot")

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create the notification channel on Android Oreo and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Attendance Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Loud alarm reminders to mark attendance"
                enableLights(true)
                enableVibration(true)
                val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                setSound(
                    alarmSound,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Action intents pointing to AlarmActionReceiver
        val presentIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            putExtra("action", "ACTION_PRESENT")
            putExtra("profileId", profileId)
            putExtra("id", id)
            putExtra("profileName", profileName)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("isOneShot", isOneShot)
        }
        val presentPending = PendingIntent.getBroadcast(
            context,
            id * 10 + 1,
            presentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val absentIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            putExtra("action", "ACTION_ABSENT")
            putExtra("profileId", profileId)
            putExtra("id", id)
            putExtra("profileName", profileName)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("isOneShot", isOneShot)
        }
        val absentPending = PendingIntent.getBroadcast(
            context,
            id * 10 + 2,
            absentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val halfIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            putExtra("action", "ACTION_HALF")
            putExtra("profileId", profileId)
            putExtra("id", id)
            putExtra("profileName", profileName)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("isOneShot", isOneShot)
        }
        val halfPending = PendingIntent.getBroadcast(
            context,
            id * 10 + 3,
            halfIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Intent to open the app when clicking the notification body
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val openPending = PendingIntent.getActivity(
            context,
            id,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val title = if (isOneShot) "🔔 Attendance Alarm (Test)" else "⏰ Attendance Alarm"
        val body = "Did $profileName attend today? Mark attendance below."

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setSound(alarmSound)
            .setAutoCancel(true)
            .setFullScreenIntent(openPending, true)
            .setContentIntent(openPending)
            .addAction(android.R.drawable.ic_menu_today, "Present", presentPending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Absent", absentPending)
            .addAction(android.R.drawable.ic_menu_compass, "Half Day", halfPending)

        notificationManager.notify(id, builder.build())

        // Re-schedule for next day if this is a repeating alarm
        if (!isOneShot) {
            AlarmScheduler.scheduleAlarm(context, id, profileId, profileName, hour, minute, false)
        }
    }
}
