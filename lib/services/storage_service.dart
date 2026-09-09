import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/profile.dart';

/// Handles all persistence using Hive.
/// - profilesBox: stores profile maps keyed by profile id.
/// - attendanceBox: stores attendance keyed by `profileId|yyyy-mm-dd` to status key.
/// - settingsBox: misc app settings (onboardingDone, activeProfileId).
class StorageService {
  static const nativeChannel = MethodChannel(
    'com.attendancetracker.attend/alarm',
  );
  static bool get supportsNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> importNativeAttendance() async {
    if (!supportsNative) return;
    final pending =
        await nativeChannel.invokeMapMethod<String, String>(
          'pendingAttendance',
        ) ??
        {};
    final ids = getProfiles().map((p) => p.id).toSet();
    for (final entry in pending.entries) {
      final key = entry.key.replaceFirst('pending_', '');
      if (ids.contains(key.split('|').first))
        await _attendanceBox.put(key, entry.value);
    }
    await nativeChannel.invokeMethod('ackAttendance', {'values': pending});
  }

  Future<void> syncNativeState() async {
    if (!supportsNative) return;
    await nativeChannel.invokeMethod('syncAttendance', {
      'active':
          activeProfileId ??
          (getProfiles().isEmpty ? '' : getProfiles().first.id),
      'profiles': jsonEncode(
        getProfiles()
            .map(
              (p) => {
                ...p.toMap(),
                'startDate': p.startDate.toIso8601String().substring(0, 10),
                'records': getAllForProfile(p.id).map(
                  (date, raw) =>
                      MapEntry(_key(p.id, date).split('|').last, raw),
                ),
              },
            )
            .toList(),
      ),
    });
  }

  Future<void> _publishAttendance(
    String profileId,
    DateTime date,
    String? raw,
  ) async {
    if (!supportsNative) return;
    await nativeChannel.invokeMethod('setAttendance', {
      'profileId': profileId,
      'date': _key(profileId, date).split('|').last,
      'raw': raw,
    });
  }

  static const String profilesBoxName = 'profiles';
  static const String attendanceBoxName = 'attendance';
  static const String metadataBoxName = 'attendance_metadata';
  static const String settingsBoxName = 'settings';

  late Box _profilesBox;
  late Box _attendanceBox;
  late Box _metadataBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _profilesBox = await Hive.openBox(profilesBoxName);
    _attendanceBox = await Hive.openBox(attendanceBoxName);
    _metadataBox = await Hive.openBox(metadataBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
  }

  Box get settingsBox => _settingsBox;

  // ---- Settings ----
  bool get onboardingDone =>
      _settingsBox.get('onboardingDone', defaultValue: false) as bool;
  Future<void> setOnboardingDone(bool v) =>
      _settingsBox.put('onboardingDone', v);

  String? get activeProfileId => _settingsBox.get('activeProfileId') as String?;
  Future<void> setActiveProfileId(String id) =>
      _settingsBox.put('activeProfileId', id);

  // ---- Profiles ----
  List<Profile> getProfiles() {
    return _profilesBox.values.map((e) => Profile.fromMap(e as Map)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> saveProfile(Profile p) => _profilesBox.put(p.id, p.toMap());

  Future<void> deleteProfile(String id) async {
    await _profilesBox.delete(id);
    // remove attendance records for this profile
    final keysToRemove = _attendanceBox.keys
        .where((k) => k.toString().startsWith('$id|'))
        .toList();
    await _attendanceBox.deleteAll(keysToRemove);
    final metadataKeysToRemove = _metadataBox.keys
        .where((k) => k.toString().startsWith('$id|'))
        .toList();
    await _metadataBox.deleteAll(metadataKeysToRemove);
  }

  // ---- Attendance ----
  String _key(String profileId, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '$profileId|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String? getStatusRaw(String profileId, DateTime date) {
    return _attendanceBox.get(_key(profileId, date)) as String?;
  }

  Future<void> setStatusRaw(String profileId, DateTime date, String raw) async {
    await _attendanceBox.put(_key(profileId, date), raw);
    await _publishAttendance(profileId, date, raw);
  }

  Future<void> clearStatus(String profileId, DateTime date) async {
    await _attendanceBox.delete(_key(profileId, date));
    await _publishAttendance(profileId, date, null);
  }

  // ---- Attendance Metadata ----
  Map<String, dynamic>? getAttendanceMetadata(String profileId, DateTime date) {
    final raw = _metadataBox.get(_key(profileId, date));
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> setAttendanceMetadata(
    String profileId,
    DateTime date,
    Map<String, dynamic> metadata,
  ) {
    return _metadataBox.put(_key(profileId, date), metadata);
  }

  Future<void> clearAttendanceMetadata(String profileId, DateTime date) {
    return _metadataBox.delete(_key(profileId, date));
  }

  /// Returns map of date -> raw storage string for a profile.
  Map<DateTime, String> getAllForProfile(String profileId) {
    final result = <DateTime, String>{};
    for (final k in _attendanceBox.keys) {
      final ks = k.toString();
      if (ks.startsWith('$profileId|')) {
        final datePart = ks.split('|')[1];
        final parts = datePart.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        result[date] = _attendanceBox.get(k) as String;
      }
    }
    return result;
  }
}
