import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';

import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/widget_previews.dart';
import 'profile_setup_screen.dart';
import 'alarm_center_screen.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _animCtrl;
  final String _previewStatus = 'present';

  @override
  bool get wantKeepAlive => true;

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

  Future<void> _pinWidget({
    required String name,
    required String androidName,
    required String qualifiedAndroidName,
  }) async {
    try {
      final bool? isSupported = await HomeWidget.isRequestPinWidgetSupported();
      if (isSupported == true) {
        await HomeWidget.requestPinWidget(
          name: name,
          androidName: androidName,
          qualifiedAndroidName: qualifiedAndroidName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Widget pinning request sent!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Direct widget pinning is not supported by your launcher. Please add it from your launcher widgets menu.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error adding widget: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppProvider>();
    final profiles = provider.profiles;
    final active = provider.activeProfile;

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

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header Row
          animatedItem(
            0,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // Alarm center button
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AlarmCenterScreen(),
                      ),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.forestGreen.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.forestGreen,
                        size: 22,
                      ),
                    ),
                  ),
                  // Add profile button
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileSetupScreen(),
                      ),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.vibrantGreen.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              physics: const BouncingScrollPhysics(),
              children: [
                // Profiles List
                ...List.generate(profiles.length, (i) {
                  final p = profiles[i];
                  final isActive = p.id == active?.id;
                  return animatedItem(
                    i + 1,
                    GestureDetector(
                      onTap: () => provider.setActiveProfile(p.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppColors.forestGreen
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isActive
                                  ? AppColors.forestGreen.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: isActive ? AppColors.heroGradient : null,
                                color: isActive ? null : AppColors.screenBg,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.forestGreen
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 11,
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
                                    p.role,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: AppColors.textSubtle),
                              elevation: 8,
                              shadowColor: Colors.black.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              onSelected: (v) {
                                if (v == 'edit') {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileSetupScreen(existing: p),
                                  ));
                                } else if (v == 'delete') {
                                  _confirmDelete(context, provider, p.id,
                                      p.name, profiles.length);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit Profile')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Profile',
                                      style:
                                          TextStyle(color: AppColors.absent)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Widgets Section
                const SizedBox(height: 16),
                animatedItem(
                  profiles.length + 1,
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home Screen Widgets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Preview your interactive widgets below, then pin them to your home screen.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (active == null)
                  animatedItem(
                    profiles.length + 3,
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          'Please select or add an active profile to view widget previews.',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else ...[
                  _buildWidgetPreviewItem(
                    index: profiles.length + 3,
                    title: '1x1 Widget',
                    subtitle: 'Quick Status Button',
                    previewWidget: Center(
                      child: SizedBox(
                        width: 115,
                        height: 115,
                        child: Widget1x1Preview(
                          status: _previewStatus,
                          time: '09:02 AM',
                        ),
                      ),
                    ),
                    onPin: () => _pinWidget(
                      name: 'WidgetProvider1x1',
                      androidName: 'WidgetProvider1x1',
                      qualifiedAndroidName:
                          'com.attendancetracker.attend.WidgetProvider1x1',
                    ),
                  ),
                  _buildWidgetPreviewItem(
                    index: profiles.length + 4,
                    title: '2x1 Widget',
                    subtitle: 'Status & Monthly Summary',
                    previewWidget: Center(
                      child: SizedBox(
                        width: 250,
                        child: Widget2x1Preview(
                          status: _previewStatus,
                          time: '09:02 AM',
                          dateStr: DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                          scoreStr:
                              '${provider.stats(month: DateTime.now()).percentage.toStringAsFixed(1)}%',
                        ),
                      ),
                    ),
                    onPin: () => _pinWidget(
                      name: 'WidgetProvider2x1',
                      androidName: 'WidgetProvider2x1',
                      qualifiedAndroidName:
                          'com.attendancetracker.attend.WidgetProvider2x1',
                    ),
                  ),
                  _buildWidgetPreviewItem(
                    index: profiles.length + 5,
                    title: '2x2 Widget',
                    subtitle: 'Comprehensive Scoreboard',
                    previewWidget: Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Widget2x2Preview(
                          name: active.name,
                          status: _previewStatus,
                          time: '09:02 AM',
                          presentCount: provider
                              .stats(month: DateTime.now())
                              .presentDays
                              .toString(),
                          halfDayCount: provider
                              .stats(month: DateTime.now())
                              .halfDays
                              .toString(),
                          absentCount: provider
                              .stats(month: DateTime.now())
                              .absentDays
                              .toString(),
                          scoreStr:
                              '${provider.stats(month: DateTime.now()).percentage.toStringAsFixed(1)}%',
                        ),
                      ),
                    ),
                    onPin: () => _pinWidget(
                      name: 'WidgetProvider2x2',
                      androidName: 'WidgetProvider2x2',
                      qualifiedAndroidName:
                          'com.attendancetracker.attend.WidgetProvider2x2',
                    ),
                  ),
                  _buildWidgetPreviewItem(
                    index: profiles.length + 6,
                    title: '4x2 Widget',
                    subtitle: 'Detailed Tracker & Salary Estimator',
                    previewWidget: Widget4x2Preview(
                      status: _previewStatus,
                      time: '09:02 AM',
                      monthYear: DateFormat('MMMM yyyy').format(DateTime.now()),
                      presentCount: provider
                          .stats(month: DateTime.now())
                          .presentDays
                          .toString(),
                      halfDayCount: provider
                          .stats(month: DateTime.now())
                          .halfDays
                          .toString(),
                      absentCount: provider
                          .stats(month: DateTime.now())
                          .absentDays
                          .toString(),
                      earnedSalary:
                          NumberFormat.currency(symbol: '₹', decimalDigits: 0)
                              .format(provider
                                  .stats(month: DateTime.now())
                                  .earnedSalary)
                              .trim(),
                      estimatedSalary:
                          NumberFormat.currency(symbol: '₹', decimalDigits: 0)
                              .format(active.monthlySalary)
                              .trim(),
                      progress: active.monthlySalary == 0
                          ? 0
                          : ((provider
                                          .stats(month: DateTime.now())
                                          .earnedSalary /
                                      active.monthlySalary) *
                                  100)
                              .round()
                              .clamp(0, 100),
                    ),
                    onPin: () => _pinWidget(
                      name: 'WidgetProvider4x2',
                      androidName: 'WidgetProvider4x2',
                      qualifiedAndroidName:
                          'com.attendancetracker.attend.WidgetProvider4x2',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, String id,
      String name, int total) {
    if (total <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('You need at least one profile.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Profile?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'This will permanently delete $name and all of their historical attendance logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteProfile(id);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.absent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetPreviewItem({
    required int index,
    required String title,
    required String subtitle,
    required Widget previewWidget,
    required VoidCallback onPin,
  }) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1.0 - curve.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            previewWidget,
          ],
        ),
      ),
    );
  }
}
