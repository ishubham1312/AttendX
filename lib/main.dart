import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:home_widget/home_widget.dart';

import 'theme/app_theme.dart';
import 'models/attendance_status.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_storage_service.dart';
import 'services/update_service.dart';
import 'providers/app_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/update_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final alarmStorage = AlarmStorageService();
  await alarmStorage.init();

  final notifications = NotificationService();
  await notifications.init();
  unawaited(notifications.requestPermissions());

  final provider = AppProvider(storage, notifications, alarmStorage)..load();

  notifications.onAction = (profileId, actionId) async {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    await provider.setActiveProfile(profileId);
    switch (actionId) {
      case NotificationService.actionPresent:
        await provider.mark(date, AttendanceStatus.present);
        break;
      case NotificationService.actionAbsent:
        await provider.mark(date, AttendanceStatus.absent);
        break;
      case NotificationService.actionHalf:
        await provider.mark(date, AttendanceStatus.halfDay, half: HalfType.firstHalf);
        break;
    }
  };

  runApp(MyApp(provider: provider));
}

class MyApp extends StatelessWidget {
  final AppProvider provider;
  const MyApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
      ],
      child: MaterialApp(
        title: 'AttendX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: const _Entry(),
      ),
    );
  }
}

class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _pendingWidgetAction = false;
  StreamSubscription<Uri?>? _widgetSub;
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForWidgetLaunch();
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppProvider>().checkAndApplyPendingAttendance();
    }
  }

  void _checkForWidgetLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null) {
      _handleWidgetUri(uri);
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme == 'attendx' && uri.host == 'widget_action') {
      final action = uri.queryParameters['action'];
      if (action == 'mark_present') {
        if (_showSplash) {
          _pendingWidgetAction = true;
        } else {
          _showAttendanceOptionsBottomSheet(context);
        }
      }
    }
  }

  void _showAttendanceOptionsBottomSheet(BuildContext context) {
    final provider = context.read<AppProvider>();
    final active = provider.activeProfile;
    if (active == null) return;

    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                'Mark Attendance',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose an attendance status for ${active.name} today',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildOptionCard(
                      context: context,
                      label: 'Present',
                      icon: Icons.check_circle_outline,
                      color: AppColors.present,
                      onTap: () async {
                        await provider.mark(date, AttendanceStatus.present);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Marked Present today!'),
                              backgroundColor: AppColors.present,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOptionCard(
                      context: context,
                      label: 'Absent',
                      icon: Icons.highlight_off,
                      color: AppColors.absent,
                      onTap: () async {
                        await provider.mark(date, AttendanceStatus.absent);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Marked Absent today!'),
                              backgroundColor: AppColors.absent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOptionCard(
                      context: context,
                      label: 'Half Day',
                      icon: Icons.timelapse,
                      color: AppColors.halfDay,
                      onTap: () async {
                        await provider.mark(date, AttendanceStatus.halfDay,
                            half: HalfType.firstHalf);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Marked Half Day today!'),
                              backgroundColor: AppColors.halfDay,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOptionCard(
                      context: context,
                      label: 'Holiday',
                      icon: Icons.beach_access,
                      color: AppColors.holiday,
                      onTap: () async {
                        await provider.mark(date, AttendanceStatus.holiday);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Marked Holiday today!'),
                              backgroundColor: AppColors.holiday,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    Widget destination;
    if (!p.onboardingDone || p.activeProfile == null) {
      destination = const OnboardingScreen();
    } else {
      destination = const RootScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: _showSplash
          ? SplashScreen(
              key: const ValueKey('splash'),
              onDone: () async {
                setState(() => _showSplash = false);
                
                // Check for updates
                final result = await _updateService.checkForUpdate();
                if (result.status == UpdateStatus.updateAvailable && result.info != null && context.mounted) {
                  UpdateDialog.show(context, result.info!, _updateService);
                }

                if (_pendingWidgetAction) {
                  _pendingWidgetAction = false;
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (context.mounted) {
                      _showAttendanceOptionsBottomSheet(context);
                    }
                  });
                }
              },
            )
          : KeyedSubtree(
              key: const ValueKey('app'),
              child: destination,
            ),
    );
  }
}
