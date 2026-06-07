import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/progress_bar.dart';
import '../widgets/animated_count.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool? _animate;
  late final AnimationController _staggerCtrl;
  bool _isSalaryExpanded = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  String _money(double v) {
    final f = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return f.format(v).trim();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppProvider>();
    final profile = provider.activeProfile!;
    final monthStats = provider.stats(month: _selectedMonth);
    final overall = provider.stats();
    final hasSalary = profile.monthlySalary > 0;



    if (_animate == null) {
      _animate = !provider.dashboardStatsPlayed;
      if (_animate == true) {
        provider.dashboardStatsPlayed = true;
      }
    }
    final animate = _animate ?? false;

    Widget animatedItem(int index, Widget child) {
      final start = (index * 0.1).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      final anim = CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            animatedItem(
              0,
              const Center(
                child: Column(
                  children: [
                    Text('Dashboard',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5)),
                    SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            animatedItem(
              0,
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${profile.name} · ${profile.role}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestGreen),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Percentage hero card
            animatedItem(
              1,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestGreen.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase(),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          AnimatedCount(
                            value: monthStats.percentage,
                            animate: animate,
                            decimals: 1,
                            suffix: '%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1),
                          ),
                          const SizedBox(height: 2),
                          const Text('Attendance Score',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    _PercentRing(
                        percent: monthStats.percentage, animate: animate),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Monthly stat tiles with month picker
            animatedItem(
              2,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3),
                  ),
                  GestureDetector(
                    onTap: () => _showMonthPicker(context, profile.startDate),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.forestGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.forestGreen,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            animatedItem(
              2,
              Row(
                children: [
                  _statTile('Present', monthStats.presentDays, AppColors.present,
                      Icons.check_circle_outline_rounded, animate),
                  const SizedBox(width: 12),
                  _statTile('Half Day', monthStats.halfDays, AppColors.halfDay,
                      Icons.timelapse_rounded, animate),
                  const SizedBox(width: 12),
                  _statTile('Absent', monthStats.absentDays, AppColors.absent,
                      Icons.cancel_outlined, animate),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Salary section
            if (hasSalary) ...[
              animatedItem(3, const _SectionTitle('Salary & Earnings')),
              const SizedBox(height: 12),
               animatedItem(
                3,
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isSalaryExpanded = !_isSalaryExpanded);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(22),
                    decoration: softCard(radius: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Earned to Date',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary)),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _isSalaryExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: AppColors.textSubtle,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _money(monthStats.earnedSalary),
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.forestGreen,
                                      letterSpacing: -0.5),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Base Salary',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Text(
                                  _money(profile.monthlySalary),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        GradientProgressBar(
                          value: profile.monthlySalary == 0
                              ? 0
                              : monthStats.earnedSalary / profile.monthlySalary,
                          height: 12,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _salaryMini('Estimated Full',
                                _money(monthStats.estimatedFullSalary)),
                            Container(width: 1, height: 30, color: AppColors.shadowDark),
                            const SizedBox(width: 16),
                            _salaryMini('Total Deductions',
                                _money(monthStats.deduction),
                                color: AppColors.absent),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _isSalaryExpanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    const Divider(height: 1, thickness: 1, color: AppColors.screenBg),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Salary Calculation Details',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 12),
                                    _calcRow(
                                      'Daily Rate',
                                      '${_money(profile.monthlySalary)} ÷ 30 days = ${_money(profile.monthlySalary / 30)}/day',
                                    ),
                                    _calcRow(
                                      'Payable Days',
                                      '${monthStats.presentDays} Present + ${monthStats.halfDays} Half Day (×0.5) = ${(monthStats.presentDays + monthStats.halfDays * 0.5).toStringAsFixed(1)} days',
                                    ),
                                    _calcRow(
                                      'Earned Salary',
                                      '${(monthStats.presentDays + monthStats.halfDays * 0.5).toStringAsFixed(1)} days × ${_money(profile.monthlySalary / 30)} = ${_money(monthStats.earnedSalary)}',
                                      isGreen: true,
                                    ),
                                    _calcRow(
                                      'Deductions',
                                      '${monthStats.absentDays} Absent + ${monthStats.halfDays} Half Day (×0.5) = ${(monthStats.absentDays + monthStats.halfDays * 0.5).toStringAsFixed(1)} days × ${_money(profile.monthlySalary / 30)} = ${_money(monthStats.deduction)}',
                                      isRed: monthStats.deduction > 0,
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              animatedItem(
                3,
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: softCard(radius: 20),
                  child: const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.textSubtle, size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Add a monthly salary in your profile to track daily earnings.',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Overall summary
            animatedItem(4, const _SectionTitle('Overall History')),
            const SizedBox(height: 12),
            animatedItem(
              4,
              Container(
                padding: const EdgeInsets.all(22),
                decoration: softCard(radius: 22),
                child: Column(
                  children: [
                    _overallRow('Total Present', '${overall.presentDays} Days',
                        AppColors.present),
                    const Divider(height: 24, thickness: 1, color: AppColors.screenBg),
                    _overallRow('Total Half Days', '${overall.halfDays} Days',
                        AppColors.halfDay),
                    const Divider(height: 24, thickness: 1, color: AppColors.screenBg),
                    _overallRow('Total Absent', '${overall.absentDays} Days',
                        AppColors.absent),
                    const Divider(height: 24, thickness: 1, color: AppColors.screenBg),
                    _overallRow(
                        'Overall Percentage',
                        '${overall.percentage.toStringAsFixed(1)}%',
                        AppColors.forestGreen),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, DateTime profileStartDate) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    const minYear = 2020;
    int pickerYear = _selectedMonth.year;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
            ];

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.textSubtle.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Year selector row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: pickerYear > minYear
                            ? () => setSheetState(() => pickerYear--)
                            : null,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: pickerYear > minYear
                              ? AppColors.textPrimary
                              : AppColors.textSubtle.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        '$pickerYear',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      IconButton(
                        onPressed: pickerYear < currentYear
                            ? () => setSheetState(() => pickerYear++)
                            : null,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: pickerYear < currentYear
                              ? AppColors.textPrimary
                              : AppColors.textSubtle.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      final monthNum = i + 1;
                      final isFuture = pickerYear > currentYear ||
                          (pickerYear == currentYear && monthNum > currentMonth);
                      final isSelected = pickerYear == _selectedMonth.year &&
                          monthNum == _selectedMonth.month;

                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedMonth = DateTime(pickerYear, monthNum);
                                  _isSalaryExpanded = false;
                                });
                                Navigator.pop(ctx);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.forestGreen
                                : isFuture
                                    ? AppColors.screenBg
                                    : AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.forestGreen
                                  : isFuture
                                      ? Colors.transparent
                                      : AppColors.shadowDark,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            months[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : isFuture
                                      ? AppColors.textSubtle.withValues(alpha: 0.4)
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statTile(
      String label, int value, Color color, IconData icon, bool animate) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: softCard(radius: 18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            AnimatedCount(
              value: value.toDouble(),
              animate: animate,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _overallRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _salaryMini(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSubtle)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool isGreen = false, bool isRed = false}) {
    Color valColor = AppColors.textPrimary;
    if (isGreen) valColor = AppColors.forestGreen;
    if (isRed) valColor = AppColors.absent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: (isGreen || isRed) ? FontWeight.w700 : FontWeight.w500,
                color: valColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3));
  }
}

class _PercentRing extends StatelessWidget {
  final double percent;
  final bool animate;
  const _PercentRing({required this.percent, this.animate = false});
  @override
  Widget build(BuildContext context) {
    final target = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: animate
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: target),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.lime),
                    ),
                  )
                : CircularProgressIndicator(
                    value: target,
                    strokeWidth: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(AppColors.lime),
                  ),
          ),
          const Icon(Icons.verified_user_rounded, color: AppColors.lime, size: 28),
        ],
      ),
    );
  }
}
