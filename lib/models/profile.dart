import 'attendance_location.dart';

/// A profile represents a person whose attendance is tracked.
class Profile {
  final String id;
  String name;
  String role; // e.g. Office / School / College / University / Library / Workplace / Training Center / Other
  String attendanceType; // Same as role, explicit field for wizard flow
  DateTime startDate;
  int reminderHour;
  int reminderMinute;
  double monthlySalary;
  bool salaryTrackingEnabled; // For non-office types that opted in
  bool sandwichLeaveEnabled;
  /// List of public holiday dates in 'yyyy-MM-dd' format.
  List<String> holidays;
  List<AttendanceLocation> locations;

  Profile({
    required this.id,
    required this.name,
    this.role = 'Office',
    String? attendanceType,
    required this.startDate,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.monthlySalary = 0,
    this.salaryTrackingEnabled = false,
    this.sandwichLeaveEnabled = false,
    this.holidays = const [],
    this.locations = const [],
  }) : attendanceType = attendanceType ?? role;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'attendanceType': attendanceType,
        'startDate': startDate.millisecondsSinceEpoch,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'monthlySalary': monthlySalary,
        'salaryTrackingEnabled': salaryTrackingEnabled,
        'sandwichLeaveEnabled': sandwichLeaveEnabled,
        'holidays': holidays,
        'locations': locations.map((e) => e.toMap()).toList(),
      };

  factory Profile.fromMap(Map<dynamic, dynamic> map) => Profile(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Me',
        role: map['role'] as String? ?? 'Office',
        attendanceType: map['attendanceType'] as String? ?? map['role'] as String? ?? 'Office',
        startDate: DateTime.fromMillisecondsSinceEpoch(
            (map['startDate'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
        reminderHour: (map['reminderHour'] as int?) ?? 9,
        reminderMinute: (map['reminderMinute'] as int?) ?? 0,
        monthlySalary: (map['monthlySalary'] as num?)?.toDouble() ?? 0,
        salaryTrackingEnabled: map['salaryTrackingEnabled'] as bool? ?? false,
        sandwichLeaveEnabled: map['sandwichLeaveEnabled'] as bool? ?? false,
        holidays: (map['holidays'] as List?)?.map((e) => e.toString()).toList() ?? [],
        locations: (map['locations'] as List?)
                ?.map((e) => AttendanceLocation.fromMap(e as Map))
                .toList() ??
            [],
      );

  /// Whether salary tracking applies to this profile
  bool get hasSalaryTracking {
    if (attendanceType == 'Office') return true;
    if (attendanceType == 'Other') return salaryTrackingEnabled;
    return salaryTrackingEnabled;
  }
}
