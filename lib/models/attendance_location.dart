class AttendanceLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius; // in meters (10-100)
  final String? startTime;  // Optional "HH:mm", null = not configured
  final String? cutoffTime; // Optional "HH:mm", null = not configured

  AttendanceLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.startTime,
    this.cutoffTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'startTime': startTime,
        'cutoffTime': cutoffTime,
      };

  factory AttendanceLocation.fromMap(Map<dynamic, dynamic> map) =>
      AttendanceLocation(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Workplace',
        address: map['address'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        radius: (map['radius'] as num?)?.toDouble() ?? 50.0,
        // Legacy: old entries had non-null defaults, treat those defaults as "not configured"
        startTime: _parseLegacyTime(map['startTime'] as String?),
        cutoffTime: _parseLegacyTime(map['cutoffTime'] as String?),
      );

  /// Returns null for legacy default times that mean "not configured"
  static String? _parseLegacyTime(String? raw) {
    if (raw == null) return null;
    if (raw == '09:00' || raw == '09:30') return null; // Legacy defaults
    return raw;
  }
}
