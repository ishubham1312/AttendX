import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/profile.dart';
import '../models/attendance_location.dart';
import 'location_setup_screen.dart';

/// Multi-step attendance setup wizard shown during onboarding
/// Steps: Name → Type → Location → Arrival Time → Salary (conditional)
class AttendanceSetupWizardScreen extends StatefulWidget {
  final bool isFirst;
  final Profile? existing;
  const AttendanceSetupWizardScreen({super.key, this.isFirst = true, this.existing});

  @override
  State<AttendanceSetupWizardScreen> createState() => _AttendanceSetupWizardScreenState();
}

class _AttendanceSetupWizardScreenState extends State<AttendanceSetupWizardScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;

  // Step 1: Name
  final _nameCtrl = TextEditingController();

  // Step 2: Attendance Type
  String _attendanceType = '';
  bool? _salaryEnabled; // For 'Other' type

  // Step 3: Location (handled via LocationSetupScreen inline or passed back)
  AttendanceLocation? _location;
  bool _locationDone = false;

  // Step 4: Arrival Time
  TimeOfDay? _arrivalTime;

  // Step 5: Salary
  final _salaryCtrl = TextEditingController();
  bool _sandwichLeaveEnabled = false;

  static const _types = [
    {'label': 'Office', 'icon': Icons.business_center_rounded, 'color': 0xFF2D6A4F},
    {'label': 'School', 'icon': Icons.school_rounded, 'color': 0xFF1B7A6B},
    {'label': 'College', 'icon': Icons.account_balance_rounded, 'color': 0xFF2563EB},
    {'label': 'University', 'icon': Icons.local_library_rounded, 'color': 0xFF7C3AED},
    {'label': 'Library', 'icon': Icons.menu_book_rounded, 'color': 0xFFD97706},
    {'label': 'Workplace', 'icon': Icons.work_rounded, 'color': 0xFF059669},
    {'label': 'Training Center', 'icon': Icons.fitness_center_rounded, 'color': 0xFFDC2626},
    {'label': 'Other', 'icon': Icons.place_rounded, 'color': 0xFF6B7280},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _attendanceType = e.attendanceType;
      if (e.reminderHour > 0 || e.reminderMinute > 0) {
        _arrivalTime = TimeOfDay(hour: e.reminderHour, minute: e.reminderMinute);
      }
      if (e.monthlySalary > 0) _salaryCtrl.text = e.monthlySalary.toStringAsFixed(0);
      if (e.locations.isNotEmpty) {
        _location = e.locations.first;
        _locationDone = true;
      }
      _salaryEnabled = e.salaryTrackingEnabled;
      _sandwichLeaveEnabled = e.sandwichLeaveEnabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salaryCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  bool get _showSalaryStep =>
      _attendanceType == 'Office' || (_attendanceType == 'Other' && _salaryEnabled == true);

  // Total steps depends on type selection
  int get _totalSteps {
    if (_attendanceType.isEmpty) return 5;
    return _showSalaryStep ? 5 : 4;
  }

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    final provider = context.read<AppProvider>();
    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final profile = Profile(
      id: id,
      name: _nameCtrl.text.trim(),
      role: _attendanceType,
      attendanceType: _attendanceType,
      startDate: DateTime.now(),
      reminderHour: _arrivalTime?.hour ?? 0,
      reminderMinute: _arrivalTime?.minute ?? 0,
      monthlySalary: double.tryParse(_salaryCtrl.text.trim()) ?? 0,
      salaryTrackingEnabled: _salaryEnabled ?? false,
      sandwichLeaveEnabled: _sandwichLeaveEnabled,
      locations: _location != null ? [_location!] : [],
    );

    if (widget.existing != null) {
      await provider.updateProfile(profile);
    } else {
      await provider.addProfile(profile);
    }
    await provider.notifications.requestPermissions();

    if (!mounted) return;
    if (widget.isFirst) {
      await provider.completeOnboarding();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar + back button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                      onPressed: _prevPage,
                      color: AppColors.textPrimary,
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(AppColors.forestGreen),
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildNameStep(),
                  _buildTypeStep(),
                  _buildLocationStep(),
                  _buildArrivalTimeStep(),
                  if (_showSalaryStep) _buildSalaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Name ────────────────────────────────────────────────────────────
  Widget _buildNameStep() {
    return _StepWrapper(
      title: 'What\'s your name?',
      subtitle: 'We\'ll use this to personalize your attendance records.',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          Container(
            decoration: softCard(radius: 16),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Your name...',
                hintStyle: TextStyle(color: AppColors.textSubtle, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              if (_nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your name')),
                );
                return;
              }
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Attendance Type ─────────────────────────────────────────────────
  Widget _buildTypeStep() {
    return _StepWrapper(
      title: 'Where do you attend?',
      subtitle: 'Choose the type of place you want to track attendance for.',
      icon: Icons.place_rounded,
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: _types.map((t) {
              final label = t['label'] as String;
              final icon = t['icon'] as IconData;
              final color = Color(t['color'] as int);
              final selected = _attendanceType == label;
              return GestureDetector(
                onTap: () => setState(() {
                  _attendanceType = label;
                  if (label != 'Other') _salaryEnabled = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? color : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: selected ? color : AppColors.textSubtle, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected ? color : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // Salary question for "Other"
          if (_attendanceType == 'Other') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: softCard(radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Do you want to track monthly salary?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ChoiceChip(
                        label: 'Yes',
                        selected: _salaryEnabled == true,
                        onTap: () => setState(() => _salaryEnabled = true),
                        color: AppColors.forestGreen,
                      ),
                      const SizedBox(width: 12),
                      _ChoiceChip(
                        label: 'No',
                        selected: _salaryEnabled == false,
                        onTap: () => setState(() => _salaryEnabled = false),
                        color: AppColors.absent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              if (_attendanceType.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select an attendance type')),
                );
                return;
              }
              if (_attendanceType == 'Other' && _salaryEnabled == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please answer the salary question')),
                );
                return;
              }
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Location ────────────────────────────────────────────────────────
  Widget _buildLocationStep() {
    return _StepWrapper(
      title: 'Set your location',
      subtitle: 'Pick the place where attendance will be tracked automatically.',
      icon: Icons.location_on_rounded,
      child: Column(
        children: [
          if (_locationDone && _location != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.forestGreen, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _location!.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        if (_location!.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _location!.address,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Radius: ${_location!.radius.round()}m',
                          style: const TextStyle(color: AppColors.forestGreen, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openLocationSetup,
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              label: const Text('Change Location'),
              style: TextButton.styleFrom(foregroundColor: AppColors.forestGreen),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: softCard(radius: 16),
              child: Column(
                children: [
                  Icon(Icons.add_location_alt_rounded, color: AppColors.forestGreen, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'No location set yet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap below to select your attendance location on a map.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: 'Set Location on Map',
              icon: Icons.map_rounded,
              onTap: _openLocationSetup,
            ),
          ],
          const SizedBox(height: 24),
          if (_locationDone)
            _PrimaryButton(
              label: 'Continue',
              onTap: _nextPage,
            ),
        ],
      ),
    );
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      final parts = timeStr.trim().split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  void _openLocationSetup() async {
    // Create a temporary profile shell for LocationSetupScreen
    final tempProfile = Profile(
      id: widget.existing?.id ?? 'temp_wizard',
      name: _nameCtrl.text.trim().isEmpty ? 'Me' : _nameCtrl.text.trim(),
      role: _attendanceType.isEmpty ? 'Office' : _attendanceType,
      attendanceType: _attendanceType.isEmpty ? 'Office' : _attendanceType,
      startDate: DateTime.now(),
      locations: _location != null ? [_location!] : [],
    );

    final result = await Navigator.push<AttendanceLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSetupScreen(
          profile: tempProfile,
          existing: _location,
          autoNameFromType: _attendanceType,
          onSaved: (loc) => Navigator.pop(context, loc),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _location = result;
        _locationDone = true;
        if (result.cutoffTime != null) {
          _arrivalTime = _parseTimeOfDay(result.cutoffTime);
        }
      });
    }
  }

  // ─── Step 4: Arrival Time ────────────────────────────────────────────────────
  Widget _buildArrivalTimeStep() {
    return _StepWrapper(
      title: 'Set arrival time',
      subtitle: 'Optional. Set your usual arrival time for reminders.',
      icon: Icons.schedule_rounded,
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _arrivalTime ?? const TimeOfDay(hour: 9, minute: 0),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                  child: child!,
                ),
              );
              if (t != null) setState(() => _arrivalTime = t);
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _arrivalTime != null
                    ? AppColors.forestGreen.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _arrivalTime != null
                      ? AppColors.forestGreen.withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: _arrivalTime != null ? AppColors.forestGreen : AppColors.textSubtle,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _arrivalTime != null
                              ? _arrivalTime!.format(context)
                              : 'Tap to set arrival time',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: _arrivalTime != null ? AppColors.textPrimary : AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _arrivalTime != null ? 'Arrival time configured' : 'Not configured (optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: _arrivalTime != null ? AppColors.forestGreen : AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _arrivalTime != null ? AppColors.forestGreen : AppColors.textSubtle,
                  ),
                ],
              ),
            ),
          ),
          if (_arrivalTime != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _arrivalTime = null),
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear time'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If left blank, attendance will be marked automatically when you arrive — no time limits.',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: _showSalaryStep ? 'Continue' : 'Finish Setup',
            onTap: _showSalaryStep ? _nextPage : _finish,
          ),
        ],
      ),
    );
  }

  // ─── Step 5: Salary (Conditional) ───────────────────────────────────────────
  Widget _buildSalaryStep() {
    return _StepWrapper(
      title: 'Monthly Salary',
      subtitle: 'Enter your monthly salary for earnings calculations.',
      icon: Icons.payments_rounded,
      child: Column(
        children: [
          Container(
            decoration: softCard(radius: 16),
            child: TextField(
              controller: _salaryCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestGreen,
                ),
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.textSubtle, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Per-day salary is calculated from working days each month.',
              style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: softCard(radius: 16),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Sandwich Leave Policy',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Weekends/holidays between leaves will be treated as leave.',
                style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
              ),
              value: _sandwichLeaveEnabled,
              activeThumbColor: AppColors.forestGreen,
              onChanged: (val) => setState(() => _sandwichLeaveEnabled = val),
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Finish Setup',
            onTap: _finish,
          ),
          TextButton(
            onPressed: () {
              _salaryCtrl.clear();
              _finish();
            },
            child: const Text('Skip for now', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable step wrapper ───────────────────────────────────────────────────
class _StepWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _StepWrapper({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.forestGreen, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const _PrimaryButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Choice chip ─────────────────────────────────────────────────────────────
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _ChoiceChip({required this.label, required this.selected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
