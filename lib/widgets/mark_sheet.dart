import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/attendance_status.dart';
import '../providers/app_provider.dart';

/// Animated bottom sheet for marking attendance, including First/Second Half
/// selection when Half Day is chosen.
class MarkSheet extends StatefulWidget {
  final DateTime date;
  final AttendanceEntry? current;
  const MarkSheet({super.key, required this.date, this.current});

  static Future<void> show(
      BuildContext context, DateTime date, AttendanceEntry? current) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MarkSheet(date: date, current: current),
    );
  }

  @override
  State<MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends State<MarkSheet> with SingleTickerProviderStateMixin {
  bool _showHalfOptions = false;

  @override
  void initState() {
    super.initState();
    _showHalfOptions = widget.current?.status == AttendanceStatus.halfDay;
  }

  void _mark(AttendanceStatus status, {HalfType? half}) {
    HapticFeedback.lightImpact();
    context.read<AppProvider>().mark(widget.date, status, half: half);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final current = widget.current;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.shadowDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(DateFormat('EEEE, MMM dd').format(widget.date),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _option(
            AttendanceStatus.present,
            Icons.check_rounded,
            AppColors.present,
            active: current?.status == AttendanceStatus.present,
            onTap: () => _mark(AttendanceStatus.present),
          ),
          _option(
            AttendanceStatus.halfDay,
            Icons.timelapse_rounded,
            AppColors.halfDay,
            active: current?.status == AttendanceStatus.halfDay,
            trailing: AnimatedRotation(
              turns: _showHalfOptions ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSubtle),
            ),
            onTap: () => setState(() => _showHalfOptions = !_showHalfOptions),
          ),
          // First / Second half animated reveal
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _showHalfOptions
                ? Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 12),
                    child: Row(
                      children: [
                        _halfChip(HalfType.firstHalf,
                            current?.half == HalfType.firstHalf),
                        const SizedBox(width: 10),
                        _halfChip(HalfType.secondHalf,
                            current?.half == HalfType.secondHalf),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _option(
            AttendanceStatus.absent,
            Icons.close_rounded,
            AppColors.absent,
            active: current?.status == AttendanceStatus.absent,
            onTap: () => _mark(AttendanceStatus.absent),
          ),
          if (widget.date.weekday != DateTime.sunday)
            _option(
              AttendanceStatus.holiday,
              Icons.beach_access_rounded,
              AppColors.holiday,
              active: current?.status == AttendanceStatus.holiday,
              onTap: () => _mark(AttendanceStatus.holiday),
            ),
          if (current != null)
            TextButton(
              onPressed: () {
                provider.clear(widget.date);
                Navigator.pop(context);
              },
              child: const Text('Clear mark',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _halfChip(HalfType half, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _mark(AttendanceStatus.halfDay, half: half),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active
                ? AppColors.halfDay.withValues(alpha: 0.15)
                : AppColors.screenBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppColors.halfDay : Colors.transparent,
                width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                half == HalfType.firstHalf
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_outlined,
                size: 18,
                color: active ? AppColors.halfDay : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(half.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          active ? AppColors.halfDay : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(
    AttendanceStatus s,
    IconData icon,
    Color color, {
    required bool active,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : AppColors.screenBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Text(s.label,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            if (trailing != null)
              trailing
            else if (active)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}
