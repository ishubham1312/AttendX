import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

typedef NotificationActionHandler = void Function(
    String profileId, String actionId);

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
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onResponse,
      );
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init failed: $e');
    }
  }

  void _setLocalTimezone() {
    try {
      final platformTz = DateTime.now().timeZoneName;
      final locations = tz.timeZoneDatabase.locations;
      if (locations.containsKey(platformTz)) {
        tz.setLocalLocation(locations[platformTz]!);
        return;
      }
      // Fallback: match by UTC offset
      final offset = DateTime.now().timeZoneOffset;
      for (final loc in locations.values) {
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
    final payload = response.payload;
    final actionId = response.actionId;
    if (payload != null && actionId != null && onAction != null) {
      onAction!(payload, actionId);
    }
  }

  /// Request ALL permissions needed for reliable alarm delivery.
  Future<void> requestPermissions() async {
    if (kIsWeb || !_ready) return;
    try {
      // 1. POST_NOTIFICATIONS (Android 13+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // 2. SCHEDULE_EXACT_ALARM (Android 12+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      // Background execution is handled by smart platform behavior.
      // Avoid forcing a battery optimization exemption prompt.
    } catch (e) {
      if (kDebugMode) debugPrint('Permission request failed: $e');
    }
  }

  // ---- Battery / System ----

  Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb) return true;
    try {
      return await _batteryChannel
              .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestDisableBatteryOptimization() async {
    if (kIsWeb) return;
    try {
      await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
    } catch (_) {}
  }

  Future<bool> isExactAlarmPermissionGranted() async {
    if (kIsWeb) return true;
    try {
      return await _batteryChannel
              .invokeMethod<bool>('isExactAlarmPermissionGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestExactAlarmPermission() async {
    if (kIsWeb) return;
    try {
      await _batteryChannel.invokeMethod('requestExactAlarmPermission');
    } catch (_) {}
  }

  // ---- Scheduling ----

  /// Schedule (or reschedule) a daily native alarm at [hour]:[minute].
  Future<void> scheduleDailyReminder({
    required int id,
    required String profileId,
    required String profileName,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    try {
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
            'Native daily alarm scheduled: "$profileName" at $hour:${minute.toString().padLeft(2, '0')}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleDailyReminder failed: $e');
    }
  }

  /// Schedule a one-shot test alarm firing at [scheduledTime].
  Future<void> scheduleTestNotification({
    required DateTime scheduledTime,
    required String profileId,
    required String profileName,
  }) async {
    if (kIsWeb) return;
    try {
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': 88888,
        'profileId': profileId,
        'profileName': profileName,
        'hour': scheduledTime.hour,
        'minute': scheduledTime.minute,
        'isOneShot': true,
      });
      if (kDebugMode) {
        debugPrint(
            'Test alarm scheduled for "$profileName" at ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleTestNotification failed: $e');
    }
  }

  /// Show an immediate notification (no scheduling).
  Future<void> showTestNow({
    required String profileId,
    required String profileName,
  }) async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.show(
        99999,
        '⏰ Mark Your Attendance',
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
      if (kDebugMode) debugPrint('showTestNow failed: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (kIsWeb) {
      debugPrint('Web Notification: $title - $body');
      return;
    }
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Attendance Reminder',
            channelDescription: 'Daily attendance reminder',
            importance: Importance.max,
            priority: Priority.high,
            actions: actions,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('showNotification failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    try {
      if (_ready) await _plugin.cancel(id);
      await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      if (_ready) await _plugin.cancelAll();
    } catch (_) {}
  }
}
