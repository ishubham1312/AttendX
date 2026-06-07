package com.attendancetracker.attend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmBootReceiver : BroadcastReceiver() {
    private val TAG = "AlarmBootReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Boot receiver received action: $action")
        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            AlarmScheduler.rescheduleAllAlarms(context)
        }
    }
}
