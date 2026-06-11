/// Represents an alarm configured in the application.
class AlarmItem {
  final String id;
  String name;
  int hour;
  int minute;
  bool isEnabled;
  bool isRepeating;
  List<int> repeatDays; // 1=Mon, 2=Tue, ... 7=Sun
  final AlarmType type;
  String? linkedProfileId;

  AlarmItem({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    this.isRepeating = true,
    this.repeatDays = const [1, 2, 3, 4, 5, 6], // Mon-Sat by default
    this.type = AlarmType.custom,
    this.linkedProfileId,
  });

  bool get isPrimary => type == AlarmType.primary;

  String get timeString {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String get repeatLabel {
    if (!isRepeating) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 6 && !repeatDays.contains(7)) return 'Mon - Sat';
    if (repeatDays.length == 5 && !repeatDays.contains(6) && !repeatDays.contains(7)) {
      return 'Weekdays';
    }
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatDays.map((d) => dayNames[d]).join(', ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'isEnabled': isEnabled,
        'isRepeating': isRepeating,
        'repeatDays': repeatDays,
        'type': type.name,
        'linkedProfileId': linkedProfileId,
      };

  factory AlarmItem.fromMap(Map<dynamic, dynamic> map) => AlarmItem(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Alarm',
        hour: (map['hour'] as int?) ?? 9,
        minute: (map['minute'] as int?) ?? 0,
        isEnabled: map['isEnabled'] as bool? ?? true,
        isRepeating: map['isRepeating'] as bool? ?? true,
        repeatDays: (map['repeatDays'] as List?)?.map((e) => e as int).toList() ??
            [1, 2, 3, 4, 5, 6],
        type: AlarmType.values.firstWhere(
          (e) => e.name == (map['type'] as String? ?? 'custom'),
          orElse: () => AlarmType.custom,
        ),
        linkedProfileId: map['linkedProfileId'] as String?,
      );
}

enum AlarmType {
  primary,
  custom,
}
