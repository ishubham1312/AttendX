package com.attendancetracker.attend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        val config = AlarmScheduler.load(context, id) ?: return
        val follow = intent.getBooleanExtra("followUp", false)
        val scheduled = intent.getLongExtra("triggerAt", 0)
        val expected = config.optLong(if (follow) "followUpAt" else "triggerAt")
        if (scheduled != expected || scheduled > System.currentTimeMillis()) return
        if (follow && config.optString("lastMainDate") != AttendanceState.dateKey()) return
        if (!follow && config.optBoolean("completed")) return
        val suppressed = config.optBoolean("isPrimary") &&
            AttendanceState.isMarkedOrDayOff(context, config.optString("profileId"))
        AlarmScheduler.onDelivered(context, config, follow)
        if (!suppressed) AlarmNotificationService.show(context, config, follow)
        WidgetHelper.refreshAll(context)
    }
}
