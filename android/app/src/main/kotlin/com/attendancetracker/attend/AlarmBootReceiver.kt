package com.attendancetracker.attend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmBootReceiver : BroadcastReceiver() {
    private fun actionChanged(action: String?) = action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.attendancetracker.attend.REFRESH_WIDGETS" && intent.action != Intent.ACTION_DATE_CHANGED) {
            AlarmScheduler.rescheduleAllAlarms(context, actionChanged(intent.action))
        }
        WidgetHelper.refreshAll(context)
    }
}
