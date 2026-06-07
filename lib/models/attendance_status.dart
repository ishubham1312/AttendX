/// Attendance status for a given day.
enum AttendanceStatus {
  present,
  absent,
  halfDay,
  holiday,
}

/// Which half of the day for a half-day mark.
enum HalfType {
  firstHalf,
  secondHalf,
}

extension HalfTypeX on HalfType {
  String get label =>
      this == HalfType.firstHalf ? 'First Half' : 'Second Half';

  String get key => this == HalfType.firstHalf ? 'first' : 'second';

  static HalfType fromKey(String? key) =>
      key == 'second' ? HalfType.secondHalf : HalfType.firstHalf;
}

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.holiday:
        return 'Holiday';
    }
  }

  /// Weight used for salary / percentage calculations.
  double get weight {
    switch (this) {
      case AttendanceStatus.present:
        return 1.0;
      case AttendanceStatus.absent:
        return 0.0;
      case AttendanceStatus.halfDay:
        return 0.5;
      case AttendanceStatus.holiday:
        return 1.0;
    }
  }

  String get key {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.halfDay:
        return 'halfDay';
      case AttendanceStatus.holiday:
        return 'holiday';
    }
  }

  static AttendanceStatus fromKey(String key) {
    // Stored values may be like "halfDay:first" - split off the base part.
    final base = key.split(':').first;
    switch (base) {
      case 'absent':
        return AttendanceStatus.absent;
      case 'halfDay':
        return AttendanceStatus.halfDay;
      case 'holiday':
        return AttendanceStatus.holiday;
      default:
        return AttendanceStatus.present;
    }
  }
}

/// Combined attendance entry: a status plus an optional half type.
class AttendanceEntry {
  final AttendanceStatus status;
  final HalfType? half; // only meaningful when status == halfDay

  const AttendanceEntry(this.status, [this.half]);

  /// Serialize to a single string for storage.
  /// Examples: "present", "absent", "halfDay:first", "halfDay:second".
  String toStorage() {
    if (status == AttendanceStatus.halfDay) {
      return 'halfDay:${(half ?? HalfType.firstHalf).key}';
    }
    return status.key;
  }

  factory AttendanceEntry.fromStorage(String raw) {
    final parts = raw.split(':');
    final status = AttendanceStatusX.fromKey(parts[0]);
    if (status == AttendanceStatus.halfDay) {
      return AttendanceEntry(
          status, HalfTypeX.fromKey(parts.length > 1 ? parts[1] : 'first'));
    }
    return AttendanceEntry(status);
  }

  String get displayLabel {
    if (status == AttendanceStatus.halfDay) {
      return 'Half Day · ${(half ?? HalfType.firstHalf).label}';
    }
    return status.label;
  }
}
