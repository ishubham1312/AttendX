package com.attendancetracker.attend

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActionReceiver : BroadcastReceiver() {
    private val TAG = "AlarmActionReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 88888)
        val profileId = intent.getStringExtra("profileId") ?: ""
        val profileName = intent.getStringExtra("profileName") ?: "Me"
        val hour = intent.getIntExtra("hour", 9)
        val minute = intent.getIntExtra("minute", 0)
        val isOneShot = intent.getBooleanExtra("isOneShot", false)
        val action = intent.getStringExtra("action") ?: ""

        Log.d(TAG, "Action clicked! Action: $action, profileId: $profileId")

        // 1. Cancel notification
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id)

        // 2. Format state values
        val status = when (action) {
            "ACTION_PRESENT" -> "present"
            "ACTION_ABSENT" -> "absent"
            "ACTION_HALF" -> "halfDay"
            else -> ""
        }

        if (status.isNotEmpty()) {
            val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val valStr = if (status == "halfDay") {
                "halfDay|$dateStr|firstHalf"
            } else {
                "$status|$dateStr"
            }

            // Write to Flutter SharedPreferences
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().putString("flutter.pending_attendance_$profileId", valStr).apply()

            // Update HomeWidgetSharedPreferences so the widgets update instantly!
            val widgetPrefs = context.getSharedPreferences("HomeWidgetSharedPreferences", Context.MODE_PRIVATE)
            val timeStr = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())

            val presentCountStr = widgetPrefs.getString("present_count", "0") ?: "0"
            val halfDayCountStr = widgetPrefs.getString("half_day_count", "0") ?: "0"
            val absentCountStr = widgetPrefs.getString("absent_count", "0") ?: "0"

            var presentCount = presentCountStr.toIntOrNull() ?: 0
            var halfDayCount = halfDayCountStr.toIntOrNull() ?: 0
            var absentCount = absentCountStr.toIntOrNull() ?: 0

            val previousStatus = widgetPrefs.getString("today_status", "pending") ?: "pending"

            if (previousStatus != status) {
                // Decrement previous status count if valid
                when (previousStatus) {
                    "present" -> if (presentCount > 0) presentCount--
                    "absent" -> if (absentCount > 0) absentCount--
                    "halfDay" -> if (halfDayCount > 0) halfDayCount--
                }

                // Increment new status count
                when (status) {
                    "present" -> presentCount++
                    "absent" -> absentCount++
                    "halfDay" -> halfDayCount++
                }
            }

            val totalConsidered = presentCount + absentCount + halfDayCount
            val effectiveDays = presentCount + halfDayCount * 0.5
            val percentage = if (totalConsidered == 0) 0.0 else (effectiveDays / totalConsidered) * 100.0
            val scoreText = String.format(Locale.US, "%.1f%%", percentage)

            // Get monthly salary defensively
            val monthlySalary = try {
                widgetPrefs.getFloat("monthly_salary", 0f).toDouble()
            } catch (e: Exception) {
                try {
                    widgetPrefs.getString("monthly_salary", "0")?.toDoubleOrNull() ?: 0.0
                } catch (e2: Exception) {
                    0.0
                }
            }

            val perDaySalary = monthlySalary / 30.0
            val earned = perDaySalary * effectiveDays

            val earnedSalaryStr = "₹" + String.format(Locale.US, "%,d", Math.round(earned))
            val estimatedSalaryStr = "₹" + String.format(Locale.US, "%,d", Math.round(monthlySalary))
            val salaryProgressPercent = if (monthlySalary == 0.0) 0 else Math.min(100, Math.max(0, Math.round((earned / monthlySalary) * 100.0).toInt()))

            widgetPrefs.edit().apply {
                putString("today_status", status)
                putString("today_time", timeStr)
                putString("profile_name", profileName)
                putString("present_count", presentCount.toString())
                putString("half_day_count", halfDayCount.toString())
                putString("absent_count", absentCount.toString())
                putString("attendance_score", scoreText)
                putString("earned_salary", earnedSalaryStr)
                putString("estimated_salary", estimatedSalaryStr)
                putInt("salary_progress", salaryProgressPercent)
                apply()
            }

            // Force widget refresh natively
            try {
                val updateIntent1 = Intent(context, WidgetProvider1x1::class.java).apply {
                    setAction("android.appwidget.action.APPWIDGET_UPDATE")
                }
                context.sendBroadcast(updateIntent1)
                
                val updateIntent2 = Intent(context, WidgetProvider2x1::class.java).apply {
                    setAction("android.appwidget.action.APPWIDGET_UPDATE")
                }
                context.sendBroadcast(updateIntent2)

                val updateIntent3 = Intent(context, WidgetProvider2x2::class.java).apply {
                    setAction("android.appwidget.action.APPWIDGET_UPDATE")
                }
                context.sendBroadcast(updateIntent3)

                val updateIntent4 = Intent(context, WidgetProvider4x2::class.java).apply {
                    setAction("android.appwidget.action.APPWIDGET_UPDATE")
                }
                context.sendBroadcast(updateIntent4)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widgets natively: ${e.message}")
            }
        }

        // Reschedule is handled by AlarmReceiver itself after each trigger.
        // Only needed here for one-shot test alarms (which don't reschedule).
    }
}
