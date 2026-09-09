import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';
import '../models/attendance_location.dart';
import '../models/profile.dart';
import '../providers/app_provider.dart';

class LocationSetupScreen extends StatefulWidget {
  final Profile profile;
  final AttendanceLocation? existing;

  /// When called from wizard: auto-set name from type, call this instead of saving to provider
  final String? autoNameFromType;
  final void Function(AttendanceLocation)? onSaved;

  const LocationSetupScreen({
    super.key,
    required this.profile,
    this.existing,
    this.autoNameFromType,
    this.onSaved,
  });

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();
  google.GoogleMapController? _googleController;
  bool _useGoogleMaps = false;
  bool _mapReady = false;
  bool _saving = false;
  int _searchRequest = 0;
  int _geocodeRequest = 0;
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'User-Agent': 'AttendX/2.6 (attendance location selection)'},
    ),
  );

  Future<void> _checkGoogleMaps() async {
    if (!StorageService.supportsNative) return;
    try {
      final configured =
          await StorageService.nativeChannel.invokeMethod<bool>(
            'googleMapsConfigured',
          ) ??
          false;
      if (mounted && configured)
        setState(() {
          _useGoogleMaps = true;
          _mapReady = false;
        });
    } catch (_) {
      /* Keep the working fallback if Google Maps is not configured. */
    }
  }

  void _moveMap(LatLng point) {
    if (_useGoogleMaps) {
      _googleController?.animateCamera(
        google.CameraUpdate.newLatLngZoom(
          google.LatLng(point.latitude, point.longitude),
          16,
        ),
      );
    } else if (_mapReady) {
      _mapController.move(point, 16);
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  LatLng _selectedPoint = const LatLng(25.3176, 82.9739);
  double _radius = 50.0;
  TimeOfDay? _startTime;
  TimeOfDay? _cutoffTime;
  bool _useCustomTime = false;

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingCurrent = false;

  @override
  void initState() {
    super.initState();
    _checkGoogleMaps();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _addressCtrl.text = e.address;
      _selectedPoint = LatLng(e.latitude, e.longitude);
      _radius = e.radius.clamp(10.0, 100.0);
      _startTime = e.startTime != null ? _parseTimeOfDay(e.startTime!) : null;
      _cutoffTime = e.cutoffTime != null
          ? _parseTimeOfDay(e.cutoffTime!)
          : null;
      _useCustomTime = _startTime != null && _cutoffTime != null;
    } else {
      _nameCtrl.text = widget.autoNameFromType ?? 'Workplace';
      _getUserCurrentLocation();
      _useCustomTime = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    _googleController?.dispose();
    _mapController.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _getUserCurrentLocation() async {
    if (_isLoadingCurrent) return;
    setState(() => _isLoadingCurrent = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _message('Location permission is needed to find your position.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _message('Enable location permission in system settings.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedPoint = point);
      _moveMap(point);
      _reverseGeocode(point);
    } catch (e) {
      _message(
        'Could not find your position. Try again or search for an address.',
      );
    } finally {
      if (mounted) setState(() => _isLoadingCurrent = false);
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    final request = ++_searchRequest;
    setState(() => _isSearching = true);
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': query, 'format': 'json', 'limit': 5},
      );
      if (response.statusCode == 200 && response.data != null) {
        if (!mounted || request != _searchRequest) return;
        final List list = response.data;
        if (list.isEmpty)
          _message('No matching addresses found. Try a nearby landmark.');
        setState(() {
          _searchResults = list
              .map(
                (item) => {
                  'display_name': item['display_name'] as String,
                  'lat': double.parse(item['lat'] as String),
                  'lon': double.parse(item['lon'] as String),
                },
              )
              .toList();
        });
      }
    } catch (e) {
      if (request == _searchRequest)
        _message('Address search unavailable. Please try again.');
    } finally {
      if (mounted && request == _searchRequest)
        setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final request = ++_geocodeRequest;
    _addressCtrl.text =
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'json',
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final displayName = response.data['display_name'] as String?;
        if (displayName != null && mounted && request == _geocodeRequest) {
          setState(() => _addressCtrl.text = displayName);
        }
      }
    } catch (_) {}
  }

  void _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    if (_useCustomTime && (_startTime == null || _cutoffTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'On Time and Cut-off Time are required when custom time is enabled',
          ),
        ),
      );
      return;
    }

    if (_useCustomTime && _startTime != null && _cutoffTime != null) {
      final startMin = _startTime!.hour * 60 + _startTime!.minute;
      final cutoffMin = _cutoffTime!.hour * 60 + _cutoffTime!.minute;
      if (startMin >= cutoffMin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start time must be before cut-off time'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final newLoc = AttendanceLocation(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: _addressCtrl.text.trim(),
      latitude: _selectedPoint.latitude,
      longitude: _selectedPoint.longitude,
      radius: _radius,
      startTime: _useCustomTime && _startTime != null
          ? _formatTimeOfDay(_startTime!)
          : null,
      cutoffTime: _useCustomTime && _cutoffTime != null
          ? _formatTimeOfDay(_cutoffTime!)
          : null,
    );

    // If called from wizard, return via callback instead of saving to provider
    if (widget.onSaved != null) {
      widget.onSaved!(newLoc);
      return;
    }

    // Normal save flow: update the profile in the provider
    final provider = context.read<AppProvider>();
    final List<AttendanceLocation> updatedLocations = List.from(
      widget.profile.locations,
    );

    if (widget.existing != null) {
      final idx = updatedLocations.indexWhere(
        (loc) => loc.id == widget.existing!.id,
      );
      if (idx != -1) {
        updatedLocations[idx] = newLoc;
      } else {
        updatedLocations.add(newLoc);
      }
    } else {
      updatedLocations.add(newLoc);
    }

    setState(() => _saving = true);
    final previous = widget.profile.locations;
    try {
      widget.profile.locations = updatedLocations;
      await provider.updateProfile(widget.profile);
    } catch (_) {
      widget.profile.locations = previous;
      _message('Could not save this location. Please try again.');
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location "${newLoc.name}" saved!'),
          backgroundColor: AppColors.forestGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Location' : 'Set Attendance Location'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Map
          if (_useGoogleMaps)
            google.GoogleMap(
              initialCameraPosition: google.CameraPosition(
                target: google.LatLng(
                  _selectedPoint.latitude,
                  _selectedPoint.longitude,
                ),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _googleController = controller;
                _moveMap(_selectedPoint);
              },
              onTap: (point) {
                final selected = LatLng(point.latitude, point.longitude);
                setState(() => _selectedPoint = selected);
                _reverseGeocode(selected);
              },
              markers: {
                google.Marker(
                  markerId: const google.MarkerId('workplace'),
                  position: google.LatLng(
                    _selectedPoint.latitude,
                    _selectedPoint.longitude,
                  ),
                ),
              },
              circles: {
                google.Circle(
                  circleId: const google.CircleId('attendance-radius'),
                  center: google.LatLng(
                    _selectedPoint.latitude,
                    _selectedPoint.longitude,
                  ),
                  radius: _radius,
                  fillColor: AppColors.forestGreen.withValues(alpha: 0.15),
                  strokeColor: AppColors.forestGreen,
                  strokeWidth: 2,
                ),
              },
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              padding: EdgeInsets.only(
                bottom: MediaQuery.sizeOf(context).height * 0.5,
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 15.0,
                onMapReady: () {
                  _mapReady = true;
                  _moveMap(_selectedPoint);
                },
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedPoint = point;
                    _reverseGeocode(point);
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _selectedPoint,
                      radius: _radius,
                      useRadiusInMeter: true,
                      color: AppColors.forestGreen.withValues(alpha: 0.15),
                      borderColor: AppColors.forestGreen,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.absent,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),

          // Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search address...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: AppColors.textSubtle),
                          ),
                          onSubmitted: _searchAddress,
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchRequest++;
                              _isSearching = false;
                              _searchCtrl.clear();
                              _searchResults.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          title: Text(
                            item['display_name'] as String,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _geocodeRequest++;
                            FocusScope.of(context).unfocus();
                            final point = LatLng(
                              item['lat'] as double,
                              item['lon'] as double,
                            );
                            setState(() {
                              _selectedPoint = point;
                              _addressCtrl.text =
                                  item['display_name'] as String;
                              _searchResults.clear();
                              _searchCtrl.text = item['display_name'] as String;
                            });
                            _moveMap(point);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // My location FAB
          Positioned(
            top: 90,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_loc',
              onPressed: _isLoadingCurrent ? null : _getUserCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.forestGreen,
              mini: true,
              child: _isLoadingCurrent
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // Bottom Form Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                      child: Text(
                        _useGoogleMaps
                            ? 'Address search: OpenStreetMap contributors'
                            : 'Map: OpenStreetMap contributors / CARTO. Google Maps available in configured Android builds.',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    // Name
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location Name',
                        hintText: 'e.g. Office, College',
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Address (readonly)
                    TextField(
                      controller: _addressCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Address (tap map to update)',
                        border: UnderlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Radius Slider — 10 to 100m
                    Row(
                      children: [
                        Text(
                          'Radius: ${_radius.round()}m',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _radius,
                            min: 10,
                            max: 100,
                            divisions: 18,
                            activeColor: AppColors.forestGreen,
                            label: '${_radius.round()}m',
                            onChanged: (val) => setState(() => _radius = val),
                          ),
                        ),
                        Text(
                          '${_radius.round()}m',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '10m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          '100m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // On Time & Cut-off Time Pickers
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Custom Location Check Time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Specify custom on-time and cutoff hours for this location',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: _useCustomTime,
                      activeColor: AppColors.forestGreen,
                      onChanged: (val) {
                        setState(() {
                          _useCustomTime = val;
                          if (!val) {
                            _startTime = null;
                            _cutoffTime = null;
                          } else {
                            _startTime = const TimeOfDay(hour: 9, minute: 0);
                            _cutoffTime = const TimeOfDay(hour: 9, minute: 30);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    if (_useCustomTime) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildOptionalTimePicker(
                              label: 'On Time (Check-In Start)',
                              time: _startTime,
                              onSet: (t) => setState(() => _startTime = t),
                              onClear: () => setState(() => _startTime = null),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOptionalTimePicker(
                              label: 'Cut-off Time (Deadline)',
                              time: _cutoffTime,
                              onSet: (t) => setState(() => _cutoffTime = t),
                              onClear: () => setState(() => _cutoffTime = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          _saving
                              ? 'Saving...'
                              : (isEdit ? 'Save Changes' : 'Confirm Location'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalTimePicker({
    required String label,
    required TimeOfDay? time,
    required void Function(TimeOfDay) onSet,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (t != null) onSet(t);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: time != null
                ? AppColors.forestGreen.withValues(alpha: 0.5)
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
          color: time != null
              ? AppColors.forestGreen.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time != null ? time.format(context) : 'Select time',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: time != null
                          ? AppColors.textPrimary
                          : AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
