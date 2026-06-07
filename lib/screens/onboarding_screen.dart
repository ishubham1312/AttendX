import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// For ImageFilter to implement glassmorphism

import '../theme/app_theme.dart';
import '../widgets/shield_logo.dart';
import '../providers/app_provider.dart';
import 'profile_setup_screen.dart';
// import '../widgets/glass_card.dart'; // Import GlassCard

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardData(
      title: 'Attendance Made\nEffortless',
      subtitle: 'Track your daily attendance with a single tap.',
    ),
    _OnboardData(
      title: 'Never Miss\na Day',
      subtitle: 'Get daily reminders to mark Present, Absent or Half Day.',
    ),
    _OnboardData(
      title: 'Know Your\nEarnings',
      subtitle: 'See attendance stats and estimated salary instantly.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    final provider = context.read<AppProvider>();
    if (provider.profiles.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileSetupScreen(isFirst: true),
        ),
      );
    } else {
      provider.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final d = _pages[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ShieldLogo(size: 130),
                      const SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          d.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          d.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.forestGreen
                        : AppColors.forestGreen.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen, // Premium Forest green button
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _next,
                  child: Center(
                    child: Text(
                      _page == _pages.length - 1 ? 'Get started' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardData {
  final String title;
  final String subtitle;
  const _OnboardData({required this.title, required this.subtitle});
}
