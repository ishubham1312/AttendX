package com.attendancetracker.attend

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmNotificationService : Service() {
    private val TAG = "AlarmNotificationService"

    companion object {
        const val ALARM_CHANNEL_ID = "attendance_alarm_channel"
        private const val FG_CHANNEL_ID   = "attendance_fg_channel"
        private const val FG_NOTIF_ID     = 999_001   // fixed id — never collides with profile alarms
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id          = intent?.getIntExtra("id", 88888) ?: 88888
        val profileId   = intent?.getStringExtra("profileId") ?: ""
        val profileName = intent?.getStringExtra("profileName") ?: "Me"
        val hour        = intent?.getIntExtra("hour", 9) ?: 9
        val minute      = intent?.getIntExtra("minute", 0) ?: 0
        val isOneShot   = intent?.getBooleanExtra("isOneShot", false) ?: false

        Log.d(TAG, "onStartCommand: profile=$profileName id=$id isOneShot=$isOneShot")

        // Skip Sunday — reschedule to next valid day without showing notification
        val today = java.util.Calendar.getInstance()
        if (today.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.SUNDAY) {
            Log.d(TAG, "Today is Sunday — skipping notification, rescheduling for next day")
            if (!isOneShot) {
                AlarmScheduler.scheduleAlarm(this, id, profileId, profileName, hour, minute, false)
            }
            stopSelf(startId)
            return START_NOT_STICKY
        }

        // Suppress notification if already marked today
        val widgetPrefs = getSharedPreferences("HomeWidgetSharedPreferences", Context.MODE_PRIVATE)
        val todayDateStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(today.time)
        val savedStatusDate = widgetPrefs.getString("today_status_date", "") ?: ""
        val todayStatus = widgetPrefs.getString("today_status", "pending") ?: "pending"
        if (savedStatusDate == todayDateStr && todayStatus != "pending") {
            Log.d(TAG, "Attendance already marked today ($todayStatus) — skipping notification")
            if (!isOneShot) {
                AlarmScheduler.scheduleAlarm(this, id, profileId, profileName, hour, minute, false)
            }
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. Must call startForeground immediately with a SEPARATE id (FG_NOTIF_ID)
        //    so stopSelf() won't cancel the alarm notification.
        ensureFgChannel(nm)
        startForeground(FG_NOTIF_ID, buildFgNotification())

        // 2. Ensure the visible alarm channel exists
        ensureAlarmChannel(nm)

        // 3. Build & post the high-priority alarm notification with its own id
        val alarmNotif = buildAlarmNotification(id, profileId, profileName, hour, minute, isOneShot)
        nm.notify(id, alarmNotif)
        Log.d(TAG, "Alarm notification posted (id=$id)")

        // 4. Reschedule for next day before stopping
        if (!isOneShot) {
            AlarmScheduler.scheduleAlarm(this, id, profileId, profileName, hour, minute, false)
            Log.d(TAG, "Next day alarm rescheduled for $profileName at $hour:$minute")
        }

        // 5. Stop the foreground service after a short delay.
        //    The alarm notification (id != FG_NOTIF_ID) survives because it was
        //    posted via notificationManager.notify(), not startForeground().
        Handler(Looper.getMainLooper()).postDelayed({
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf(startId)
        }, 3_000)

        return START_NOT_STICKY
    }

    // --------------- notification builders ---------------

    private fun buildAlarmNotification(
        id: Int, profileId: String, profileName: String,
        hour: Int, minute: Int, isOneShot: Boolean
    ): Notification {
        val openPending = openAppPending(id)

        return NotificationCompat.Builder(this, ALARM_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (isOneShot) "🔔 Test Reminder" else "⏰ Mark Your Attendance")
            .setContentText("Did $profileName attend today? Tap to mark.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(openPending)
            .addAction(
                android.R.drawable.ic_menu_today, "Present",
                actionPending(id, "ACTION_PRESENT", profileId, profileName, hour, minute, isOneShot)
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel, "Absent",
                actionPending(id, "ACTION_ABSENT", profileId, profileName, hour, minute, isOneShot)
            )
            .addAction(
                android.R.drawable.ic_menu_compass, "Half Day",
                actionPending(id, "ACTION_HALF", profileId, profileName, hour, minute, isOneShot)
            )
            .build()
    }

    private fun buildFgNotification(): Notification =
        NotificationCompat.Builder(this, FG_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Attendance Reminder")
            .setContentText("Preparing your reminder…")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .setOngoing(true)
            .build()

    // --------------- channel helpers ---------------

    private fun ensureAlarmChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // Delete old channel if it exists (was previously created with alarm sound/usage)
        // Channel sound/importance settings are locked after creation, so we must
        // delete and recreate to change them.
        nm.deleteNotificationChannel(ALARM_CHANNEL_ID)
        val ch = NotificationChannel(ALARM_CHANNEL_ID, "Attendance Reminder",
            NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Daily attendance reminder"
            enableLights(true)
            enableVibration(true)
        }
        nm.createNotificationChannel(ch)
    }

    private fun ensureFgChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm.getNotificationChannel(FG_CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(FG_CHANNEL_ID, "Alarm Service",
                NotificationManager.IMPORTANCE_MIN).apply { setShowBadge(false) }
        )
    }

    // --------------- pending intent helpers ---------------

    private fun openAppPending(id: Int): PendingIntent =
        PendingIntent.getActivity(this, id,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)

    private fun actionPending(
        id: Int, action: String,
        profileId: String, profileName: String,
        hour: Int, minute: Int, isOneShot: Boolean
    ): PendingIntent {
        val reqCode = when (action) {
            "ACTION_PRESENT" -> id * 10 + 1
            "ACTION_ABSENT"  -> id * 10 + 2
            else             -> id * 10 + 3
        }
        return PendingIntent.getBroadcast(this, reqCode,
            Intent(this, AlarmActionReceiver::class.java).apply {
                putExtra("action",      action)
                putExtra("profileId",   profileId)
                putExtra("id",          id)
                putExtra("profileName", profileName)
                putExtra("hour",        hour)
                putExtra("minute",      minute)
                putExtra("isOneShot",   isOneShot)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
    }
}
