import 'package:hive_flutter/hive_flutter.dart';
import '../models/alarm_model.dart';

/// Manages alarm persistence using Hive.
class AlarmStorageService {
  static const String alarmsBoxName = 'alarms';
  late Box _alarmsBox;

  Future<void> init() async {
    _alarmsBox = await Hive.openBox(alarmsBoxName);
  }

  List<AlarmItem> getAlarms() {
    return _alarmsBox.values
        .map((e) => AlarmItem.fromMap(e as Map))
        .toList()
      ..sort((a, b) {
        // Primary alarms first, then by time
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  Future<void> saveAlarm(AlarmItem alarm) =>
      _alarmsBox.put(alarm.id, alarm.toMap());

  Future<void> deleteAlarm(String id) => _alarmsBox.delete(id);

  AlarmItem? getAlarm(String id) {
    final raw = _alarmsBox.get(id);
    if (raw == null) return null;
    return AlarmItem.fromMap(raw as Map);
  }

  /// Ensure primary alarm exists for a profile. If not, create one.
  AlarmItem ensurePrimaryAlarm({
    required String profileId,
    required String profileName,
    required int hour,
    required int minute,
  }) {
    // Check if primary alarm already exists for this profile
    final alarms = getAlarms();
    final existing = alarms.where(
      (a) => a.type == AlarmType.primary && a.linkedProfileId == profileId,
    );

    if (existing.isNotEmpty) {
      return existing.first;
    }

    // Create primary alarm
    final alarm = AlarmItem(
      id: 'primary_$profileId',
      name: 'Primary Arrival Alarm',
      hour: hour,
      minute: minute,
      isEnabled: true,
      isRepeating: true,
      repeatDays: [1, 2, 3, 4, 5, 6], // Mon-Sat
      type: AlarmType.primary,
      linkedProfileId: profileId,
    );
    _alarmsBox.put(alarm.id, alarm.toMap());
    return alarm;
  }

  /// Update the primary alarm when profile reminder time changes.
  Future<void> syncPrimaryAlarmWithProfile({
    required String profileId,
    required int hour,
    required int minute,
  }) async {
    final alarms = getAlarms();
    for (final alarm in alarms) {
      if (alarm.type == AlarmType.primary && alarm.linkedProfileId == profileId) {
        alarm.hour = hour;
        alarm.minute = minute;
        await saveAlarm(alarm);
        break;
      }
    }
  }
}
