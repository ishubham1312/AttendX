package com.attendancetracker.attend

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.attendancetracker.attend/battery"
    private val ALARM_CHANNEL   = "com.attendancetracker.attend/alarm"

    override fun onResume() {
        super.onResume()
        AlarmScheduler.rescheduleAllAlarms(this)
        WidgetHelper.refreshAll(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationDisabled" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } else result.success(true)
                    }
                    "requestDisableBatteryOptimization" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivity(
                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            )
                        }
                        result.success(true)
                    }
                    "isExactAlarmPermissionGranted" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(am.canScheduleExactAlarms())
                        } else result.success(true)
                    }
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            startActivity(
                                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            )
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        AlarmScheduler.scheduleAlarm(
                            context,
                            call.argument<Int>("id") ?: 88888,
                            call.argument<String>("profileId") ?: "",
                            call.argument<String>("profileName") ?: "Me",
                            call.argument<Int>("hour") ?: 9,
                            call.argument<Int>("minute") ?: 0,
                            call.argument<Boolean>("isOneShot") ?: false,
                            call.argument<List<Int>>("repeatDays") ?: listOf(1, 2, 3, 4, 5, 6),
                            call.argument<String>("alertMode") ?: "notification",
                            call.argument<Boolean>("isPrimary") ?: true,
                            call.argument<Int>("followUpMinutes") ?: 30,
                            call.argument<Number>("triggerAt")?.toLong()
                        )
                        result.success(true)
                    }
                    "googleMapsConfigured" -> {
                        val info = packageManager.getApplicationInfo(packageName, android.content.pm.PackageManager.GET_META_DATA)
                        result.success(!info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrBlank())
                    }
                    "syncAttendance" -> {
                        AttendanceState.sync(context, call.argument<String>("profiles") ?: "[]", call.argument<String>("active") ?: "")
                        result.success(true)
                    }
                    "setAttendance" -> {
                        AttendanceState.mark(context, call.argument<String>("profileId")!!, call.argument<String>("date")!!, call.argument<String>("raw"))
                        result.success(true)
                    }
                    "pendingAttendance" -> result.success(AttendanceState.pending(context))
                    "ackAttendance" -> {
                        AttendanceState.acknowledge(context, call.argument<Map<String, String>>("values") ?: emptyMap())
                        result.success(true)
                    }
                    "completedAlarms" -> result.success(AlarmScheduler.completedIds(context))
                    "refreshWidgets" -> { WidgetHelper.refreshAll(context); result.success(true) }
                    "cancelAlarm" -> {
                        AlarmScheduler.cancelAlarm(context, call.argument<Int>("id") ?: 88888)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
