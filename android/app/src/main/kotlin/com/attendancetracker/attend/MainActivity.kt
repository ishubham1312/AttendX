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
    private val CHANNEL = "com.attendancetracker.attend/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationDisabled" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } else {
                            result.success(true)
                        }
                    }
                    "requestDisableBatteryOptimization" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    }
                    "isExactAlarmPermissionGranted" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(alarmManager.canScheduleExactAlarms())
                        } else {
                            result.success(true)
                        }
                    }
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.attendancetracker.attend/alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<Int>("id") ?: 88888
                        val profileId = call.argument<String>("profileId") ?: ""
                        val profileName = call.argument<String>("profileName") ?: "Me"
                        val hour = call.argument<Int>("hour") ?: 9
                        val minute = call.argument<Int>("minute") ?: 0
                        val isOneShot = call.argument<Boolean>("isOneShot") ?: false
                        
                        AlarmScheduler.scheduleAlarm(context, id, profileId, profileName, hour, minute, isOneShot)
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        val id = call.argument<Int>("id") ?: 88888
                        AlarmScheduler.cancelAlarm(context, id)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
