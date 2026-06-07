import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Callback invoked (on the main isolate) when the user taps a notification
/// action like "Present", "Absent" or "Half Day".
typedef NotificationActionHandler = void Function(
    String profileId, String actionId);

/// Wraps flutter_local_notifications for daily attendance reminders with
/// quick-action buttons. Gracefully no-ops on web.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String channelId = 'attendance_reminder';
  static const String actionPresent = 'ACTION_PRESENT';
  static const String actionAbsent = 'ACTION_ABSENT';
  static const String actionHalf = 'ACTION_HALF';

  static const _batteryChannel =
      MethodChannel('com.attendancetracker.attend/battery');

  static const _alarmChannel =
      MethodChannel('com.attendancetracker.attend/alarm');

  NotificationActionHandler? onAction;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      _setLocalTimezone();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: android, iOS: ios);
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onResponse,
      );
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init failed: $e');
    }
  }

  /// Sets tz.local to the device's current timezone using the platform timezone ID.
  void _setLocalTimezone() {
    try {
      final platformTz = DateTime.now().timeZoneName;
      // Try to find the location by platform name first
      final locations = tz.timeZoneDatabase.locations;
      if (locations.containsKey(platformTz)) {
        tz.setLocalLocation(locations[platformTz]!);
        return;
      }
      // Fallback: match by UTC offset
      final offset = DateTime.now().timeZoneOffset;
      for (final name in locations.keys) {
        final loc = locations[name]!;
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to set local timezone: $e');
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload; // profileId
    final actionId = response.actionId;
    if (payload != null && actionId != null && onAction != null) {
      onAction!(payload, actionId);
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || !_ready) return;
    try {
      // Request notification display permission
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request exact alarm permission (required on Android 12+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      if (kDebugMode) debugPrint('Permission request failed: $e');
    }
  }

  // ---- Battery Optimization ----

  /// Check if battery optimization is already disabled for this app.
  Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb) return true;
    try {
      final result =
          await _batteryChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('Battery check failed: $e');
      return false;
    }
  }

  /// Request the OS dialog to disable battery optimization for this app.
  Future<void> requestDisableBatteryOptimization() async {
    if (kIsWeb) return;
    try {
      await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      if (kDebugMode) debugPrint('Battery opt request failed: $e');
    }
  }

  /// Check if exact alarm permission is granted.
  Future<bool> isExactAlarmPermissionGranted() async {
    if (kIsWeb) return true;
    try {
      final result =
          await _batteryChannel.invokeMethod<bool>('isExactAlarmPermissionGranted');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('Exact alarm check failed: $e');
      return false;
    }
  }

  /// Request the system exact alarm settings page.
  Future<void> requestExactAlarmPermission() async {
    if (kIsWeb) return;
    try {
      await _batteryChannel.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      if (kDebugMode) debugPrint('Exact alarm request failed: $e');
    }
  }

  // ---- Scheduling ----

  /// Schedule a daily reminder at [hour]:[minute] for a profile, with
  /// Present / Half Day / Absent quick-action buttons.
  Future<void> scheduleDailyReminder({
    required int id,
    required String profileId,
    required String profileName,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    try {
      // Cancel local notification if scheduled previously
      if (_ready) {
        await _plugin.cancel(id);
      }

      // Schedule exact daily alarm natively
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': id,
        'profileId': profileId,
        'profileName': profileName,
        'hour': hour,
        'minute': minute,
        'isOneShot': false,
      });

      if (kDebugMode) {
        debugPrint(
          'Native daily alarm scheduled for "$profileName" (id: $id) '
          'at $hour:${minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Native scheduleDailyReminder failed: $e');
    }
  }

  /// Schedule a ONE-SHOT test notification at a specific [DateTime].
  /// Does NOT repeat daily — meant only for testing.
  Future<void> scheduleTestNotification({
    required DateTime scheduledTime,
    required String profileId,
    required String profileName,
  }) async {
    if (kIsWeb) return;
    try {
      const testId = 88888;
      if (_ready) {
        await _plugin.cancel(testId);
      }

      // Schedule exact one-shot alarm natively
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': testId,
        'profileId': profileId,
        'profileName': profileName,
        'hour': scheduledTime.hour,
        'minute': scheduledTime.minute,
        'isOneShot': true,
      });

      if (kDebugMode) {
        debugPrint(
          'Native test alarm scheduled for "$profileName" at '
          '${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Native scheduleTestNotification failed: $e');
    }
  }

  /// Show an immediate test notification (useful for the "Test" button).
  Future<void> showTestNow({
    required String profileId,
    required String profileName,
  }) async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.show(
        99999,
        'Mark your attendance',
        'Did $profileName attend today? Mark Present, Half Day or Absent.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Attendance Reminder',
            channelDescription: 'Daily attendance reminder',
            importance: Importance.max,
            priority: Priority.high,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(actionPresent, 'Present'),
              AndroidNotificationAction(actionHalf, 'Half Day'),
              AndroidNotificationAction(actionAbsent, 'Absent'),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: profileId,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Show test failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    try {
      if (_ready) {
        await _plugin.cancel(id);
      }
      await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
    } catch (_) {}
  }

  /// Cancel all pending notifications.
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      if (_ready) {
        await _plugin.cancelAll();
      }
      // There's no custom channel cancelAll natively, but cancelling via local is fine
      // and individual profile alarms are cancelled during profile edit/delete.
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
