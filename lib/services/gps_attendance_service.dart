import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/profile.dart';
import '../models/attendance_status.dart';
import '../models/attendance_location.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'motivational_notification_service.dart';

class GPSAttendanceService extends ChangeNotifier {
  final StorageService storage;
  final NotificationService notifications;

  GPSAttendanceService(this.storage, this.notifications);

  bool _isTracking = false;
  Position? _currentPosition;
  bool _isInside = false;
  double _distanceToWorkplace = -1; // in meters
  String _gpsStatus = 'Unknown'; // 'Disabled', 'PermissionMissing', 'BackgroundMissing', 'Active'
  
  // Anti-fraud and status logs
  final List<String> _fraudLogs = [];
  Position? _lastCheckedPosition;
  DateTime? _lastCheckedTime;

  // Simulation parameters for Web/Testing
  bool _simulationMode = false;
  double _simulatedLat = 25.3176;
  double _simulatedLng = 82.9739;
  double _simulatedAccuracy = 15.0;
  bool _simulatedIsMocked = false;

  // Reminders and deadline timers
  Timer? _pollingTimer;
  Timer? _deadlineTimer;
  StreamSubscription<Position>? _positionStreamSub;
  String? _activeProfileId;
  DateTime? _lastFailureNotificationTime;

  // Getters
  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;
  bool get isInside => _isInside;
  double get distanceToWorkplace => _distanceToWorkplace;
  String get gpsStatus => _gpsStatus;
  List<String> get fraudLogs => _fraudLogs;

  bool get simulationMode => _simulationMode;
  double get simulatedLat => _simulatedLat;
  double get simulatedLng => _simulatedLng;
  double get simulatedAccuracy => _simulatedAccuracy;
  bool get simulatedIsMocked => _simulatedIsMocked;

  void setSimulationMode(bool value) {
    _simulationMode = value;
    _checkLocation();
    notifyListeners();
  }

  void updateSimulatedLocation(double lat, double lng, {double accuracy = 15.0, bool isMocked = false}) {
    _simulatedLat = lat;
    _simulatedLng = lng;
    _simulatedAccuracy = accuracy;
    _simulatedIsMocked = isMocked;
    if (_simulationMode) {
      _checkLocation();
    }
    notifyListeners();
  }

  /// Initialize and start tracking if we have an active profile and are inside window
  Future<void> init(String profileId) async {
    _activeProfileId = profileId;
    await checkPermissions();
    updateTrackingState();
    _startDeadlineChecks();
  }

  /// Checks if current time falls within any configured attendance window.
  bool isInsideAnyAttendanceWindow() {
    if (_activeProfileId == null) return false;
    final profiles = storage.getProfiles();
    final profileIndex = profiles.indexWhere((p) => p.id == _activeProfileId);
    if (profileIndex == -1) return false;
    final profile = profiles[profileIndex];
    if (profile.locations.isEmpty) return false;

    final today = DateTime.now();
    final dateKey = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    if (today.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
      return false;
    }

    final dateKeyDate = DateTime(today.year, today.month, today.day);
    final existingRaw = storage.getStatusRaw(profile.id, dateKeyDate);
    if (existingRaw != null && existingRaw.startsWith('present')) {
      return false; // Present is already marked, stop tracking
    }

    for (final loc in profile.locations) {
      final start = _parseTime(loc.startTime);
      final cutoff = _parseTime(loc.cutoffTime);
      if (start == null || cutoff == null) continue;

      final nowTime = TimeOfDay.fromDateTime(today);
      final nowMinutes = nowTime.hour * 60 + nowTime.minute;
      final startMinutes = start.hour * 60 + start.minute;
      final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;

      if (nowMinutes >= startMinutes && nowMinutes <= cutoffMinutes) {
        return true;
      }
    }
    return false;
  }

  /// Start or stop tracking depending on the active profile's attendance window.
  void updateTrackingState() {
    if (_activeProfileId == null) {
      if (_isTracking) stopTracking();
      return;
    }

    final profiles = storage.getProfiles();
    final profileIndex = profiles.indexWhere((p) => p.id == _activeProfileId);
    if (profileIndex == -1) {
      if (_isTracking) stopTracking();
      return;
    }
    final profile = profiles[profileIndex];
    if (profile.locations.isEmpty) {
      if (_isTracking) stopTracking();
      return;
    }

    final today = DateTime.now();
    final dateKey = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    if (today.weekday == DateTime.sunday || profile.holidays.contains(dateKey)) {
      if (_isTracking) stopTracking();
      return;
    }

    final dateKeyDate = DateTime(today.year, today.month, today.day);
    final existingRaw = storage.getStatusRaw(profile.id, dateKeyDate);

    // After Present is marked: Stop attendance reminders for that day. No further attendance notifications should be sent.
    // Also, if already marked Present, we don't need to track anymore today.
    if (existingRaw != null && existingRaw.startsWith('present')) {
      if (_isTracking) stopTracking();
      return;
    }

    // Check if current time is within any location's attendance window
    bool inWindow = false;
    for (final loc in profile.locations) {
      final start = _parseTime(loc.startTime);
      final cutoff = _parseTime(loc.cutoffTime);
      if (start == null || cutoff == null) continue;

      final nowTime = TimeOfDay.fromDateTime(today);
      final nowMinutes = nowTime.hour * 60 + nowTime.minute;
      final startMinutes = start.hour * 60 + start.minute;
      final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;

      if (nowMinutes >= startMinutes && nowMinutes <= cutoffMinutes) {
        inWindow = true;
        break;
      }
    }

    if (inWindow) {
      if (!_isTracking) {
        startTracking();
      }
    } else {
      if (_isTracking) {
        stopTracking();
      }
    }
  }

  /// Check permission and service status
  Future<void> checkPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _gpsStatus = 'Disabled';
      _isInside = false;
      _distanceToWorkplace = -1;
      notifyListeners();
      _sendLocationDisabledNotification();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      _gpsStatus = 'PermissionMissing';
      notifyListeners();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _gpsStatus = 'PermissionMissing';
      notifyListeners();
      return;
    }

    // Check background location permission for Android/iOS if needed
    if (!kIsWeb) {
      if (permission == LocationPermission.whileInUse) {
        // We can still function but background location permission is missing
        _gpsStatus = 'BackgroundMissing';
        notifyListeners();
        return;
      }
    }

    _gpsStatus = 'Active';
    notifyListeners();
  }

  /// Request permissions, including background location if supported
  Future<bool> requestLocationPermission() async {
    // Ensure location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();

    // Request while-in-use permission if not granted
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _gpsStatus = 'PermissionMissing';
        notifyListeners();
        return false;
      }
    }

    // If denied forever, cannot request
    if (permission == LocationPermission.deniedForever) {
      _gpsStatus = 'PermissionMissing';
      notifyListeners();
      return false;
    }

    // At this point we have whileInUse or always.
    if (permission == LocationPermission.whileInUse) {
      // Attempt to request always (background) permission
      final bgPermission = await Geolocator.requestPermission();
      if (bgPermission == LocationPermission.always) {
        permission = bgPermission;
      }
    }

    // Set status based on final permission
    if (permission == LocationPermission.always) {
      _gpsStatus = 'Active';
    } else if (permission == LocationPermission.whileInUse) {
      _gpsStatus = 'BackgroundMissing';
    }
    notifyListeners();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Start background/foreground tracking
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;

    if (kIsWeb) {
      // Web fallback: use periodic polling timer
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkLocation());
    } else {
      // Mobile: listen to position stream with foreground notification config
      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: Duration(seconds: 10),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationText: "AttendX is running background geofence verification.",
          notificationTitle: "Automatic Attendance Active",
          enableWakeLock: true,
        ),
      );

      _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen(
            (Position pos) {
              if (!_simulationMode) {
                _processPosition(pos);
              }
            },
            onError: (err) {
              debugPrint("Geolocator stream error: $err");
              _gpsStatus = 'Disabled';
              notifyListeners();
            },
          );
      
      // Also start periodic timer to verify in background/web fallback
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkLocation());
    }
    _checkLocation();
    notifyListeners();
  }

  /// Stop tracking
  void stopTracking() {
    _isTracking = false;
    _pollingTimer?.cancel();
    _positionStreamSub?.cancel();
    notifyListeners();
  }

  /// Force a location check
  Future<void> _checkLocation() async {
    if (!isInsideAnyAttendanceWindow() && !_simulationMode) {
      return;
    }
    if (_simulationMode) {
      // Create simulated position
      final mockPos = Position(
        latitude: _simulatedLat,
        longitude: _simulatedLng,
        timestamp: DateTime.now(),
        accuracy: _simulatedAccuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: _simulatedIsMocked,
      );
      _processPosition(mockPos);
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsStatus = 'Disabled';
        notifyListeners();
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _gpsStatus = 'PermissionMissing';
        notifyListeners();
        return;
      }

      _gpsStatus = permission == LocationPermission.whileInUse ? 'BackgroundMissing' : 'Active';

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _processPosition(pos);
    } catch (e) {
      debugPrint("Error checking location: $e");
    }
  }

  /// Process the updated position
  void _processPosition(Position position) {
    _currentPosition = position;
    
    // Find active profile
    if (_activeProfileId == null) return;
    final profile = storage.getProfiles().firstWhere((p) => p.id == _activeProfileId);
    
    if (profile.locations.isEmpty) {
      _isInside = false;
      _distanceToWorkplace = -1;
      notifyListeners();
      return;
    }

    // Find the closest geofenced location
    double minDistance = double.infinity;
    AttendanceLocation? closestLocation;

    for (final loc in profile.locations) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        loc.latitude,
        loc.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestLocation = loc;
      }
    }

    if (closestLocation == null) return;

    _distanceToWorkplace = minDistance;
    final wasInside = _isInside;
    _isInside = minDistance <= closestLocation.radius;

    // Check transition entry/exit alerts
    if (_isInside && !wasInside) {
      _sendNotification(90001, "📍 Location Entered", "Welcome! You have entered your attendance area: ${closestLocation.name}.");
    } else if (!_isInside && wasInside) {
      _sendNotification(90002, "📍 Location Exited", "You have left your attendance area: ${closestLocation.name}.");
    }

    notifyListeners();

    // Check if we need to auto-mark attendance
    if (_isInside) {
      _attemptAutoMark(profile, closestLocation, position);
    }
  }

  /// Try to mark attendance automatically
  void _attemptAutoMark(Profile profile, AttendanceLocation location, Position position) async {
    final today = DateTime.now();
    final dateKey = DateTime(today.year, today.month, today.day);

    // 1. Check if already marked today
    final existingRaw = storage.getStatusRaw(profile.id, dateKey);
    final existingMetadata = storage.getAttendanceMetadata(profile.id, dateKey);

    if (existingRaw == null) {
      // First arrival of the day!
      final start = _parseTime(location.startTime);
      final cutoff = _parseTime(location.cutoffTime);

      final nowTime = TimeOfDay.fromDateTime(today);
      final nowMinutes = nowTime.hour * 60 + nowTime.minute;

      if (start != null) {
        final startMinutes = start.hour * 60 + start.minute;
        if (nowMinutes < startMinutes) {
          // Too early, don't mark yet
          return;
        }
      }

      bool isLate = false;
      String? delayStr;
      if (cutoff != null) {
        final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;
        if (nowMinutes > cutoffMinutes) {
          isLate = true;
          final delay = nowMinutes - cutoffMinutes;
          delayStr = "$delay minutes";
        }
      }

      // Anti-Fraud Measures
      _fraudLogs.clear();

      // A. GPS Accuracy Check
      const minAccuracyThreshold = 50.0; // max allowed 50 meters inaccuracy
      if (position.accuracy > minAccuracyThreshold) {
        _fraudLogs.add("Accuracy validation failed: ${position.accuracy.toStringAsFixed(1)}m (limit is ${minAccuracyThreshold}m)");
      }

      // B. Mock Location Check
      if (!_simulationMode && position.isMocked) {
        _fraudLogs.add("Mock location detected via provider flags.");
      }

      // C. Sudden location jumps
      if (_lastCheckedPosition != null && _lastCheckedTime != null) {
        final dist = Geolocator.distanceBetween(
          _lastCheckedPosition!.latitude,
          _lastCheckedPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        final timeDiffSec = today.difference(_lastCheckedTime!).inSeconds;
        if (timeDiffSec > 0) {
          final speedKmh = (dist / timeDiffSec) * 3.6;
          if (speedKmh > 300 && dist > 500) {
            _fraudLogs.add("Sudden location jump detected: ${speedKmh.toStringAsFixed(1)} km/h.");
          }
        }
      }

      _lastCheckedPosition = position;
      _lastCheckedTime = today;

      // If fraud logs contain errors, do not mark, log it and notify listeners
      if (_fraudLogs.isNotEmpty) {
        debugPrint("Anti-Fraud validation failed: ${_fraudLogs.join(', ')}");
        return;
      }

      // Mark attendance
      final entry = AttendanceEntry(AttendanceStatus.present);
      await storage.setStatusRaw(profile.id, dateKey, entry.toStorage());

      final timeStr = "${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}";
      // Save metadata
      final metadata = {
        'timestamp': today.millisecondsSinceEpoch,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'method': 'GPS Auto Marked',
        'locationName': location.name,
        'gpsVerified': true,
        'status': isLate ? 'Late' : 'Present',
        'arrivalTime': timeStr,
        'departureTime': timeStr,
        'duration': '0m',
        'delayDuration': delayStr ?? '0 minutes',
      };
      await storage.setAttendanceMetadata(profile.id, dateKey, metadata);

      // Cancel pending reminders
      notifications.cancel(profile.id.hashCode);

      // Trigger Success Notification
      final statusLabel = isLate ? "Late" : "Present";
      _sendNotification(
        90003,
        "✓ Attendance Marked ($statusLabel)",
        "Arrived at $timeStr for ${location.name} (GPS Verified).",
      );

      // Notify listeners so UI updates instantly
      notifyListeners();

      // Trigger motivational check
      final motivational = MotivationalNotificationService(storage, notifications);
      Future.delayed(const Duration(seconds: 2), () {
        motivational.checkAndTrigger(profile);
      });
    } else {
      // Already marked today. Update departure time if status is present/late.
      if (existingMetadata != null && existingRaw.startsWith('present')) {
        final arrivalStr = existingMetadata['arrivalTime'] as String?;
        if (arrivalStr != null) {
          final timeStr = "${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}";
          
          // Calculate duration between arrivalStr and now
          final parts = arrivalStr.split(':');
          final arrHour = int.parse(parts[0]);
          final arrMin = int.parse(parts[1]);
          
          final nowHour = today.hour;
          final nowMin = today.minute;
          
          int totalMins = (nowHour * 60 + nowMin) - (arrHour * 60 + arrMin);
          if (totalMins < 0) totalMins = 0;
          
          final hrs = totalMins ~/ 60;
          final mins = totalMins % 60;
          final durationStr = hrs > 0 ? "${hrs}h ${mins}m" : "${mins}m";

          // Update metadata with new departure time and duration
          final updatedMetadata = Map<String, dynamic>.from(existingMetadata);
          updatedMetadata['departureTime'] = timeStr;
          updatedMetadata['duration'] = durationStr;
          
          await storage.setAttendanceMetadata(profile.id, dateKey, updatedMetadata);
          notifyListeners();
        }
      }
    }
  }

  /// Periodic checks for missed deadlines (Absent detection) & reminders
  void _startDeadlineChecks() {
    _deadlineTimer?.cancel();
    _deadlineTimer = Timer.periodic(const Duration(minutes: 1), (_) => _runScheduledAlerts());
  }

  /// Run alerts for the active profile
  void _runScheduledAlerts() async {
    if (_activeProfileId == null) return;
    
    // Get profile
    final profile = storage.getProfiles().firstWhere((p) => p.id == _activeProfileId);
    
    // Update tracking state: starts or stops tracking based on current window/status
    updateTrackingState();

    if (profile.locations.isEmpty) return;

    final today = DateTime.now();
    
    // Check if sunday or holiday
    final dateKey = DateTime(today.year, today.month, today.day);
    final dateKeyStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    if (today.weekday == DateTime.sunday || profile.holidays.contains(dateKeyStr)) {
      return; // Skip alerts on holidays/sundays
    }

    final existing = storage.getStatusRaw(profile.id, dateKey);
    if (existing != null) {
      return; // Already marked today
    }

    // Process closest location timing
    for (final loc in profile.locations) {
      final start = _parseTime(loc.startTime);
      final cutoff = _parseTime(loc.cutoffTime);
      if (cutoff == null) continue; // Skip deadline checks if cutoff is not configured

      final nowTime = TimeOfDay.fromDateTime(today);
      final nowMin = nowTime.hour * 60 + nowTime.minute;
      final cutoffMin = cutoff.hour * 60 + cutoff.minute;
      final startMin = start != null ? start.hour * 60 + start.minute : 0;

      // 1. Failure Alarm Check during the attendance window
      if (start != null && nowMin >= startMin && nowMin <= cutoffMin) {
        final permission = await Geolocator.checkPermission();
        final gpsEnabled = await Geolocator.isLocationServiceEnabled();
        
        bool permissionDenied = permission == LocationPermission.denied || permission == LocationPermission.deniedForever;
        bool gpsDisabled = !gpsEnabled;
        bool locationUnavailable = _currentPosition == null;
        
        bool geofenceFailed = false;
        if (_lastCheckedTime != null) {
          final timeSinceLastCheck = today.difference(_lastCheckedTime!).inMinutes;
          if (timeSinceLastCheck > 10) { // No location check succeeded in 10 minutes
            geofenceFailed = true;
          }
        } else {
          // If we have been in the window for more than 5 minutes and haven't checked location
          if (nowMin - startMin > 5) {
            geofenceFailed = true;
          }
        }

        if (permissionDenied || gpsDisabled || locationUnavailable || geofenceFailed) {
          // Trigger alarm notification (with quick action buttons to let them mark manually)
          final lastNotificationTime = _lastFailureNotificationTime;
          if (lastNotificationTime == null || today.difference(lastNotificationTime).inMinutes >= 15) {
            _lastFailureNotificationTime = today;

            String alertBody = "";
            if (gpsDisabled) {
              alertBody = "GPS is disabled. Please turn on location services to verify attendance.";
            } else if (permissionDenied) {
              alertBody = "Location permission is denied. Auto-attendance cannot verify your location.";
            } else if (locationUnavailable) {
              alertBody = "Location is unavailable. Please check your signal or connection.";
            } else {
              alertBody = "Geofence detection failed. Please verify attendance manually.";
            }

            _sendNotificationWithActions(
              90025,
              "⚠️ Attendance Verification Alarm",
              alertBody,
              const [
                AndroidNotificationAction('ACTION_PRESENT', 'Present'),
                AndroidNotificationAction('ACTION_HALF', 'Half Day'),
                AndroidNotificationAction('ACTION_ABSENT', 'Absent'),
              ],
            );
          }
        }
      }

      // 2. Absent Detection: If current time is past cutoff time and user never entered
      if (nowMin > cutoffMin && nowMin < cutoffMin + 5) {
        // Just passed cutoff time! Mark absent
        final entry = AttendanceEntry(AttendanceStatus.absent);
        await storage.setStatusRaw(profile.id, dateKey, entry.toStorage());

        final metadata = {
          'timestamp': today.millisecondsSinceEpoch,
          'latitude': _currentPosition?.latitude ?? 0.0,
          'longitude': _currentPosition?.longitude ?? 0.0,
          'accuracy': _currentPosition?.accuracy ?? 0.0,
          'method': 'GPS Auto Marked',
          'locationName': loc.name,
          'gpsVerified': false,
          'reason': 'Attendance window closed. User was not detected inside the geofence area.',
        };
        await storage.setAttendanceMetadata(profile.id, dateKey, metadata);

        _sendNotification(
          90004,
          "❌ Attendance Missed",
          "Attendance window has closed. You were not detected within the ${loc.name} area.",
        );
        notifyListeners();

        // Trigger motivational check
        final motivational = MotivationalNotificationService(storage, notifications);
        Future.delayed(const Duration(seconds: 2), () {
          motivational.checkAndTrigger(profile);
        });
        return;
      }

      // 3. Escalating reminders before cutoff
      final diff = cutoffMin - nowMin;
      if (diff == 60) {
        _sendNotification(90010, "⏰ Attendance Reminder", "You have not reached your attendance location yet.");
      } else if (diff == 30) {
        _sendNotification(90011, "⏰ Deadline Approaching", "Attendance deadline is approaching.");
      } else if (diff == 15) {
        _sendNotification(90012, "⏰ Attendance Warning", "You are still outside the attendance area.");
      } else if (diff == 5) {
        _sendNotification(90013, "⚠️ Critical Attendance Alert", "Attendance may be marked absent if you do not arrive soon.");
      }
    }
  }

  /// Parse time helper
  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      final clean = timeStr.trim().toUpperCase();
      if (clean.contains('AM') || clean.contains('PM')) {
        final parts = clean.split(' ');
        final hm = parts[0].split(':');
        var hour = int.parse(hm[0]);
        final minute = int.parse(hm[1]);
        if (clean.contains('PM') && hour != 12) hour += 12;
        if (clean.contains('AM') && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      } else {
        final parts = clean.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {
      return null;
    }
  }

  /// Helper to send notifications
  void _sendNotification(int id, String title, String body) {
    notifications.showNotification(
      id: id,
      title: title,
      body: body,
      payload: _activeProfileId,
    );
  }

  /// Send location services disabled warning
  void _sendLocationDisabledNotification() {
    notifications.showNotification(
      id: 90020,
      title: "⚠️ Location Services Disabled",
      body: "Location services are disabled. Attendance cannot be verified.",
      payload: _activeProfileId,
    );
  }

  /// Helper to send notifications with action buttons
  void _sendNotificationWithActions(int id, String title, String body, List<AndroidNotificationAction> actions) {
    notifications.showNotification(
      id: id,
      title: title,
      body: body,
      payload: _activeProfileId,
      actions: actions,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _deadlineTimer?.cancel();
    _positionStreamSub?.cancel();
    super.dispose();
  }
}
