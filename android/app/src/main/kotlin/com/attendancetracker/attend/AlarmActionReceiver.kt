package com.attendancetracker.attend

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
        val profile = intent.getStringExtra("profileId") ?: return
        val date = intent.getStringExtra("date") ?: return
        // An old notification must never mark a different day.
        if (date != AttendanceState.dateKey()) return
        val status = when (intent.action) {
            "ACTION_PRESENT" -> "present"
            "ACTION_ABSENT" -> "absent"
            "ACTION_HALF" -> "halfDay:first"
            else -> return
        }
        AttendanceState.mark(context, profile, date, status, true)
        WidgetHelper.refreshAll(context)
    }
}
