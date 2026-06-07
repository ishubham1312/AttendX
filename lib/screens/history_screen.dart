import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/attendance_status.dart';
import '../providers/app_provider.dart';
import '../widgets/mark_sheet.dart';

enum CalView { monthly, weekly }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  CalView _view = CalView.monthly;
  DateTime _selected = DateTime.now();

  static const int _base = 5000;
  late final DateTime _refMonth;
  late final DateTime _refWeekStart;

  late PageController _monthController;
  late PageController _weekController;

  int _monthIndex = _base;
  int _weekIndex = _base;

  late final AnimationController _animCtrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _refMonth = DateTime(now.year, now.month);
    _refWeekStart = _startOfWeek(now);
    _monthController = PageController(initialPage: _base);
    _weekController = PageController(initialPage: _base);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _monthController.dispose();
    _weekController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    final offset = date.weekday % 7; // Sun=0
    return date.subtract(Duration(days: offset));
  }

  DateTime _monthForIndex(int index) =>
      DateTime(_refMonth.year, _refMonth.month + (index - _base));

  DateTime _weekStartForIndex(int index) =>
      _refWeekStart.add(Duration(days: 7 * (index - _base)));

  void _toggleView(CalView v) {
    if (_view == v) return;
    HapticFeedback.selectionClick();
    setState(() => _view = v);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppProvider>();
    final headerDate = _view == CalView.monthly
        ? _monthForIndex(_monthIndex)
        : _weekStartForIndex(_weekIndex);

    final showTodayBtn = _view == CalView.monthly
        ? _monthIndex != _base
        : _weekIndex != _base;

    Widget animatedItem(int index, Widget child) {
      final start = (index * 0.1).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      final anim = CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
      return AnimatedBuilder(
        animation: anim,
        builder: (_, c) => Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - anim.value)),
            child: c,
          ),
        ),
        child: child,
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header with view controls
          animatedItem(
            0,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _circleBtn(Icons.chevron_left, () => _step(-1)),
                  const Spacer(),
                  const Text(
                    'History',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5),
                  ),
                  const Spacer(),
                  _circleBtn(Icons.chevron_right, () => _step(1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          animatedItem(
            1,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _view == CalView.monthly
                              ? DateFormat('MMMM yyyy').format(headerDate)
                              : _weekLabel(headerDate),
                          key: ValueKey('$_view-$headerDate'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (showTodayBtn) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _jumpToToday,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.forestGreen.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.today,
                                    size: 13, color: AppColors.forestGreen),
                                SizedBox(width: 4),
                                Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _viewToggle(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          animatedItem(2, _weekdayHeader()),
          const SizedBox(height: 8),

          // Nested PageView only for the calendar cards
          animatedItem(
            3,
            SizedBox(
              height: _view == CalView.monthly ? 336 : 96,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                reverseDuration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutQuad,
                switchOutCurve: Curves.easeInQuad,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: _view == CalView.monthly
                    ? _monthlyPager(provider)
                    : _weeklyPager(provider),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rest of content directly in column so horizontal swipes here fall back to RootScreen PageView
          if (_view == CalView.weekly) ...[
            animatedItem(4, _weekSummary(provider, headerDate)),
            const SizedBox(height: 16),
          ],
          animatedItem(5, _legend()),
        ],
      ),
    );
  }

  void _jumpToToday() {
    HapticFeedback.mediumImpact();
    setState(() {
      _selected = DateTime.now();
    });
    if (_view == CalView.monthly) {
      _monthController.animateToPage(
        _base,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _weekController.animateToPage(
        _base,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _step(int delta) {
    HapticFeedback.selectionClick();
    if (_view == CalView.monthly) {
      _monthController.animateToPage(
        _monthIndex + delta,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _weekController.animateToPage(
        _weekIndex + delta,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    if (weekStart.month == end.month) {
      return '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('dd').format(end)}';
    }
    return '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd').format(end)}';
  }

  Widget _viewToggle() {
    Widget seg(String text, CalView v) {
      final active = _view == v;
      return GestureDetector(
        onTap: () => _toggleView(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.forestGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.forestGreen.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          seg('Monthly', CalView.monthly),
          seg('Weekly', CalView.weekly),
        ],
      ),
    );
  }

  Widget _weekdayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSubtle)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ---- Monthly ----
  Widget _monthlyPager(AppProvider provider) {
    return PageView.builder(
      key: const ValueKey('monthly'),
      controller: _monthController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() => _monthIndex = i);
      },
      itemBuilder: (_, index) {
        final month = _monthForIndex(index);
        return _buildMonthGrid(provider, month);
      },
    );
  }

  Widget _buildMonthGrid(AppProvider provider, DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: softCard(radius: 24),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (_, index) {
            if (index < startWeekday) return const SizedBox();
            final day = index - startWeekday + 1;
            final date = DateTime(month.year, month.month, day);
            return _dayCell(provider, date);
          },
        ),
      ),
    );
  }

  // ---- Weekly ----
  Widget _weeklyPager(AppProvider provider) {
    return PageView.builder(
      key: const ValueKey('weekly'),
      controller: _weekController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() => _weekIndex = i);
      },
      itemBuilder: (_, index) {
        final weekStart = _weekStartForIndex(index);
        return _buildWeekRow(provider, weekStart);
      },
    );
  }

  Widget _buildWeekRow(AppProvider provider, DateTime weekStart) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: softCard(radius: 24),
        child: Row(
          children: List.generate(7, (i) {
            final date = weekStart.add(Duration(days: i));
            return Expanded(child: _dayCell(provider, date, tall: true));
          }),
        ),
      ),
    );
  }

  Widget _weekSummary(AppProvider provider, DateTime weekStart) {
    int present = 0, half = 0, absent = 0;
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final s = provider.effectiveStatusFor(date);
      if (s == AttendanceStatus.present || s == AttendanceStatus.holiday) present++;
      if (s == AttendanceStatus.halfDay) half++;
      if (s == AttendanceStatus.absent) absent++;
    }
    Widget chip(String label, int v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: softCard(radius: 18),
            child: Column(
              children: [
                Text('$v',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          chip('Present', present, AppColors.present),
          chip('Half Day', half, AppColors.halfDay),
          chip('Absent', absent, AppColors.absent),
        ],
      ),
    );
  }

  Widget _dayCell(AppProvider provider, DateTime date, {bool tall = false}) {
    final isSunday = date.weekday == DateTime.sunday;
    final isManuallyMarked = provider.isManuallyMarked(date);
    final entry = (isSunday && !isManuallyMarked) ? null : provider.entryFor(date);
    final status = entry?.status;
    final isSelected = _isSameDay(date, _selected);
    final isFuture = date.isAfter(DateTime.now());
    final isToday = _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selected = date);
              MarkSheet.show(context, date, entry);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: tall ? 68 : null,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _bgFor(status, isSelected, date, provider),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.forestGreen, width: 2.5)
              : (isToday && status == null
                  ? Border.all(
                      color: AppColors.forestGreen.withValues(alpha: 0.5),
                      width: 1.5)
                  : null),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.forestGreen.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tall) ...[
                    Text(DateFormat('E').format(date).substring(0, 1),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: status != null
                                ? Colors.white70
                                : (isSunday && !isManuallyMarked
                                    ? Colors.red.withValues(alpha: 0.7)
                                    : AppColors.textSubtle))),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: _textFor(status, isFuture, date, provider),
                      fontWeight:
                          status != null ? FontWeight.w800 : FontWeight.w600,
                      fontSize: tall ? 15 : 14,
                    ),
                  ),
                ],
              ),
            ),
            if (status == AttendanceStatus.halfDay)
              Positioned(
                right: 6,
                top: 6,
                child: Icon(
                  entry!.half == HalfType.secondHalf
                      ? Icons.nightlight_outlined
                      : Icons.wb_sunny_outlined,
                  size: 9,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text(t,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: softCard(radius: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Center(child: item(AppColors.present, 'Present'))),
              Expanded(child: Center(child: item(AppColors.absent, 'Absent'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Center(child: item(AppColors.halfDay, 'Half Day'))),
              Expanded(child: Center(child: item(AppColors.holiday, 'Holiday'))),
            ],
          ),
        ],
      ),
    );
  }

  Color _bgFor(AttendanceStatus? s, bool selected, DateTime date, AppProvider provider) {
    if (date.weekday == DateTime.sunday && !provider.isManuallyMarked(date)) {
      return selected ? Colors.white : Colors.transparent;
    }
    switch (s) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.halfDay:
        return AppColors.halfDay;
      case AttendanceStatus.holiday:
        return AppColors.holiday;
      case null:
        return selected ? Colors.white : Colors.transparent;
    }
  }

  Color _textFor(AttendanceStatus? s, bool future, DateTime date, AppProvider provider) {
    if (date.weekday == DateTime.sunday && !provider.isManuallyMarked(date)) {
      if (future) return Colors.red.withValues(alpha: 0.35);
      return Colors.red;
    }
    if (future) return AppColors.textSubtle.withValues(alpha: 0.35);
    if (s != null) return Colors.white;
    return AppColors.textPrimary;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}
