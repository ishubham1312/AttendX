package com.attendancetracker.attend

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

/** Delivery needs no foreground service: the OS owns the notification and alarm sound. */
object AlarmNotificationService {
    fun show(context: Context, config: JSONObject, followUp: Boolean) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return
        val id = config.getInt("id")
        val ringing = !followUp && config.optString("alertMode") == "alarm"
        val channel = if (ringing) "attendance_ringing_v2" else "attendance_notification_v2"
        val sound = RingtoneManager.getDefaultUri(if (ringing) RingtoneManager.TYPE_ALARM else RingtoneManager.TYPE_NOTIFICATION)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audio = AudioAttributes.Builder().setUsage(if (ringing) AudioAttributes.USAGE_ALARM else AudioAttributes.USAGE_NOTIFICATION).build()
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(channel, if (ringing) "Ringing alarms" else "Attendance notifications", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(sound, audio); enableVibration(true)
            })
        }
        val date = AttendanceState.dateKey()
        fun action(name: String): PendingIntent = PendingIntent.getBroadcast(context, id,
            Intent(context, AlarmActionReceiver::class.java).apply {
                this.action = name; data = Uri.parse("attendx://action/$id/$date/$name")
                putExtra("id", id); putExtra("profileId", config.optString("profileId")); putExtra("date", date)
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(context, id, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val primary = config.optBoolean("isPrimary")
        val builder = NotificationCompat.Builder(context, channel)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (followUp) "Forgot to mark attendance?" else if (primary) "Mark your attendance" else config.optString("profileName"))
            .setContentText(if (followUp) "${config.optString("profileName")}: attendance is still unmarked." else "${config.optString("profileName")}: tap to open AttendX.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(if (ringing) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_REMINDER)
            .setSound(sound, if (ringing) android.media.AudioManager.STREAM_ALARM else android.media.AudioManager.STREAM_NOTIFICATION)
            .setContentIntent(open).setAutoCancel(true).setDeleteIntent(action("DISMISS"))
        if (primary) {
            builder.addAction(0, "Present", action("ACTION_PRESENT"))
                .addAction(0, "Absent", action("ACTION_ABSENT"))
                .addAction(0, "Half Day", action("ACTION_HALF"))
        } else builder.addAction(0, "Dismiss", action("DISMISS"))
        if (ringing) builder.setTimeoutAfter(60_000)
        val notification = builder.build()
        if (ringing) notification.flags = notification.flags or Notification.FLAG_INSISTENT
        nm.notify(id, notification)
    }
}
