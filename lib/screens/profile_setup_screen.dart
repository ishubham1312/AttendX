import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/profile.dart';
import '../providers/app_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isFirst;
  final Profile? existing;
  const ProfileSetupScreen({super.key, this.isFirst = false, this.existing});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  String _role = 'Office';
  DateTime _startDate = DateTime.now();
  TimeOfDay _reminder = const TimeOfDay(hour: 9, minute: 0);
  bool _sandwichLeaveEnabled = false;

  final _roles = const ['Office', 'College', 'School'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _salaryCtrl.text = e.monthlySalary > 0 ? e.monthlySalary.toString() : '';
      _role = e.role;
      _startDate = e.startDate;
      _reminder = TimeOfDay(hour: e.reminderHour, minute: e.reminderMinute);
      _sandwichLeaveEnabled = e.sandwichLeaveEnabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    final provider = context.read<AppProvider>();
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final profile = Profile(
      id: id,
      name: name,
      role: _role,
      startDate: _startDate,
      reminderHour: _reminder.hour,
      reminderMinute: _reminder.minute,
      monthlySalary: double.tryParse(_salaryCtrl.text.trim()) ?? 0,
      sandwichLeaveEnabled: _sandwichLeaveEnabled,
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
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        title: Text(isEdit
            ? 'Edit Profile'
            : widget.isFirst
                ? 'Set Up Your Profile'
                : 'New Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('Name'),
            _field(_nameCtrl, hint: 'e.g. Rose, John...'),
            const SizedBox(height: 18),
            _label('Type'),
            Row(
              children: _roles.map((r) {
                final active = r == _role;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _role = r),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: active ? AppColors.forestGreen : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          r,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _label('Start Date'),
            _tappableTile(
              icon: Icons.calendar_today_outlined,
              text: DateFormat('MMM dd, yyyy').format(_startDate),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _startDate = d);
              },
            ),
            const SizedBox(height: 18),
            _label('Daily Reminder Time'),
            _tappableTile(
              icon: Icons.notifications_active_outlined,
              text: _reminder.format(context),
              onTap: () async {
                final t = await showTimePicker(
                    context: context, initialTime: _reminder);
                if (t != null) setState(() => _reminder = t);
              },
            ),
            const SizedBox(height: 18),
            _label('Monthly Salary (optional)'),
            _field(_salaryCtrl,
                hint: 'e.g. 30000', keyboard: TextInputType.number),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Per-day pay is calculated automatically from working days (Mon–Fri) in each month.',
                style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
              ),
            ),
            const SizedBox(height: 18),
            _label('Sandwich Leave Rule'),
            _switchTile(
              icon: Icons.layers_outlined,
              title: 'Enable Sandwich Leave',
              subtitle: 'Holidays between two Absent days will count as Absent',
              value: _sandwichLeaveEnabled,
              onChanged: (val) => setState(() => _sandwichLeaveEnabled = val),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(isEdit ? 'Save Changes' : 'Continue',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );

  Widget _field(TextEditingController c,
      {String? hint, TextInputType? keyboard}) {
    return Container(
      decoration: softCard(radius: 14),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSubtle),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _tappableTile(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: softCard(radius: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.forestGreen, size: 20),
            const SizedBox(width: 12),
            Text(text,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textSubtle),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: softCard(radius: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.forestGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.forestGreen,
          ),
        ],
      ),
    );
  }
}
