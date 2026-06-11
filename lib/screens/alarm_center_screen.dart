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
    return GestureDetector(
      onTap: onEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: alarm.isPrimary
              ? Border.all(
                  color: AppColors.forestGreen.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: alarm.isEnabled
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Alarm icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: alarm.isPrimary
                        ? AppColors.heroGradient
                        : null,
                    color: alarm.isPrimary
                        ? null
                        : (alarm.isEnabled
                            ? AppColors.forestGreen.withValues(alpha: 0.08)
                            : AppColors.screenBg),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    alarm.isPrimary
                        ? Icons.notifications_active_rounded
                        : Icons.alarm_rounded,
                    color: alarm.isPrimary
                        ? Colors.white
                        : (alarm.isEnabled
                            ? AppColors.forestGreen
                            : AppColors.textSubtle),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            alarm.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: alarm.isEnabled
                                  ? AppColors.textPrimary
                                  : AppColors.textSubtle,
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
                                  fontSize: 10,
                                  color: AppColors.forestGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.timeString,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: alarm.isEnabled
                              ? AppColors.textPrimary
                              : AppColors.textSubtle,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: alarm.isEnabled,
                      onChanged: onToggle,
                      activeThumbColor: AppColors.forestGreen,
                    ),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.absent,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Details row
            Row(
              children: [
                _detailChip(
                  Icons.repeat_rounded,
                  alarm.repeatLabel,
                  alarm.isEnabled,
                ),
                const SizedBox(width: 8),
                _detailChip(
                  Icons.category_outlined,
                  alarm.isPrimary ? 'Arrival Alarm' : 'Custom',
                  alarm.isEnabled,
                ),
                if (!alarm.isEnabled) ...[
                  const SizedBox(width: 8),
                  _detailChip(
                    Icons.pause_circle_outline_rounded,
                    'Inactive',
                    false,
                    color: AppColors.absent,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, bool isActive,
      {Color? color}) {
    final c = color ??
        (isActive ? AppColors.textSecondary : AppColors.textSubtle);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSubtle).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'Edit Alarm' : 'New Alarm',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Time picker
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.forestGreen.withValues(alpha: 0.15),
                  ),
                ),
                child: Center(
                  child: Text(
                    _time.format(context),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name field
            if (!isPrimary) ...[
              const Text('Alarm Name',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                decoration: softCard(radius: 14),
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Office Arrival, Break Time...',
                    hintStyle: TextStyle(color: AppColors.textSubtle),
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
              decoration: softCard(radius: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded,
                      color: AppColors.forestGreen, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Repeat',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: _isRepeating,
                    onChanged: (v) => setState(() => _isRepeating = v),
                    activeThumbColor: AppColors.forestGreen,
                  ),
                ],
              ),
            ),

            // Repeat day selector
            if (_isRepeating) ...[
              const SizedBox(height: 16),
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
                      borderRadius: BorderRadius.circular(27)),
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
                            fontSize: 16, fontWeight: FontWeight.w700),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  selected ? AppColors.forestGreen : AppColors.screenBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.forestGreen
                    : AppColors.shadowDark,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                day.$2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
