package com.attendancetracker.attend

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object AlarmScheduler {
    private const val PREFS = "com.attendancetracker.attend.alarms"
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun scheduleAlarm(context: Context, id: Int, profileId: String, profileName: String,
        hour: Int, minute: Int, isOneShot: Boolean = false,
        repeatDays: List<Int> = listOf(1, 2, 3, 4, 5, 6), alertMode: String = "notification",
        isPrimary: Boolean = true, followUpMinutes: Int = 30, triggerAt: Long? = null) {
        require(hour in 0..23 && minute in 0..59)
        require(isOneShot || (repeatDays.isNotEmpty() && repeatDays.all { it in 1..7 }))
        require(followUpMinutes in 0..180)
        val config = JSONObject().put("id", id).put("profileId", profileId)
            .put("profileName", profileName).put("hour", hour).put("minute", minute)
            .put("isOneShot", isOneShot).put("repeatDays", JSONArray(repeatDays))
            .put("alertMode", alertMode).put("isPrimary", isPrimary)
            .put("followUpMinutes", followUpMinutes)
        val old = load(context, id)
        // Keep a one-time alarm's original date across ordinary app launches.
        val same = old != null && listOf("hour", "minute", "isOneShot", "alertMode", "followUpMinutes", "repeatDays", "isPrimary", "profileId").all { old.opt(it).toString() == config.opt(it).toString() }
        val trigger = triggerAt ?: if (same && old!!.optLong("triggerAt") > System.currentTimeMillis()) old.optLong("triggerAt")
            else nextTriggerMs(hour, minute, if (isOneShot) (1..7).toList() else repeatDays)
        if (same) {
            for (key in listOf("lastMainDate", "followUpAt", "completed")) {
                if (old!!.has(key)) config.put(key, old.get(key))
            }
        }
        config.put("triggerAt", trigger)
        prefs(context).edit().putString(id.toString(), config.toString()).apply()
        if (!same) cancelPending(context, id, true)
        arm(context, config, false, trigger)
    }

    fun load(context: Context, id: Int): JSONObject? = try {
        prefs(context).getString(id.toString(), null)?.let { JSONObject(it) }
    } catch (_: Exception) { null }

    private fun pending(context: Context, id: Int, followUp: Boolean, trigger: Long): PendingIntent =
        PendingIntent.getBroadcast(context, id, Intent(context, AlarmReceiver::class.java).apply {
            action = if (followUp) "FOLLOW_UP" else "MAIN"
            data = Uri.parse("attendx://reminder/$id/$action")
            putExtra("id", id); putExtra("followUp", followUp); putExtra("triggerAt", trigger)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun arm(context: Context, config: JSONObject, followUp: Boolean, trigger: Long) {
        if (trigger <= System.currentTimeMillis()) return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(context, config.getInt("id"), followUp, trigger)
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
        if (exact && !followUp && config.optString("alertMode") == "alarm") {
            val open = PendingIntent.getActivity(context, config.getInt("id"),
                Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            am.setAlarmClock(AlarmManager.AlarmClockInfo(trigger, open), pi)
        } else if (exact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        } else {
            // Exact APIs also require permission; use a genuinely permission-free fallback.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        }
    }

    fun onDelivered(context: Context, config: JSONObject, followUp: Boolean) {
        val id = config.getInt("id")
        if (followUp) {
            config.remove("followUpAt")
        } else {
            config.put("lastMainDate", AttendanceState.dateKey())
            val delay = config.optInt("followUpMinutes")
            if (config.optBoolean("isPrimary") && delay > 0 &&
                !AttendanceState.isMarkedOrDayOff(context, config.optString("profileId"))) {
                nextFollowUpMs(System.currentTimeMillis(), delay)?.let { next ->
                    config.put("followUpAt", next)
                    arm(context, config, true, next)
                }
            }
            if (config.optBoolean("isOneShot")) {
                config.put("completed", true)
            } else {
                val days = config.getJSONArray("repeatDays")
                val next = nextTriggerMs(config.getInt("hour"), config.getInt("minute"),
                    (0 until days.length()).map { days.getInt(it) })
                config.put("triggerAt", next)
                arm(context, config, false, next)
            }
        }
        prefs(context).edit().putString(id.toString(), config.toString()).apply()
    }

    fun cancelPending(context: Context, id: Int, followUp: Boolean) {
        val pi = pending(context, id, followUp, 0)
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
        pi.cancel()
    }

    fun cancelAlarm(context: Context, id: Int) {
        cancelPending(context, id, false); cancelPending(context, id, true)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
        // Cancel the pre-migration PendingIntent too.
        val legacy = PendingIntent.getBroadcast(context, id, Intent(context, AlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        legacy?.let { (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(it); it.cancel() }
        prefs(context).edit().remove(id.toString()).apply()
    }

    fun attendanceMarked(context: Context, profileId: String) {
        for (key in prefs(context).all.keys) {
            val id = key.toIntOrNull() ?: continue
            val c = load(context, id) ?: continue
            if (c.optString("profileId") != profileId || !c.optBoolean("isPrimary")) continue
            cancelPending(context, id, true)
            c.remove("followUpAt")
            prefs(context).edit().putString(key, c.toString()).apply()
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
        }
    }

    fun completedIds(context: Context): List<Int> = prefs(context).all.keys.mapNotNull { key ->
        key.toIntOrNull()?.takeIf { load(context, it)?.optBoolean("completed") == true }
    }

    fun rescheduleAllAlarms(context: Context, clockChanged: Boolean = false) {
        for (key in prefs(context).all.keys) {
            val id = key.toIntOrNull() ?: continue
            val c = load(context, id) ?: continue
            if (!c.optBoolean("completed")) {
                var trigger = c.optLong("triggerAt")
                if (trigger <= System.currentTimeMillis() || clockChanged) {
                    if (c.optBoolean("isOneShot")) {
                        c.put("completed", true)
                        prefs(context).edit().putString(key, c.toString()).apply()
                        continue
                    }
                    val days = c.getJSONArray("repeatDays")
                    trigger = nextTriggerMs(c.getInt("hour"), c.getInt("minute"), (0 until days.length()).map { days.getInt(it) })
                    c.put("triggerAt", trigger)
                }
                arm(context, c, false, trigger)
            }
            val follow = c.optLong("followUpAt")
            if (follow > System.currentTimeMillis() && c.optString("lastMainDate") == AttendanceState.dateKey()) arm(context, c, true, follow)
            prefs(context).edit().putString(key, c.toString()).apply()
        }
    }

    internal fun nextFollowUpMs(deliveredAt: Long, delayMinutes: Int): Long? {
        if (delayMinutes <= 0) return null
        require(delayMinutes <= 180)
        val follow = deliveredAt + delayMinutes * 60_000L
        return follow.takeIf { AttendanceState.dateKey(it) == AttendanceState.dateKey(deliveredAt) }
    }

    internal fun nextTriggerMs(hour: Int, minute: Int, days: List<Int>, now: Long = System.currentTimeMillis()): Long {
        require(days.isNotEmpty() && days.all { it in 1..7 })
        val cal = Calendar.getInstance().apply {
            timeInMillis = now; set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        while (cal.timeInMillis <= now || ((cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1) !in days) cal.add(Calendar.DATE, 1)
        return cal.timeInMillis
    }
}
