package com.attendancetracker.attend

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

object WidgetHelper {
    fun updateViews1x1(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val todayStatus = widgetData.getString("today_status", "pending") ?: "pending"
        val todayTime = widgetData.getString("today_time", "Mark Today") ?: "Mark Today"

        // Set status icon
        val iconRes = getStatusIcon(todayStatus)
        views.setImageViewResource(R.id.widget_status_icon, iconRes)

        // Set status label and color
        val label = getStatusLabel(todayStatus)
        val color = getStatusColor(todayStatus)
        views.setTextViewText(R.id.widget_status_label, label)
        views.setTextColor(R.id.widget_status_label, color)

        // Set subtitle
        val isDayOff = todayStatus == "sunday" || todayStatus == "holiday"
        views.setTextViewText(R.id.widget_status_subtitle, if (isDayOff) "Day Off" else todayTime)

        // Set click pending intent
        val launchUri = Uri.parse("attendx://widget_action?action=open")
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, launchUri)
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    }

    fun updateViews2x1(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val todayStatus = widgetData.getString("today_status", "pending") ?: "pending"
        val todayTime = widgetData.getString("today_time", "") ?: ""
        val dateText = widgetData.getString("widget_date", "") ?: ""
        val scoreText = widgetData.getString("attendance_score", "") ?: ""

        val isPending = todayStatus == "pending"
        val isDayOff = todayStatus == "sunday" || todayStatus == "holiday"

        // Set status icon
        views.setImageViewResource(R.id.widget_status_icon, getStatusIcon(todayStatus))

        // Set title and subtitle
        if (isPending) {
            views.setTextViewText(R.id.widget_title, "Attendance Pending")
            views.setTextColor(R.id.widget_title, 0xFF090F16.toInt())
            views.setTextViewText(R.id.widget_subtitle, "Tap to mark attendance")
            views.setViewVisibility(R.id.widget_bottom_right_icon, View.VISIBLE)
            views.setViewVisibility(R.id.widget_bottom_right_text, View.GONE)
        } else if (isDayOff) {
            views.setTextViewText(R.id.widget_title, getStatusLabel(todayStatus))
            views.setTextColor(R.id.widget_title, getStatusColor(todayStatus))
            views.setTextViewText(R.id.widget_subtitle, "Day Off")
            views.setViewVisibility(R.id.widget_bottom_right_icon, View.GONE)
            views.setViewVisibility(R.id.widget_bottom_right_text, View.VISIBLE)
            views.setTextViewText(R.id.widget_bottom_right_text, "No attendance needed")
        } else {
            views.setTextViewText(R.id.widget_title, getStatusLabel(todayStatus))
            views.setTextColor(R.id.widget_title, getStatusColor(todayStatus))
            views.setTextViewText(R.id.widget_subtitle, "Today marked at $todayTime")
            views.setViewVisibility(R.id.widget_bottom_right_icon, View.GONE)
            views.setViewVisibility(R.id.widget_bottom_right_text, View.VISIBLE)
            if (scoreText.isNotEmpty()) {
                views.setTextViewText(R.id.widget_bottom_right_text, "Attendance • $scoreText")
            } else {
                views.setTextViewText(R.id.widget_bottom_right_text, "Attendance • Marked")
            }
        }

        // Set date
        if (dateText.isNotEmpty()) {
            views.setTextViewText(R.id.widget_date, dateText)
        }

        // Set click pending intent
        val launchUri = if (isPending) {
            Uri.parse("attendx://widget_action?action=mark_present")
        } else {
            Uri.parse("attendx://widget_action?action=open")
        }
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, launchUri)
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    }

    fun updateViews2x2(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val profileName = widgetData.getString("profile_name", "Shubham") ?: "Shubham"
        val todayStatus = widgetData.getString("today_status", "pending") ?: "pending"
        val todayTime = widgetData.getString("today_time", "") ?: ""
        val countPresent = widgetData.getString("present_count", "0") ?: "0"
        val countHalfDay = widgetData.getString("half_day_count", "0") ?: "0"
        val countAbsent = widgetData.getString("absent_count", "0") ?: "0"
        val scoreText = widgetData.getString("attendance_score", "0.0%") ?: "0.0%"

        views.setTextViewText(R.id.widget_header_title, "Good Morning, $profileName")

        // Status
        views.setImageViewResource(R.id.widget_status_icon, getStatusIcon(todayStatus))
        val isPending = todayStatus == "pending"
        val isDayOff = todayStatus == "sunday" || todayStatus == "holiday"
        when {
            isPending -> {
                views.setTextViewText(R.id.widget_title, "Pending")
                views.setTextColor(R.id.widget_title, 0xFF9AA1B0.toInt())
                views.setTextViewText(R.id.widget_subtitle, "Mark Today")
                views.setViewVisibility(R.id.widget_time_badge, View.GONE)
            }
            isDayOff -> {
                views.setTextViewText(R.id.widget_title, getStatusLabel(todayStatus))
                views.setTextColor(R.id.widget_title, getStatusColor(todayStatus))
                views.setTextViewText(R.id.widget_subtitle, "Day Off")
                views.setViewVisibility(R.id.widget_time_badge, View.GONE)
            }
            else -> {
                views.setTextViewText(R.id.widget_title, getStatusLabel(todayStatus))
                views.setTextColor(R.id.widget_title, getStatusColor(todayStatus))
                views.setTextViewText(R.id.widget_subtitle, "Marked Today")
                views.setViewVisibility(R.id.widget_time_badge, View.VISIBLE)
                views.setTextViewText(R.id.widget_time_badge, todayTime)
                views.setTextColor(R.id.widget_time_badge, getStatusColor(todayStatus))
            }
        }

        // Stats counts
        views.setTextViewText(R.id.widget_count_present, countPresent)
        views.setTextViewText(R.id.widget_count_half_day, countHalfDay)
        views.setTextViewText(R.id.widget_count_absent, countAbsent)

        // Bottom score
        views.setTextViewText(R.id.widget_score_text, scoreText)

        // Click action
        val launchUri = if (isPending) {
            Uri.parse("attendx://widget_action?action=mark_present")
        } else {
            Uri.parse("attendx://widget_action?action=open")
        }
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, launchUri)
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    }

    fun updateViews4x2(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val todayStatus = widgetData.getString("today_status", "pending") ?: "pending"
        val todayTime = widgetData.getString("today_time", "") ?: ""
        val monthYear = widgetData.getString("month_year", "") ?: ""
        val countPresent = widgetData.getString("present_count", "0") ?: "0"
        val countHalfDay = widgetData.getString("half_day_count", "0") ?: "0"
        val countAbsent = widgetData.getString("absent_count", "0") ?: "0"
        
        val earnedSalary = widgetData.getString("earned_salary", "₹0") ?: "₹0"
        val estimatedSalary = widgetData.getString("estimated_salary", "₹0") ?: "₹0"
        val salaryProgress = widgetData.getInt("salary_progress", 0)

        if (monthYear.isNotEmpty()) {
            views.setTextViewText(R.id.widget_month_header, monthYear)
        }

        // Status
        views.setImageViewResource(R.id.widget_status_icon, getStatusIcon(todayStatus))
        val isPending = todayStatus == "pending"
        val isDayOff = todayStatus == "sunday" || todayStatus == "holiday"
        when {
            isPending -> {
                views.setTextViewText(R.id.widget_title, "Pending")
                views.setTextColor(R.id.widget_title, 0xFF9AA1B0.toInt())
                views.setTextViewText(R.id.widget_subtitle, "Attendance Pending")
            }
            isDayOff -> {
                views.setTextViewText(R.id.widget_title, getStatusLabel(todayStatus))
                views.setTextColor(R.id.widget_title, getStatusColor(todayStatus))
                views.setTextViewText(R.id.widget_subtitle, "Day Off")
            }
            else -> {
                views.setTextViewText(R.id.widget_title, getStatusLabel(todayStatus))
                views.setTextColor(R.id.widget_title, getStatusColor(todayStatus))
                views.setTextViewText(R.id.widget_subtitle, "Marked Today · $todayTime")
            }
        }

        // Stats counts
        views.setTextViewText(R.id.widget_count_present, countPresent)
        views.setTextViewText(R.id.widget_count_half_day, countHalfDay)
        views.setTextViewText(R.id.widget_count_absent, countAbsent)

        // Salary Info
        views.setTextViewText(R.id.widget_salary_earned, earnedSalary)
        views.setTextViewText(R.id.widget_salary_estimated, estimatedSalary)
        views.setProgressBar(R.id.widget_salary_progress, 100, salaryProgress, false)
        views.setTextViewText(R.id.widget_salary_percent, "$salaryProgress%")

        // Click action
        val launchUri = if (isPending) {
            Uri.parse("attendx://widget_action?action=mark_present")
        } else {
            Uri.parse("attendx://widget_action?action=open")
        }
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, launchUri)
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    }

    private fun getStatusIcon(status: String): Int {
        return when (status) {
            "present" -> R.drawable.ic_widget_present
            "halfDay" -> R.drawable.ic_widget_halfday
            "absent" -> R.drawable.ic_widget_absent
            "holiday", "sunday" -> R.drawable.ic_widget_holiday
            else -> R.drawable.ic_widget_pending
        }
    }

    private fun getStatusLabel(status: String): String {
        return when (status) {
            "present" -> "Present"
            "halfDay" -> "Half Day"
            "absent" -> "Absent"
            "holiday" -> "Holiday"
            "sunday" -> "Sunday"
            else -> "Pending"
        }
    }

    private fun getStatusColor(status: String): Int {
        return when (status) {
            "present" -> 0xFF22C55E.toInt()
            "halfDay" -> 0xFFF59E0B.toInt()
            "absent" -> 0xFFEF4444.toInt()
            "holiday", "sunday" -> 0xFF0EA5E9.toInt()
            else -> 0xFF9AA1B0.toInt()
        }
    }
}
