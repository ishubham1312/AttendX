// Run with: dart test/alarm_model_regression.dart (no emulator required).
import '../lib/models/alarm_model.dart';
import '../lib/models/attendance_status.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final legacy = AlarmItem.fromMap({'id': 'primary_a', 'name': 'Arrival'});
  check(
    legacy.alertMode == AlertMode.notification,
    'Legacy alerts migrate to notifications',
  );
  check(legacy.followUpMinutes == 30, 'Default follow-up is 30 minutes');
  final alarm = AlarmItem(
    id: 'alarm_a',
    name: 'Work',
    hour: 22,
    minute: 45,
    alertMode: AlertMode.alarm,
    followUpMinutes: 60,
    repeatDays: [1, 3, 5],
    linkedProfileId: 'a',
  );
  final restored = AlarmItem.fromMap(alarm.toMap());
  check(
    restored.alertMode == AlertMode.alarm && restored.followUpMinutes == 60,
    'Alert settings survive serialization',
  );
  check(
    restored.repeatDays.join(',') == '1,3,5' && restored.linkedProfileId == 'a',
    'Repeat days and profile survive serialization',
  );
  check(
    AlarmItem.notificationId('abc') == 96354,
    'Native identifiers use a deterministic hash',
  );
  check(
    AlarmItem.fromMap({
          ...alarm.toMap(),
          'followUpMinutes': -1,
        }).followUpMinutes ==
        0,
    'Invalid delays are bounded',
  );
  check(
    AlarmItem.fromMap({
          ...alarm.toMap(),
          'followUpMinutes': 999,
        }).followUpMinutes ==
        180,
    'Large delays are bounded',
  );
  check(
    AttendanceEntry.fromStorage('halfDay:first').status ==
        AttendanceStatus.halfDay,
    'Native half-day status is compatible',
  );
  check(
    AttendanceEntry.fromStorage('halfDay:second').half == HalfType.secondHalf,
    'Second half is preserved',
  );
  print('9 alarm and attendance model regression checks passed.');
}
