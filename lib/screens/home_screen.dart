import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../models/attendance_status.dart';
import '../providers/app_provider.dart';
import '../widgets/mark_sheet.dart';
import '../widgets/user_switcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late Timer _timer;
  DateTime _now = DateTime.now();
  late final AnimationController _rippleCtrl;
  late final AnimationController _introCtrl;
  late final AnimationController _glowCtrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _timer.cancel();
    _rippleCtrl.dispose();
    _introCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = _now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _greetingEmoji() {
    final h = _now.hour;
    if (h < 12) return '☀️';
    if (h < 17) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppProvider>();
    final profile = provider.activeProfile!;
    final today = DateTime(_now.year, _now.month, _now.day);
    final isSunday = today.weekday == DateTime.sunday;
    final isHoliday = provider.isHolidayDate(today);
    final isDayOff = (isSunday || isHoliday) && !provider.isManuallyMarked(today);
    final entry = provider.isManuallyMarked(today)
        ? provider.entryFor(today)
        : (isDayOff ? AttendanceEntry(AttendanceStatus.holiday, null) : provider.entryFor(today));

    Widget animatedItem(int index, Widget child) {
      final start = (index * 0.10).clamp(0.0, 1.0);
      final end = (start + 0.45).clamp(0.0, 1.0);
      final anim = CurvedAnimation(
        parent: _introCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
      return AnimatedBuilder(
        animation: anim,
        builder: (_, c) => Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - anim.value)),
            child: c,
          ),
        ),
        child: child,
      );
    }

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            animatedItem(
              0,
              Container(
                padding: const EdgeInsets.all(18),
                decoration: glassCard(radius: 22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()} ${_greetingEmoji()}',
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile.role,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forestGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        UserSwitcher.show(context);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.forestGreen
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                profile.name.isNotEmpty
                                    ? profile.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.swap_horiz,
                                  size: 12,
                                  color: AppColors.forestGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Time display
            animatedItem(
              1,
              Center(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        DateFormat('hh:mm').format(_now),
                        key: ValueKey(DateFormat('hh:mm').format(_now)),
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('a').format(_now),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forestGreen
                                  .withValues(alpha: 0.7)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.textSubtle,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEE, MMM dd').format(_now),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Mark button
            animatedItem(
              2,
              Center(
                child: _ConcentricButton(
                  entry: entry,
                  isDayOff: isDayOff,
                  isSunday: isSunday,
                  rippleCtrl: _rippleCtrl,
                  glowCtrl: _glowCtrl,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    MarkSheet.show(context, today, provider.isManuallyMarked(today) ? entry : null);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ConcentricButton extends StatefulWidget {
  final AttendanceEntry? entry;
  final bool isDayOff;
  final bool isSunday;
  final AnimationController rippleCtrl;
  final AnimationController glowCtrl;
  final VoidCallback onTap;
  const _ConcentricButton({
    required this.entry,
    required this.isDayOff,
    required this.isSunday,
    required this.rippleCtrl,
    required this.glowCtrl,
    required this.onTap,
  });

  @override
  State<_ConcentricButton> createState() => _ConcentricButtonState();
}

class _ConcentricButtonState extends State<_ConcentricButton>
    with TickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _markRippleCtrl;
  AttendanceStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _lastStatus = widget.entry?.status;
    _markRippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didUpdateWidget(_ConcentricButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newStatus = widget.entry?.status;
    if (newStatus != _lastStatus) {
      if (newStatus != null) {
        _markRippleCtrl.forward(from: 0.0);
      }
      _lastStatus = newStatus;
    }
  }

  @override
  void dispose() {
    _markRippleCtrl.dispose();
    super.dispose();
  }

  AttendanceEntry? get entry => widget.entry;
  AnimationController get rippleCtrl => widget.rippleCtrl;

  Color get _centerColor {
    switch (entry?.status) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.halfDay:
        return AppColors.halfDay;
      case AttendanceStatus.holiday:
        return AppColors.holiday;
      case null:
        return AppColors.screenBg;
    }
  }

  String get _label {
    if (entry == null) return 'Mark';
    if (widget.isDayOff && entry!.status == AttendanceStatus.holiday) {
      return widget.isSunday ? 'Sunday' : 'Holiday';
    }
    if (entry!.status == AttendanceStatus.halfDay) {
      return entry!.half == HalfType.secondHalf ? '2nd Half' : '1st Half';
    }
    return entry!.status.label;
  }

  IconData get _icon {
    switch (entry?.status) {
      case AttendanceStatus.present:
        return Icons.check_rounded;
      case AttendanceStatus.absent:
        return Icons.close_rounded;
      case AttendanceStatus.halfDay:
        return Icons.timelapse_rounded;
      case AttendanceStatus.holiday:
        return Icons.beach_access_rounded;
      case null:
        return Icons.touch_app_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final marked = entry != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Flowing color ripple animation (dual ripple)
              AnimatedBuilder(
                animation: _markRippleCtrl,
                builder: (context, child) {
                  if (!_markRippleCtrl.isAnimating &&
                      _markRippleCtrl.value == 0) {
                    return const SizedBox.shrink();
                  }

                  Color color;
                  switch (widget.entry?.status) {
                    case AttendanceStatus.present:
                      color = AppColors.present;
                      break;
                    case AttendanceStatus.absent:
                      color = AppColors.absent;
                      break;
                    case AttendanceStatus.halfDay:
                      color = AppColors.halfDay;
                      break;
                    case AttendanceStatus.holiday:
                      color = AppColors.holiday;
                      break;
                    default:
                      color = Colors.transparent;
                  }

                  if (color == Colors.transparent) return const SizedBox.shrink();

                  return Stack(
                    alignment: Alignment.center,
                    children: List.generate(2, (index) {
                      // Offset the second ripple slightly in time
                      final delay = index * 0.15;
                      final progress =
                          (_markRippleCtrl.value - delay).clamp(0.0, 1.0);
                      if (progress == 0.0 || progress == 1.0) {
                        return const SizedBox.shrink();
                      }

                      final opacity = (1.0 - progress) * 0.12;
                      final size = 120.0 + (progress * 780.0);

                      return Opacity(
                        opacity: opacity,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              // Pulsing glow when not marked
              if (!marked)
                AnimatedBuilder(
                  animation: widget.glowCtrl,
                  builder: (_, __) => Container(
                    width: 220 + widget.glowCtrl.value * 20,
                    height: 220 + widget.glowCtrl.value * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.vibrantGreen.withValues(
                              alpha: 0.1 + widget.glowCtrl.value * 0.08),
                          blurRadius: 40 + widget.glowCtrl.value * 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              // Animated expanding ripples when not marked
              if (!marked)
                AnimatedBuilder(
                  animation: rippleCtrl,
                  builder: (_, __) {
                    return Stack(
                      alignment: Alignment.center,
                      children: List.generate(3, (i) {
                        final t = (rippleCtrl.value + i / 3) % 1.0;
                        return Opacity(
                          opacity: (1 - t) * 0.35,
                          child: Container(
                            width: 150 + t * 160,
                            height: 150 + t * 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.vibrantGreen
                                      .withValues(alpha: 0.5),
                                  width: 2),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              // Neumorphic concentric rings
              Container(
                width: 300,
                height: 300,
                decoration:
                    neumorphic(radius: 150, color: AppColors.screenBg),
              ),
              Container(
                width: 230,
                height: 230,
                decoration:
                    neumorphic(radius: 115, color: AppColors.screenBg),
              ),
              Container(
                width: 170,
                height: 170,
                decoration:
                    neumorphic(radius: 85, color: AppColors.screenBg),
              ),
              // Center status circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: marked ? 130 : 120,
                height: marked ? 130 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: marked ? _centerColor : AppColors.screenBg,
                  boxShadow: marked
                      ? [
                          BoxShadow(
                            color: _centerColor.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color:
                                AppColors.shadowDark.withValues(alpha: 0.1),
                            offset: const Offset(4, 4),
                            blurRadius: 22,
                          ),
                          const BoxShadow(
                            color: AppColors.shadowLight,
                            offset: Offset(-4, -4),
                            blurRadius: 22,
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Icon(
                        _icon,
                        key: ValueKey(_icon),
                        color:
                            marked ? Colors.white : AppColors.textSecondary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _label,
                      style: TextStyle(
                        color:
                            marked ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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
}



