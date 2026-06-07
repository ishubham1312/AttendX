import 'package:flutter/material.dart';

/// Counts up from 0 to [value] with easing when [animate] is true,
/// otherwise shows the final value immediately (no replay).
class AnimatedCount extends StatelessWidget {
  final double value;
  final bool animate;
  final TextStyle style;
  final int decimals;
  final String suffix;
  final String prefix;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.animate,
    required this.style,
    this.decimals = 0,
    this.suffix = '',
    this.prefix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  String _format(double v) {
    final num shown = decimals == 0 ? v.round() : v;
    final body = decimals == 0
        ? shown.toString()
        : shown.toStringAsFixed(decimals);
    return '$prefix$body$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return Text(_format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, val, __) => Text(_format(val), style: style),
    );
  }
}
