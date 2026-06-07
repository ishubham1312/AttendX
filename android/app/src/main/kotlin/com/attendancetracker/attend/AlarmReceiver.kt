package com.attendancetracker.attend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    private val TAG = "AlarmReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val id          = intent.getIntExtra("id", 88888)
        val profileId   = intent.getStringExtra("profileId") ?: ""
        val profileName = intent.getStringExtra("profileName") ?: "Me"
        val hour        = intent.getIntExtra("hour", 9)
        val minute      = intent.getIntExtra("minute", 0)
        val isOneShot   = intent.getBooleanExtra("isOneShot", false)

        Log.d(TAG, "AlarmReceiver fired: profile=$profileName id=$id isOneShot=$isOneShot")

        // Delegate to a foreground service so work survives Doze / low memory
        val serviceIntent = Intent(context, AlarmNotificationService::class.java).apply {
            putExtra("id", id)
            putExtra("profileId", profileId)
            putExtra("profileName", profileName)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("isOneShot", isOneShot)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
