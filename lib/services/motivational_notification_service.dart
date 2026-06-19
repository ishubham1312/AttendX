import 'package:flutter/foundation.dart';
import '../models/profile.dart';
import '../models/attendance_status.dart';
import 'storage_service.dart';
import 'notification_service.dart';

class MotivationalNotificationService {
  final StorageService storage;
  final NotificationService notifications;

  MotivationalNotificationService(this.storage, this.notifications);

  /// Check all triggers and send at most one notification per call (prioritized)
  /// to avoid notification fatigue.
  Future<void> checkAndTrigger(Profile profile) async {
    final today = DateTime.now();
    final year = today.year;
    final month = today.month;
    final week = _getWeekNumber(today);
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Check overall daily limit: max 1 motivational notification per day
    final lastSentDate = storage.settingsBox.get('last_motivational_sent_date') as String?;
    if (lastSentDate == todayStr) {
      if (kDebugMode) debugPrint("Motivational notification already sent today. Skipping.");
      return;
    }

    final records = _recordsFor(profile.id);
    if (records.isEmpty) return;

    // 1. Check Warning for Excessive Absences (High Priority Warning)
    if (_checkWeeklyAbsenceWarning(profile, records, today, year, week)) return;

    // 2. Check Repeated Late Arrivals Warning (High Priority Warning)
    if (_checkLateArrivalWarning(profile, records, today, todayStr)) return;

    // 3. Reached Salary Milestones (earnings 25%, 50%, 75%, 100%)
    if (_checkSalaryMilestones(profile, records, today, year, month)) return;

    // 4. Streak Milestones (consecutive Present days)
    if (_checkStreakMilestones(profile, records, today, todayStr)) return;

    // 5. Positive Encouragement / Recovery
    if (_checkRecoveryEncouragement(profile, records, today, year, week)) return;

    // 6. Improved Attendance compared to previous week
    if (_checkWeeklyImprovement(profile, records, today, year, week)) return;

    // 7. 100% Weekly Attendance Achievement
    if (_checkWeekly100Attendance(profile, records, today, year, week)) return;

    // 8. 100% Monthly Attendance Achievement
    if (_checkMonthly100Attendance(profile, records, today, year, month)) return;

    // 9. Punctuality (Consistent on-time arrivals)
    if (_checkPunctualityAchievement(profile, records, today, todayStr)) return;
  }

  Map<DateTime, AttendanceEntry> _recordsFor(String profileId) {
    final raw = storage.getAllForProfile(profileId);
    return raw.map((k, v) => MapEntry(k, AttendanceEntry.fromStorage(v)));
  }

  // Helper to send and track a notification
  void _sendNotification(int id, String title, String body, String key, {dynamic valueToSave = true}) {
    notifications.showNotification(
      id: id,
      title: title,
      body: body,
      payload: storage.activeProfileId,
    );
    storage.settingsBox.put(key, valueToSave);
    
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    storage.settingsBox.put('last_motivational_sent_date', todayStr);
    
    if (kDebugMode) {
      debugPrint("Sent motivational notification: $title - $body (key: $key)");
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return ((dayOfYear - (date.weekday - 1)) / 7).ceil();
  }

  // ---- Triggers ----

  bool _checkWeeklyAbsenceWarning(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, int year, int week) {
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    int absencesThisWeek = 0;
    for (final date in records.keys) {
      if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
        if (records[date]?.status == AttendanceStatus.absent) {
          absencesThisWeek++;
        }
      }
    }

    if (absencesThisWeek >= 2) {
      final key = 'motivational_${profile.id}_absent_warning_${year}_w$week';
      if (storage.settingsBox.get(key, defaultValue: false) == false) {
        _sendNotification(
          91001,
          "⚠️ Maintain Consistency",
          "You've been absent frequently this week. Try maintaining consistency.",
          key,
        );
        return true;
      }
    }
    return false;
  }

  bool _checkLateArrivalWarning(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, String todayStr) {
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    int lateArrivals = 0;
    
    for (final date in records.keys) {
      if (date.isAfter(sevenDaysAgo)) {
        final meta = storage.getAttendanceMetadata(profile.id, date);
        if (meta != null && meta['status'] == 'Late') {
          lateArrivals++;
        }
      }
    }

    if (lateArrivals >= 3) {
      final key = 'motivational_${profile.id}_late_warning';
      final lastSentStr = storage.settingsBox.get(key) as String?;
      bool shouldSend = true;
      if (lastSentStr != null) {
        final lastSent = DateTime.tryParse(lastSentStr);
        if (lastSent != null && today.difference(lastSent).inDays < 7) {
          shouldSend = false;
        }
      }
      
      if (shouldSend) {
        _sendNotification(
          91002,
          "⚠️ Repeated Late Arrivals",
          "You've had repeated late arrivals recently. Try arriving a bit earlier.",
          key,
          valueToSave: todayStr,
        );
        return true;
      }
    }
    return false;
  }

  bool _isSandwichLeave(String profileId, DateTime date, Map<DateTime, AttendanceEntry> records) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
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
        break;
      }
      prevDate = prevDate.subtract(const Duration(days: 1));
    }
    return prevStatus == AttendanceStatus.absent;
  }

  bool _checkSalaryMilestones(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, int year, int month) {
    if (!profile.hasSalaryTracking || profile.monthlySalary <= 0) return false;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final perDay = profile.monthlySalary / daysInMonth;

    final Map<DateTime, AttendanceEntry> fullRecords = Map.from(records);
    final start = DateTime(profile.startDate.year, profile.startDate.month, profile.startDate.day);
    final end = DateTime.now().add(const Duration(days: 365));
    var d = start;
    while (!d.isAfter(end)) {
      final dateKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (d.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
        final normalized = DateTime(d.year, d.month, d.day);
        if (!fullRecords.containsKey(normalized)) {
          fullRecords[normalized] = AttendanceEntry(AttendanceStatus.holiday, null);
        }
      }
      d = d.add(const Duration(days: 1));
    }

    double payableDays = 0;
    DateTime monthStart = DateTime(year, month, 1);
    final pStart = DateTime(profile.startDate.year, profile.startDate.month, profile.startDate.day);
    if (pStart.isAfter(monthStart) && pStart.year == year && pStart.month == month) {
      monthStart = pStart;
    }

    for (int day = monthStart.day; day <= today.day; day++) {
      final date = DateTime(year, month, day);
      final entry = fullRecords[date];
      if (entry != null) {
        var effectiveStatus = entry.status;
        if (effectiveStatus == AttendanceStatus.holiday) {
          if (profile.sandwichLeaveEnabled && _isSandwichLeave(profile.id, date, fullRecords)) {
            effectiveStatus = AttendanceStatus.absent;
          }
        }
        if (effectiveStatus == AttendanceStatus.present) {
          payableDays += 1.0;
        } else if (effectiveStatus == AttendanceStatus.halfDay) {
          payableDays += 0.5;
        } else if (effectiveStatus == AttendanceStatus.holiday) {
          payableDays += 1.0;
        }
      }
    }

    final earned = perDay * payableDays;
    final ratio = earned / profile.monthlySalary;

    final milestones = [0.25, 0.50, 0.75, 1.00];
    final labels = ["25%", "50%", "75%", "100%"];

    for (int i = milestones.length - 1; i >= 0; i--) {
      if (ratio >= milestones[i]) {
        final key = 'motivational_${profile.id}_salary_${labels[i]}_${year}_m$month';
        if (storage.settingsBox.get(key, defaultValue: false) == false) {
          _sendNotification(
            91100 + i,
            "💰 Estimated Salary Milestone Reached!",
            "Great work! You've earned ${labels[i]} of your estimated monthly salary.",
            key,
          );
          return true;
        }
      }
    }
    return false;
  }

  bool _checkStreakMilestones(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, String todayStr) {
    final streak = _calculateCurrentStreak(profile, records);
    final milestones = [5, 10, 15, 30, 50, 100];
    
    if (milestones.contains(streak)) {
      final key = 'motivational_${profile.id}_streak_${streak}_milestone';
      final lastTriggeredDate = storage.settingsBox.get(key) as String?;
      if (lastTriggeredDate != todayStr) {
        _sendNotification(
          91200 + streak,
          "🔥 Attendance Streak!",
          "You're on a $streak-day attendance streak.",
          key,
          valueToSave: todayStr,
        );
        return true;
      }
    }
    return false;
  }

  int _calculateCurrentStreak(Profile profile, Map<DateTime, AttendanceEntry> records) {
    int streak = 0;
    final today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    if (records[checkDate] == null) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final dateKey = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      if (checkDate.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      final entry = records[checkDate];
      if (entry != null && entry.status == AttendanceStatus.present) {
        streak++;
      } else {
        break;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (today.difference(checkDate).inDays > 365) break;
    }
    return streak;
  }

  bool _checkRecoveryEncouragement(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, int year, int week) {
    if (today.weekday < DateTime.wednesday) return false;

    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));

    int absencesLastWeek = 0;
    for (final date in records.keys) {
      if (date.isAfter(startOfLastWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfLastWeek.add(const Duration(seconds: 1)))) {
        if (records[date]?.status == AttendanceStatus.absent) {
          absencesLastWeek++;
        }
      }
    }

    if (absencesLastWeek < 2) return false;

    int presentThisWeek = 0;
    int absentThisWeek = 0;
    for (final date in records.keys) {
      if (date.isAfter(startOfThisWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(today.add(const Duration(seconds: 1)))) {
        final status = records[date]?.status;
        if (status == AttendanceStatus.present) {
          presentThisWeek++;
        } else if (status == AttendanceStatus.absent || status == AttendanceStatus.halfDay) {
          absentThisWeek++;
        }
      }
    }

    if (presentThisWeek >= 3 && absentThisWeek == 0) {
      final key = 'motivational_${profile.id}_recovery_${year}_w$week';
      if (storage.settingsBox.get(key, defaultValue: false) == false) {
        _sendNotification(
          91005,
          "✨ Great Recovery!",
          "Great recovery! Keep up the good work this week.",
          key,
        );
        return true;
      }
    }
    return false;
  }

  bool _checkWeeklyImprovement(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, int year, int week) {
    if (today.weekday < DateTime.friday) return false;

    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));

    int presentLast = 0;
    int totalLast = 0;
    for (final date in records.keys) {
      if (date.isAfter(startOfLastWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfLastWeek.add(const Duration(seconds: 1)))) {
        final status = records[date]?.status;
        if (status == AttendanceStatus.present) {
          presentLast++;
          totalLast++;
        } else if (status == AttendanceStatus.absent) {
          totalLast++;
        } else if (status == AttendanceStatus.halfDay) {
          presentLast += 1;
          totalLast++;
        }
      }
    }

    if (totalLast == 0) return false;
    final lastWeekPct = (presentLast / totalLast) * 100;

    int presentThis = 0;
    int totalThis = 0;
    for (final date in records.keys) {
      if (date.isAfter(startOfThisWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(today.add(const Duration(seconds: 1)))) {
        final status = records[date]?.status;
        if (status == AttendanceStatus.present) {
          presentThis++;
          totalThis++;
        } else if (status == AttendanceStatus.absent) {
          totalThis++;
        } else if (status == AttendanceStatus.halfDay) {
          presentThis += 1;
          totalThis++;
        }
      }
    }

    if (totalThis < 3) return false;
    final thisWeekPct = (presentThis / totalThis) * 100;

    final improvement = thisWeekPct - lastWeekPct;
    if (improvement >= 15.0) {
      final key = 'motivational_${profile.id}_weekly_improvement_${year}_w$week';
      if (storage.settingsBox.get(key, defaultValue: false) == false) {
        _sendNotification(
          91006,
          "📈 Attendance Improved!",
          "Your attendance improved by ${improvement.toStringAsFixed(0)}% compared to last week.",
          key,
        );
        return true;
      }
    }
    return false;
  }

  bool _checkWeekly100Attendance(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, int year, int week) {
    if (today.weekday < DateTime.friday) return false;

    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    
    int presentDays = 0;
    int otherDays = 0;

    for (int i = 0; i < today.weekday; i++) {
      final date = startOfThisWeek.add(Duration(days: i));
      final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      if (date.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
        continue;
      }

      final entry = records[date];
      if (entry != null && entry.status == AttendanceStatus.present) {
        presentDays++;
      } else {
        otherDays++;
      }
    }

    if (presentDays >= 4 && otherDays == 0) {
      final key = 'motivational_${profile.id}_weekly_100_${year}_w$week';
      if (storage.settingsBox.get(key, defaultValue: false) == false) {
        _sendNotification(
          91007,
          "🎉 100% Attendance!",
          "Congratulations! You've achieved 100% attendance this week.",
          key,
        );
        return true;
      }
    }
    return false;
  }

  bool _checkMonthly100Attendance(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, int year, int month) {
    if (today.day < 25) return false;

    int presentDays = 0;
    int otherDays = 0;

    for (int d = 1; d <= today.day; d++) {
      final date = DateTime(year, month, d);
      final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      if (date.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
        continue;
      }

      final entry = records[date];
      if (entry != null && entry.status == AttendanceStatus.present) {
        presentDays++;
      } else {
        otherDays++;
      }
    }

    if (presentDays >= 15 && otherDays == 0) {
      final key = 'motivational_${profile.id}_monthly_100_${year}_m$month';
      if (storage.settingsBox.get(key, defaultValue: false) == false) {
        _sendNotification(
          91008,
          "🏆 Perfect Month!",
          "Congratulations! You've achieved 100% attendance this month.",
          key,
        );
        return true;
      }
    }
    return false;
  }

  bool _checkPunctualityAchievement(Profile profile, Map<DateTime, AttendanceEntry> records, DateTime today, String todayStr) {
    int checkCount = 0;
    int lateOrAbsentCount = 0;
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    while (checkCount < 5) {
      final dateKey = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      if (checkDate.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      final entry = records[checkDate];
      if (entry == null) {
        break;
      }

      if (entry.status != AttendanceStatus.present) {
        lateOrAbsentCount++;
      } else {
        final meta = storage.getAttendanceMetadata(profile.id, checkDate);
        if (meta != null && meta['status'] == 'Late') {
          lateOrAbsentCount++;
        }
      }

      checkCount++;
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (today.difference(checkDate).inDays > 30) break;
    }

    if (checkCount == 5 && lateOrAbsentCount == 0) {
      final key = 'motivational_${profile.id}_punctuality';
      final lastSentStr = storage.settingsBox.get(key) as String?;
      bool shouldSend = true;
      if (lastSentStr != null) {
        final lastSent = DateTime.tryParse(lastSentStr);
        if (lastSent != null && today.difference(lastSent).inDays < 7) {
          shouldSend = false;
        }
      }

      if (shouldSend) {
        _sendNotification(
          91009,
          "⏱️ Punctuality Champ!",
          "Consistent on-time arrivals! Keep up the punctual work.",
          key,
          valueToSave: todayStr,
        );
        return true;
      }
    }
    return false;
  }
}
