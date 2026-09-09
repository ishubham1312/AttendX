package com.attendancetracker.attend

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

object WidgetHelper {
    fun refreshAll(context: Context) {
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        val providers = listOf(WidgetProvider1x1::class.java, WidgetProvider2x1::class.java,
            WidgetProvider2x2::class.java, WidgetProvider4x2::class.java)
        var hasWidgets = false
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(android.content.ComponentName(context, provider))
            if (ids.isEmpty()) continue
            hasWidgets = true
            context.sendBroadcast(android.content.Intent(context, provider).apply {
                action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            })
        }
        if (hasWidgets) {
            val next = java.util.Calendar.getInstance().apply {
                add(java.util.Calendar.DATE, 1); set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0); set(java.util.Calendar.SECOND, 1)
            }.timeInMillis
            val pi = android.app.PendingIntent.getBroadcast(context, 771122,
                android.content.Intent(context, AlarmBootReceiver::class.java).setAction("com.attendancetracker.attend.REFRESH_WIDGETS"),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
            (context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager)
                .setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, next, pi)
        }
    }

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
        val profileName = widgetData.getString("profile_name", "Your profile") ?: "Your profile"
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

/** Native mirror of Hive, plus a durable per-profile/date journal for notification actions. */
object AttendanceState {
    private fun prefs(c: Context) = c.getSharedPreferences("attendance_state_v2", Context.MODE_PRIVATE)
    fun dateKey(time: Long = System.currentTimeMillis()): String = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date(time))
    private fun profile(c: Context, id: String): org.json.JSONObject? = prefs(c).getString("profile_$id", null)?.let { org.json.JSONObject(it) }
    private fun records(c: Context, id: String) = org.json.JSONObject(prefs(c).getString("records_$id", "{}") ?: "{}")
    fun pending(c: Context): Map<String, String> = prefs(c).all.filterKeys { it.startsWith("pending_") }.mapValues { it.value as String }
    fun acknowledge(c: Context, values: Map<String, String>) {
        val edit = prefs(c).edit()
        for ((key, value) in values) if (prefs(c).getString(key, null) == value) edit.remove(key)
        edit.apply()
    }
    fun sync(c: Context, profiles: String, active: String) {
        val all = org.json.JSONArray(profiles)
        val ids = (0 until all.length()).map { all.getJSONObject(it).getString("id") }.toSet()
        val edit = prefs(c).edit().putString("active", active)
        // Remove deleted profile snapshots and journals.
        for (key in prefs(c).all.keys) {
            if (key.startsWith("profile_") && key.removePrefix("profile_") !in ids) {
                val id = key.removePrefix("profile_")
                edit.remove(key).remove("records_$id")
                for (pendingKey in pending(c).keys) if (pendingKey.startsWith("pending_$id|")) edit.remove(pendingKey)
            }
        }
        for (i in 0 until all.length()) {
            val p = all.getJSONObject(i); val id = p.getString("id")
            val rec = p.getJSONObject("records")
            // A tap received while Flutter was syncing must not be lost.
            for ((key, value) in pending(c)) if (key.startsWith("pending_$id|")) rec.put(key.substringAfter('|'), value)
            edit.putString("profile_$id", p.toString()).putString("records_$id", rec.toString())
        }
        edit.apply()
        for (id in ids) if (isMarkedOrDayOff(c, id)) AlarmScheduler.attendanceMarked(c, id)
        WidgetHelper.refreshAll(c)
    }
    fun mark(c: Context, id: String, date: String, raw: String?, journal: Boolean = false) {
        if (profile(c, id) == null) return
        val rec = records(c, id)
        if (raw == null) rec.remove(date) else rec.put(date, raw)
        val edit = prefs(c).edit().putString("records_$id", rec.toString())
        val key = "pending_$id|$date"
        if (journal && raw != null) edit.putString(key, raw) else edit.remove(key)
        if (raw != null) edit.putString("time_$id|$date", java.text.SimpleDateFormat("hh:mm a", java.util.Locale.getDefault()).format(java.util.Date()))
        else edit.remove("time_$id|$date")
        edit.commit() // Durable before acknowledging an action to the OS.
        if (date == dateKey() && raw != null) AlarmScheduler.attendanceMarked(c, id)
        WidgetHelper.refreshAll(c)
    }
    fun isMarkedOrDayOff(c: Context, id: String): Boolean {
        val p = profile(c, id) ?: return true
        val date = dateKey()
        return records(c, id).has(date) || isDayOff(p, date) || date < p.optString("startDate").take(10)
    }
    private fun isDayOff(p: org.json.JSONObject, date: String): Boolean {
        val parsed = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).parse(date) ?: return false
        val cal = java.util.Calendar.getInstance().apply { time = parsed }
        val holidays = p.optJSONArray("holidays") ?: org.json.JSONArray()
        return cal.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.SUNDAY ||
            (0 until holidays.length()).any { holidays.getString(it) == date }
    }
    fun updateWidgetData(c: Context) {
        val prefs = prefs(c)
        val id = prefs.getString("active", "") ?: ""
        val p = profile(c, id)
        val data = c.getSharedPreferences("HomeWidgetSharedPreferences", Context.MODE_PRIVATE)
        if (p == null) { data.edit().clear().apply(); return }
        val rec = records(c, id)
        val now = java.util.Calendar.getInstance()
        val today = dateKey()
        val month = today.take(7)
        val status = if (rec.has(today)) rec.getString(today).substringBefore(':')
            else if (isDayOff(p, today)) { if (now.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.SUNDAY) "sunday" else "holiday" }
            else "pending"
        val end = rec.keys().asSequence().filter { it.startsWith("$month-") }.map { it.takeLast(2).toInt() }.maxOrNull() ?: 0
        val startDate = p.optString("startDate").take(10)
        var present = 0; var absent = 0; var half = 0; var paidHolidays = 0
        fun statusAt(date: String): String? = if (rec.has(date)) rec.getString(date).substringBefore(':') else if (isDayOff(p, date)) "holiday" else null
        for (day in 1..end) {
            val date = "$month-${day.toString().padStart(2, '0')}"
            if (date < startDate) continue
            when (statusAt(date)) {
                "present" -> present++
                "absent" -> absent++
                "halfDay" -> half++
                "holiday" -> {
                    var paid = true
                    if (p.optBoolean("sandwichLeaveEnabled")) {
                        val prev = java.util.Calendar.getInstance().apply { time = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).parse(date)!! }
                        for (i in 0 until 30) {
                            prev.add(java.util.Calendar.DATE, -1)
                            val d = dateKey(prev.timeInMillis)
                            val st = if (d < startDate) null else statusAt(d)
                            if (st != "holiday") { paid = st != "absent"; break }
                        }
                    }
                    if (paid) paidHolidays++
                }
            }
        }
        val salary = p.optDouble("monthlySalary", 0.0)
        val earned = salary / now.getActualMaximum(java.util.Calendar.DAY_OF_MONTH) * (present + half * 0.5 + paidHolidays)
        val total = present + absent + half
        val score = if (total == 0) 0.0 else (present + half * 0.5) / total * 100
        fun money(value: Double) = "₹" + String.format(java.util.Locale.US, "%,d", Math.round(value))
        data.edit().putString("profile_name", p.optString("name"))
            .putString("today_status", status).putString("today_status_date", today)
            .putString("today_time", if (status == "pending") "Mark Today" else prefs.getString("time_$id|$today", "Marked"))
            .putString("widget_date", java.text.SimpleDateFormat("MMMM dd, yyyy", java.util.Locale.getDefault()).format(now.time))
            .putString("month_year", java.text.SimpleDateFormat("MMMM yyyy", java.util.Locale.getDefault()).format(now.time))
            .putString("present_count", "$present").putString("absent_count", "$absent").putString("half_day_count", "$half")
            .putString("attendance_score", String.format(java.util.Locale.US, "%.1f%%", score))
            .putString("earned_salary", money(earned)).putString("estimated_salary", money(salary))
            .putInt("salary_progress", if (salary <= 0) 0 else (earned / salary * 100).toInt().coerceIn(0, 100)).apply()
    }
}
