import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // For ImageFilter to implement glassmorphism
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'dashboard_screen.dart';
import 'profiles_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  late final PageController _pageController;

  final _screens = const [
    HomeScreen(),
    HistoryScreen(),
    DashboardScreen(),
    ProfilesScreen(),
  ];

  final _icons = const [
    Icons.home_rounded,
    Icons.calendar_month_rounded,
    Icons.insights_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void goToTab(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _onTabTapped(int i) {
    HapticFeedback.selectionClick();
    goToTab(i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // By using Stack inside Scaffold body and positioning the custom bottom navigation bar
      // as an overlay, we completely bypass Scaffold's default bottom navigation container,
      // ensuring that no solid background box covers the screen content behind the pill.
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) {
              if (i != _index) {
                setState(() => _index = i);
              }
            },
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AnimatedBottomNav(
              index: _index,
              icons: _icons,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating pill nav bar with a smoothly sliding green active indicator and flowy glassmorphism.
class _AnimatedBottomNav extends StatelessWidget {
  final int index;
  final List<IconData> icons;
  final ValueChanged<int> onTap;

  const _AnimatedBottomNav({
    required this.index,
    required this.icons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double barHorizontalMargin = 48; // Adjusted margin for a modern, flowy pill width
    const double innerPadding = 8;
    const double circleSize = 48;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            barHorizontalMargin, 0, barHorizontalMargin, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: innerPadding, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final n = icons.length;
                  final totalWidth = constraints.maxWidth;
                  final slotWidth = totalWidth / n;
                  final indicatorLeft =
                      index * slotWidth + (slotWidth - circleSize) / 2;

                  return SizedBox(
                    height: circleSize,
                    child: Stack(
                      children: [
                        // Sliding indicator with a premium gradient matching the app's visual system
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          left: indicatorLeft,
                          top: 0,
                          child: Container(
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.forestGreen.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Icons row
                        Row(
                          children: List.generate(n, (i) {
                            final active = i == index;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => onTap(i),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                        begin: 1, end: active ? 1.1 : 0.9),
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, scale, child) =>
                                        Transform.scale(scale: scale, child: child),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 150),
                                      child: Icon(
                                        icons[i],
                                        key: ValueKey('$i-$active'),
                                        color: active
                                            ? Colors.white
                                            : AppColors.textSubtle,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
