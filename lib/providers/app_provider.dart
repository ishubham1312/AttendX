import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_status.dart';
import '../models/alarm_model.dart';
import '../models/profile.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_storage_service.dart';
import '../services/widget_service.dart';
import '../services/gps_attendance_service.dart';
import '../services/motivational_notification_service.dart';

class AttendanceStats {
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int totalMarked;
  final double percentage; // 0-100
  final double earnedSalary;
  final double estimatedFullSalary;
  final double deduction;
  final double payableDays;
  final double paidHolidays;
  final double deductedHolidays;

  AttendanceStats({
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.totalMarked,
    required this.percentage,
    required this.earnedSalary,
    required this.estimatedFullSalary,
    required this.deduction,
    required this.payableDays,
    required this.paidHolidays,
    required this.deductedHolidays,
  });
}

class AppProvider extends ChangeNotifier {
  final StorageService storage;
  final NotificationService notifications;
  final AlarmStorageService alarmStorage;
  late final GPSAttendanceService gpsAttendance;
  late final MotivationalNotificationService motivationalNotifications;
  
  AttendanceStatus? _lastTodayStatus;

  AppProvider(this.storage, this.notifications, this.alarmStorage) {
    gpsAttendance = GPSAttendanceService(storage, notifications);
    gpsAttendance.addListener(() {
      notifyListeners();
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final currentStatus = entryFor(todayDate)?.status;
      if (currentStatus != _lastTodayStatus) {
        _lastTodayStatus = currentStatus;
        WidgetService.updateWidgets(this);
      }
    });
    motivationalNotifications = MotivationalNotificationService(storage, notifications);
  }

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
    
    if (_activeProfileId != null) {
      gpsAttendance.init(_activeProfileId!);
    } else {
      gpsAttendance.stopTracking();
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    _lastTodayStatus = entryFor(todayDate)?.status;

    notifyListeners();
    WidgetService.updateWidgets(this);
    // Re-schedule notifications for all profiles on every app launch
    // so they survive app kills, reboots, and updates.
    _rescheduleAllReminders();
    checkAndApplyPendingAttendance();
    // Ensure primary alarms exist for all profiles
    _ensurePrimaryAlarms();
    _applyAutoAbsent();
  }

  Future<void> _applyAutoAbsent() async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    bool anyChanged = false;

    for (final p in _profiles) {
      final start = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      var d = start;
      while (!d.isAfter(now)) {
        final dateKeyStr = _dateKey(d);
        final dDate = DateTime(d.year, d.month, d.day);

        // Skip Sundays and holidays
        if (d.weekday == DateTime.sunday || p.holidays.contains(dateKeyStr)) {
          d = d.add(const Duration(days: 1));
          continue;
        }

        final isToday = dDate.isAtSameMomentAs(todayDate);
        if (isToday) {
          if (now.hour >= 14) {
            final existing = storage.getStatusRaw(p.id, dDate);
            if (existing == null) {
              final entry = AttendanceEntry(AttendanceStatus.absent);
              await storage.setStatusRaw(p.id, dDate, entry.toStorage());

              final metadata = {
                'timestamp': now.millisecondsSinceEpoch,
                'method': 'Auto Marked Absent (2 PM Deadline)',
                'gpsVerified': false,
                'reason': 'User did not mark attendance by 2 PM deadline.',
              };
              await storage.setAttendanceMetadata(p.id, dDate, metadata);
              anyChanged = true;
            }
          }
        } else {
          final existing = storage.getStatusRaw(p.id, dDate);
          if (existing == null) {
            final entry = AttendanceEntry(AttendanceStatus.absent);
            await storage.setStatusRaw(p.id, dDate, entry.toStorage());

            final metadata = {
              'timestamp': d.millisecondsSinceEpoch,
              'method': 'Auto Marked Absent (Missed Day)',
              'gpsVerified': false,
              'reason': 'User did not mark attendance for this day.',
            };
            await storage.setAttendanceMetadata(p.id, dDate, metadata);
            anyChanged = true;
          }
        }

        d = d.add(const Duration(days: 1));
      }
    }

    if (anyChanged) {
      notifyListeners();
      WidgetService.updateWidgets(this);
    }
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
    await gpsAttendance.init(id);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    _lastTodayStatus = entryFor(todayDate)?.status;
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

    // Stop/cancel reminders for that day once Present is marked
    if (status == AttendanceStatus.present) {
      notifications.cancel(p.id.hashCode);
    }

    // Update active geofence/tracking service state
    gpsAttendance.updateTrackingState();

    notifyListeners();
    WidgetService.updateWidgets(this);

    // Trigger motivational engine check
    Future.delayed(const Duration(seconds: 1), () {
      motivationalNotifications.checkAndTrigger(p);
    });
  }

  Future<void> clear(DateTime date) async {
    final p = activeProfile;
    if (p == null) return;
    await storage.clearStatus(p.id, date);

    // Update active geofence/tracking service state
    gpsAttendance.updateTrackingState();

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


  bool isSandwichLeave(String profileId, DateTime date, Map<DateTime, AttendanceEntry> records) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Search backward for the nearest non-holiday status (could be marked or virtual non-holiday)
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
        // If there's no entry, it's a regular weekday that is unmarked.
        // Unmarked weekdays are not holidays. We treat unmarked as not a holiday, so we stop searching.
        break;
      }
      prevDate = prevDate.subtract(const Duration(days: 1));
    }

    return prevStatus == AttendanceStatus.absent;
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
        payableDays: 0,
        paidHolidays: 0,
        deductedHolidays: 0,
      );
    }

    final records = recordsFor(p.id);

    if (month != null) {
      final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      final perDay = p.monthlySalary / daysInMonth;

      final manualRecords = storage.getAllForProfile(p.id);
      final manualDatesInMonth = manualRecords.keys.where((date) =>
          date.year == month.year && date.month == month.month).toList();

      if (manualDatesInMonth.isEmpty) {
        return AttendanceStats(
          presentDays: 0,
          absentDays: 0,
          halfDays: 0,
          totalMarked: 0,
          percentage: 0,
          earnedSalary: 0,
          estimatedFullSalary: p.monthlySalary,
          deduction: 0,
          payableDays: 0,
          paidHolidays: 0,
          deductedHolidays: 0,
        );
      }

      final endDay = manualDatesInMonth.map((d) => d.day).reduce((a, b) => a > b ? a : b);
      DateTime monthStart = DateTime(month.year, month.month, 1);
      final pStart = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      if (pStart.isAfter(monthStart) && pStart.year == month.year && pStart.month == month.month) {
        monthStart = pStart;
      }

      int present = 0;
      int absent = 0;
      int half = 0;
      double paidHolidays = 0.0;
      double deductedHolidays = 0.0;

      for (int day = monthStart.day; day <= endDay; day++) {
        final date = DateTime(month.year, month.month, day);
        final entry = entryFor(date);
        if (entry == null) {
          continue; // Unmarked weekdays are skipped
        }

        var effectiveStatus = entry.status;
        if (effectiveStatus == AttendanceStatus.holiday) {
          if (p.sandwichLeaveEnabled && isSandwichLeave(p.id, date, records)) {
            effectiveStatus = AttendanceStatus.absent;
          }
        }

        switch (effectiveStatus) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.absent:
            if (entry.status == AttendanceStatus.holiday) {
              deductedHolidays++;
            } else {
              absent++;
            }
            break;
          case AttendanceStatus.halfDay:
            half++;
            break;
          case AttendanceStatus.holiday:
            paidHolidays++;
            break;
        }
      }

      final payableDays = present + half * 0.5 + paidHolidays;
      final earned = perDay * payableDays;
      final deduction = perDay * (absent + half * 0.5 + deductedHolidays);
      final totalConsidered = present + absent + half;
      final percentage = totalConsidered == 0
          ? 0.0
          : ((present + half * 0.5) / totalConsidered) * 100;

      return AttendanceStats(
        presentDays: present,
        absentDays: absent,
        halfDays: half,
        totalMarked: totalConsidered,
        percentage: percentage,
        earnedSalary: earned,
        estimatedFullSalary: p.monthlySalary,
        deduction: deduction,
        payableDays: payableDays,
        paidHolidays: paidHolidays,
        deductedHolidays: deductedHolidays,
      );
    } else {
      // Overall calculation (sum over all months with marked records)
      final manualRecords = storage.getAllForProfile(p.id);
      if (manualRecords.isEmpty) {
        return AttendanceStats(
          presentDays: 0,
          absentDays: 0,
          halfDays: 0,
          totalMarked: 0,
          percentage: 0,
          earnedSalary: 0,
          estimatedFullSalary: 0,
          deduction: 0,
          payableDays: 0,
          paidHolidays: 0,
          deductedHolidays: 0,
        );
      }

      final monthsList = manualRecords.keys
          .map((d) => DateTime(d.year, d.month))
          .toSet()
          .toList();

      int totalPresent = 0;
      int totalAbsent = 0;
      int totalHalf = 0;
      int totalMarked = 0;
      double totalEarned = 0;
      double totalDeduction = 0;
      double totalPayableDays = 0;
      double totalPaidHolidays = 0;
      double totalDeductedHolidays = 0;

      for (final m in monthsList) {
        final mStats = stats(month: m);
        totalPresent += mStats.presentDays;
        totalAbsent += mStats.absentDays;
        totalHalf += mStats.halfDays;
        totalMarked += mStats.totalMarked;
        totalEarned += mStats.earnedSalary;
        totalDeduction += mStats.deduction;
        totalPayableDays += mStats.payableDays;
        totalPaidHolidays += mStats.paidHolidays;
        totalDeductedHolidays += mStats.deductedHolidays;
      }

      final percentage = totalMarked == 0
          ? 0.0
          : ((totalPresent + totalHalf * 0.5) / totalMarked) * 100;

      return AttendanceStats(
        presentDays: totalPresent,
        absentDays: totalAbsent,
        halfDays: totalHalf,
        totalMarked: totalMarked,
        percentage: percentage,
        earnedSalary: totalEarned,
        estimatedFullSalary: p.monthlySalary * monthsList.length,
        deduction: totalDeduction,
        payableDays: totalPayableDays,
        paidHolidays: totalPaidHolidays,
        deductedHolidays: totalDeductedHolidays,
      );
    }
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
