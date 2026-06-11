import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../providers/app_provider.dart';

class AlarmCenterScreen extends StatefulWidget {
  const AlarmCenterScreen({super.key});

  @override
  State<AlarmCenterScreen> createState() => _AlarmCenterScreenState();
}

class _AlarmCenterScreenState extends State<AlarmCenterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Widget animatedItem(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _animCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 25 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final alarms = provider.getAlarms();

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        title: const Text(
          'Alarm Center',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: alarms.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              physics: const BouncingScrollPhysics(),
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                return animatedItem(
                  index,
                  _AlarmCard(
                    alarm: alarms[index],
                    onToggle: (enabled) {
                      provider.toggleAlarm(alarms[index].id, enabled);
                    },
                    onEdit: () => _showAlarmEditor(context, provider,
                        existing: alarms[index]),
                    onDelete: alarms[index].isPrimary
                        ? null
                        : () => _confirmDelete(
                            context, provider, alarms[index]),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAlarmEditor(context, provider),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text(
          'Add Alarm',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.alarm_rounded,
              size: 48,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Alarms Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to create your first alarm',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAlarmEditor(BuildContext context, AppProvider provider,
      {AlarmItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AlarmEditorSheet(
        existing: existing,
        onSave: (alarm) async {
          await provider.saveAlarm(alarm);
          if (context.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppProvider provider, AlarmItem alarm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Alarm?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to delete "${alarm.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteAlarm(alarm.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.absent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Alarm Card ────────────────────────────────────────────────────────────────

class _AlarmCard extends StatelessWidget {
  final AlarmItem alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _AlarmCard({
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = alarm.isEnabled;

    return GestureDetector(
      onTap: onEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: alarm.isPrimary
                ? AppColors.forestGreen.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isEnabled
                  ? AppColors.forestGreen.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.01),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Active status accent bar on the left edge
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  color: isEnabled
                      ? AppColors.forestGreen
                      : Colors.grey.shade300,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Icon & Title/Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Icon
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isEnabled
                                          ? AppColors.forestGreen.withValues(alpha: 0.08)
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      alarm.isPrimary
                                          ? Icons.notifications_active_rounded
                                          : Icons.alarm_rounded,
                                      color: isEnabled
                                          ? AppColors.forestGreen
                                          : AppColors.textSubtle,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              alarm.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: isEnabled
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSubtle,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            if (alarm.isPrimary) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.forestGreen
                                                      .withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'Primary',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: AppColors.forestGreen,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Large Time Text
                              Text(
                                alarm.timeString,
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: isEnabled
                                      ? AppColors.textPrimary
                                      : AppColors.textSubtle,
                                  letterSpacing: -1.2,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right: Switch & Action Buttons
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Transform.scale(
                              scale: 0.85,
                              child: Switch(
                                value: alarm.isEnabled,
                                onChanged: onToggle,
                                activeThumbColor: Colors.white,
                                activeTrackColor: AppColors.forestGreen,
                                inactiveThumbColor: Colors.grey.shade400,
                                inactiveTrackColor: Colors.grey.shade200,
                              ),
                            ),
                            if (onDelete != null)
                              IconButton(
                                onPressed: onDelete,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.absent,
                                  size: 20,
                                ),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(top: 8, right: 8),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.grey.shade100,
                    ),
                    const SizedBox(height: 14),
                    // Bottom Row: Details and Repeat Representation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Repeat days row representation or Once label
                        alarm.isRepeating
                            ? _buildRepeatDaysRow(alarm.repeatDays, isEnabled)
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: isEnabled
                                          ? AppColors.textSecondary
                                          : AppColors.textSubtle,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Once',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isEnabled
                                            ? AppColors.textSecondary
                                            : AppColors.textSubtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        // Category pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: alarm.isPrimary
                                ? AppColors.forestGreen.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alarm.isPrimary ? 'Arrival Alarm' : 'Custom Alarm',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: alarm.isPrimary
                                  ? AppColors.forestGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatDaysRow(List<int> repeatDays, bool isEnabled) {
    const days = [
      (1, 'M'),
      (2, 'T'),
      (3, 'W'),
      (4, 'T'),
      (5, 'F'),
      (6, 'S'),
      (7, 'S'),
    ];

    return Row(
      children: days.map((day) {
        final isActiveDay = repeatDays.contains(day.$1);
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isActiveDay
                ? (isEnabled
                    ? AppColors.forestGreen.withValues(alpha: 0.1)
                    : Colors.grey.shade200)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActiveDay
                  ? (isEnabled ? AppColors.forestGreen.withValues(alpha: 0.2) : Colors.grey.shade300)
                  : Colors.grey.shade100,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              day.$2,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: isActiveDay
                    ? (isEnabled ? AppColors.forestGreen : AppColors.textSecondary)
                    : AppColors.textSubtle,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Alarm Editor Bottom Sheet ─────────────────────────────────────────────────

class _AlarmEditorSheet extends StatefulWidget {
  final AlarmItem? existing;
  final Future<void> Function(AlarmItem alarm) onSave;

  const _AlarmEditorSheet({
    this.existing,
    required this.onSave,
  });

  @override
  State<_AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends State<_AlarmEditorSheet> {
  late final TextEditingController _nameCtrl;
  late TimeOfDay _time;
  late bool _isRepeating;
  late List<int> _repeatDays;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _time = e != null
        ? TimeOfDay(hour: e.hour, minute: e.minute)
        : const TimeOfDay(hour: 9, minute: 0);
    _isRepeating = e?.isRepeating ?? true;
    _repeatDays = e != null ? List<int>.from(e.repeatDays) : [1, 2, 3, 4, 5, 6];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an alarm name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final alarm = AlarmItem(
      id: widget.existing?.id ??
          'alarm_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      hour: _time.hour,
      minute: _time.minute,
      isEnabled: widget.existing?.isEnabled ?? true,
      isRepeating: _isRepeating,
      repeatDays: _repeatDays,
      type: widget.existing?.type ?? AlarmType.custom,
      linkedProfileId: widget.existing?.linkedProfileId,
    );

    await widget.onSave(alarm);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final isPrimary = widget.existing?.isPrimary ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'Edit Alarm' : 'New Alarm',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Time picker
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.forestGreen.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: AppColors.forestGreen,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _time.format(context),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forestGreen,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to change time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name field
            if (!isPrimary) ...[
              const Text(
                'Alarm Name',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Office Arrival, Break Time...',
                    hintStyle: TextStyle(
                      color: AppColors.textSubtle,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Repeat toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    color: AppColors.forestGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Repeat',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isRepeating,
                    onChanged: (v) => setState(() => _isRepeating = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.forestGreen,
                    inactiveThumbColor: Colors.grey.shade400,
                    inactiveTrackColor: Colors.grey.shade200,
                  ),
                ],
              ),
            ),

            // Repeat day selector
            if (_isRepeating) ...[
              const SizedBox(height: 20),
              _buildDaySelector(),
            ],

            const SizedBox(height: 28),

            // Save button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEdit ? 'Save Changes' : 'Create Alarm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    const days = [
      (1, 'M'),
      (2, 'T'),
      (3, 'W'),
      (4, 'T'),
      (5, 'F'),
      (6, 'S'),
      (7, 'S'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((day) {
        final selected = _repeatDays.contains(day.$1);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (selected) {
                _repeatDays.remove(day.$1);
              } else {
                _repeatDays.add(day.$1);
                _repeatDays.sort();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.forestGreen : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.forestGreen
                    : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.forestGreen.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                day.$2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
