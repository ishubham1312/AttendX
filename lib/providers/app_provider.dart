import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_status.dart';
import '../models/alarm_model.dart';
import '../models/profile.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_storage_service.dart';
import '../services/widget_service.dart';

class AttendanceStats {
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int totalMarked;
  final double percentage; // 0-100
  final double earnedSalary;
  final double estimatedFullSalary;
  final double deduction;

  AttendanceStats({
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.totalMarked,
    required this.percentage,
    required this.earnedSalary,
    required this.estimatedFullSalary,
    required this.deduction,
  });
}

class AppProvider extends ChangeNotifier {
  final StorageService storage;
  final NotificationService notifications;
  final AlarmStorageService alarmStorage;

  AppProvider(this.storage, this.notifications, this.alarmStorage);

  List<Profile> _profiles = [];
  String? _activeProfileId;

  /// Whether the dashboard stat counters have already played their
  /// 0 -> value animation during this app launch. Reset only on cold start.
  bool dashboardStatsPlayed = false;

  List<Profile> get profiles => _profiles;
  bool get onboardingDone => storage.onboardingDone;

  Profile? get activeProfile {
    if (_profiles.isEmpty) return null;
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  void load() {
    _profiles = storage.getProfiles();
    _activeProfileId = storage.activeProfileId ??
        (_profiles.isNotEmpty ? _profiles.first.id : null);
    notifyListeners();
    WidgetService.updateWidgets(this);
    // Re-schedule notifications for all profiles on every app launch
    // so they survive app kills, reboots, and updates.
    _rescheduleAllReminders();
    checkAndApplyPendingAttendance();
    // Ensure primary alarms exist for all profiles
    _ensurePrimaryAlarms();
  }

  void _ensurePrimaryAlarms() {
    for (final p in _profiles) {
      alarmStorage.ensurePrimaryAlarm(
        profileId: p.id,
        profileName: p.name,
        hour: p.reminderHour,
        minute: p.reminderMinute,
      );
    }
  }

  Future<void> checkAndApplyPendingAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('pending_attendance_')).toList();
      if (keys.isEmpty) return;

      bool changed = false;
      for (final key in keys) {
        final val = prefs.getString(key);
        if (val != null) {
          final profileId = key.replaceFirst('pending_attendance_', '');
          final parts = val.split('|');
          if (parts.length >= 2) {
            final statusStr = parts[0];
            final dateStr = parts[1];
            final date = DateTime.parse(dateStr);
            final status = AttendanceStatus.values.firstWhere(
              (e) => e.name == statusStr,
              orElse: () => AttendanceStatus.present,
            );
            HalfType? half;
            if (parts.length >= 3) {
              half = HalfType.values.firstWhere(
                (e) => e.name == parts[2],
                orElse: () => HalfType.firstHalf,
              );
            }
            final entry = AttendanceEntry(
              status,
              status == AttendanceStatus.halfDay ? (half ?? HalfType.firstHalf) : null,
            );
            await storage.setStatusRaw(profileId, date, entry.toStorage());
            changed = true;
          }
        }
        await prefs.remove(key);
      }
      if (changed) {
        // Reload locally to refresh UI & trigger widgets
        _profiles = storage.getProfiles();
        _activeProfileId = storage.activeProfileId ??
            (_profiles.isNotEmpty ? _profiles.first.id : null);
        notifyListeners();
        WidgetService.updateWidgets(this);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error processing pending attendance: $e');
    }
  }

  Future<void> _rescheduleAllReminders() async {
    for (final p in _profiles) {
      await _scheduleReminder(p);
    }
  }

  Future<void> completeOnboarding() async {
    await storage.setOnboardingDone(true);
    notifyListeners();
  }

  // ---- Profiles ----
  Future<void> addProfile(Profile p, {bool makeActive = true}) async {
    await storage.saveProfile(p);
    if (makeActive) {
      _activeProfileId = p.id;
      await storage.setActiveProfileId(p.id);
    }
    await _scheduleReminder(p);
    load();
  }

  Future<void> updateProfile(Profile p) async {
    await storage.saveProfile(p);
    await _scheduleReminder(p);
    // Sync primary alarm time when profile reminder changes
    await alarmStorage.syncPrimaryAlarmWithProfile(
      profileId: p.id,
      hour: p.reminderHour,
      minute: p.reminderMinute,
    );
    load();
  }

  Future<void> deleteProfile(String id) async {
    await notifications.cancel(id.hashCode);
    await storage.deleteProfile(id);
    if (_activeProfileId == id) {
      _activeProfileId = null;
    }
    load();
  }

  Future<void> setActiveProfile(String id) async {
    _activeProfileId = id;
    await storage.setActiveProfileId(id);
    notifyListeners();
    WidgetService.updateWidgets(this);
  }

  Future<void> _scheduleReminder(Profile p) async {
    await notifications.scheduleDailyReminder(
      id: p.id.hashCode,
      profileId: p.id,
      profileName: p.name,
      hour: p.reminderHour,
      minute: p.reminderMinute,
    );
  }

  // ---- Attendance ----
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isHolidayDate(DateTime date) {
    final p = activeProfile;
    if (p == null) return false;
    return p.holidays.contains(_dateKey(date));
  }

  AttendanceEntry? entryFor(DateTime date) {
    final p = activeProfile;
    if (p == null) return null;
    final raw = storage.getStatusRaw(p.id, date);
    if (raw == null) {
      if (date.weekday == DateTime.sunday ||
          p.holidays.contains(_dateKey(date))) {
        return AttendanceEntry(AttendanceStatus.holiday, null);
      }
      return null;
    }
    return AttendanceEntry.fromStorage(raw);
  }

  AttendanceStatus? statusFor(DateTime date) => entryFor(date)?.status;

  bool isManuallyMarked(DateTime date) {
    final p = activeProfile;
    if (p == null) return false;
    return storage.getStatusRaw(p.id, date) != null;
  }

  Future<void> toggleHoliday(DateTime date) async {
    final p = activeProfile;
    if (p == null) return;
    final key = _dateKey(date);
    final updated = List<String>.from(p.holidays);
    if (updated.contains(key)) {
      updated.remove(key);
    } else {
      updated.add(key);
    }
    p.holidays = updated;
    await storage.saveProfile(p);
    notifyListeners();
    WidgetService.updateWidgets(this);
  }

  Future<void> mark(DateTime date, AttendanceStatus status,
      {HalfType? half}) async {
    final p = activeProfile;
    if (p == null) return;
    final entry = AttendanceEntry(
        status, status == AttendanceStatus.halfDay ? (half ?? HalfType.firstHalf) : null);
    await storage.setStatusRaw(p.id, date, entry.toStorage());
    notifyListeners();
    WidgetService.updateWidgets(this);
  }

  Future<void> clear(DateTime date) async {
    final p = activeProfile;
    if (p == null) return;
    await storage.clearStatus(p.id, date);
    notifyListeners();
    WidgetService.updateWidgets(this);
  }

  Map<DateTime, AttendanceEntry> recordsFor(String profileId) {
    final raw = storage.getAllForProfile(profileId);
    final result = raw.map((k, v) => MapEntry(k, AttendanceEntry.fromStorage(v)));

    // Find the profile to get the start date
    final p = _profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => activeProfile ?? Profile(id: '', name: '', startDate: DateTime.now()),
    );
    if (p.id.isNotEmpty) {
      final start = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      final end = DateTime.now().add(const Duration(days: 365));
      var d = start;
      while (!d.isAfter(end)) {
        if (d.weekday == DateTime.sunday ||
            p.holidays.contains(_dateKey(d))) {
          final normalized = DateTime(d.year, d.month, d.day);
          if (!result.containsKey(normalized)) {
            result[normalized] = AttendanceEntry(AttendanceStatus.holiday, null);
          }
        }
        d = d.add(const Duration(days: 1));
      }
    }
    return result;
  }

  /// Count weekdays (Mon-Fri) in a given month up to [until] (inclusive).
  int _weekdaysInMonth(DateTime month, {DateTime? until}) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final end = until != null && until.isBefore(lastDay) ? until : lastDay;
    int count = 0;
    var d = firstDay;
    while (!d.isAfter(end)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        count++;
      }
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  bool isSandwichLeave(String profileId, DateTime date, Map<DateTime, AttendanceEntry> records) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // 1. Search backward for the nearest non-holiday marked status
    DateTime prevDate = normalizedDate.subtract(const Duration(days: 1));
    AttendanceStatus? prevStatus;
    for (int i = 0; i < 30; i++) {
      final entry = records[prevDate];
      if (entry != null) {
        if (entry.status != AttendanceStatus.holiday) {
          prevStatus = entry.status;
          break;
        }
      } else {
        break; // stop on unmarked
      }
      prevDate = prevDate.subtract(const Duration(days: 1));
    }

    if (prevStatus != AttendanceStatus.absent) {
      return false;
    }

    // 2. Search forward for the nearest non-holiday marked status
    DateTime nextDate = normalizedDate.add(const Duration(days: 1));
    AttendanceStatus? nextStatus;
    for (int i = 0; i < 30; i++) {
      final entry = records[nextDate];
      if (entry != null) {
        if (entry.status != AttendanceStatus.holiday) {
          nextStatus = entry.status;
          break;
        }
      } else {
        break; // stop on unmarked
      }
      nextDate = nextDate.add(const Duration(days: 1));
    }

    return nextStatus == AttendanceStatus.absent;
  }

  AttendanceStatus? effectiveStatusFor(DateTime date) {
    final entry = entryFor(date);
    if (entry == null) return null;
    if (entry.status == AttendanceStatus.holiday) {
      final p = activeProfile;
      if (p != null && p.sandwichLeaveEnabled) {
        final records = recordsFor(p.id);
        if (isSandwichLeave(p.id, date, records)) {
          return AttendanceStatus.absent;
        }
      }
    }
    return entry.status;
  }

  /// Compute stats for the active profile.
  /// If [month] is provided, restrict to that month.
  AttendanceStats stats({DateTime? month}) {
    final p = activeProfile;
    if (p == null) {
      return AttendanceStats(
        presentDays: 0,
        absentDays: 0,
        halfDays: 0,
        totalMarked: 0,
        percentage: 0,
        earnedSalary: 0,
        estimatedFullSalary: 0,
        deduction: 0,
      );
    }
    final records = recordsFor(p.id);
    int present = 0, absent = 0, half = 0;
    records.forEach((date, entry) {
      if (month != null &&
          (date.year != month.year || date.month != month.month)) {
        return;
      }
      if (date.isBefore(
          DateTime(p.startDate.year, p.startDate.month, p.startDate.day))) {
        return;
      }

      var effectiveStatus = entry.status;
      if (effectiveStatus == AttendanceStatus.holiday) {
        final today = DateTime.now();
        final todayMidnight = DateTime(today.year, today.month, today.day);
        if (date.isAfter(todayMidnight)) {
          return;
        }
        if (p.sandwichLeaveEnabled && isSandwichLeave(p.id, date, records)) {
          effectiveStatus = AttendanceStatus.absent;
        }
      }

      switch (effectiveStatus) {
        case AttendanceStatus.present:
        case AttendanceStatus.holiday:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.halfDay:
          half++;
          break;
      }
    });

    final effectiveDays = present + half * 0.5;
    final totalConsidered = present + absent + half;
    final percentage =
        totalConsidered == 0 ? 0.0 : (effectiveDays / totalConsidered) * 100;

    // Fixed 30-day month for simple per-day salary calculation.
    // e.g. ₹30,000/month → ₹1,000/day
    const int daysInMonth = 30;
    final perDay = p.monthlySalary / daysInMonth;

    final earned = perDay * effectiveDays;
    final estimatedFull = p.monthlySalary;
    final deduction = perDay * (absent + half * 0.5);

    return AttendanceStats(
      presentDays: present,
      absentDays: absent,
      halfDays: half,
      totalMarked: totalConsidered,
      percentage: percentage,
      earnedSalary: earned,
      estimatedFullSalary: estimatedFull,
      deduction: deduction,
    );
  }

  // ---- Alarms ----
  List<AlarmItem> getAlarms() => alarmStorage.getAlarms();

  Future<void> saveAlarm(AlarmItem alarm) async {
    await alarmStorage.saveAlarm(alarm);
    // Schedule/update the alarm in the native scheduler
    if (alarm.isEnabled) {
      await notifications.scheduleDailyReminder(
        id: alarm.id.hashCode,
        profileId: alarm.linkedProfileId ?? activeProfile?.id ?? '',
        profileName: alarm.name,
        hour: alarm.hour,
        minute: alarm.minute,
      );
    } else {
      await notifications.cancel(alarm.id.hashCode);
    }
    notifyListeners();
  }

  Future<void> deleteAlarm(String alarmId) async {
    final alarm = alarmStorage.getAlarm(alarmId);
    if (alarm != null && alarm.isPrimary) return; // Cannot delete primary
    await notifications.cancel(alarmId.hashCode);
    await alarmStorage.deleteAlarm(alarmId);
    notifyListeners();
  }

  Future<void> toggleAlarm(String alarmId, bool enabled) async {
    final alarm = alarmStorage.getAlarm(alarmId);
    if (alarm == null) return;
    alarm.isEnabled = enabled;
    await alarmStorage.saveAlarm(alarm);
    if (enabled) {
      await notifications.scheduleDailyReminder(
        id: alarm.id.hashCode,
        profileId: alarm.linkedProfileId ?? activeProfile?.id ?? '',
        profileName: alarm.name,
        hour: alarm.hour,
        minute: alarm.minute,
      );
    } else {
      await notifications.cancel(alarm.id.hashCode);
    }
    notifyListeners();
  }
}
