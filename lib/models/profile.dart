/// A profile represents a person whose attendance is tracked.
/// Stored as a Map in Hive for simplicity (no codegen required).
class Profile {
  final String id;
  String name;
  String role; // e.g. School / College / Office
  DateTime startDate;
  int reminderHour;
  int reminderMinute;
  double monthlySalary;
  bool sandwichLeaveEnabled;
  /// List of public holiday dates in 'yyyy-MM-dd' format.
  List<String> holidays;

  Profile({
    required this.id,
    required this.name,
    this.role = 'Office',
    required this.startDate,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.monthlySalary = 0,
    this.sandwichLeaveEnabled = false,
    this.holidays = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'startDate': startDate.millisecondsSinceEpoch,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'monthlySalary': monthlySalary,
        'sandwichLeaveEnabled': sandwichLeaveEnabled,
        'holidays': holidays,
      };

  factory Profile.fromMap(Map<dynamic, dynamic> map) => Profile(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Me',
        role: map['role'] as String? ?? 'Office',
        startDate: DateTime.fromMillisecondsSinceEpoch(
            (map['startDate'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
        reminderHour: (map['reminderHour'] as int?) ?? 9,
        reminderMinute: (map['reminderMinute'] as int?) ?? 0,
        monthlySalary: (map['monthlySalary'] as num?)?.toDouble() ?? 0,
        sandwichLeaveEnabled: map['sandwichLeaveEnabled'] as bool? ?? false,
        holidays: (map['holidays'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}
