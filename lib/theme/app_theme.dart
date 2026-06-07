import 'package:flutter/material.dart';

/// Centralized color palette and theme.
class AppColors {
  // Brand
  static const Color forestGreen = Color(0xFF144D37);
  static const Color forestGreenDark = Color(0xFF0E3A29);
  static const Color emerald = Color(0xFF10B981);
  static const Color teal = Color(0xFF0D9488);

  // Accent gradient (lime -> vibrant green)
  static const Color lime = Color(0xFFC9E23A);
  static const Color vibrantGreen = Color(0xFF48C838);

  // Backgrounds
  static const Color mintBgTop = Color(0xFFE6F2EA);
  static const Color mintBgBottom = Color(0xFFF1F7F4);
  static const Color screenBg = Color(0xFFF5F6FA);
  static const Color cardWhite = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF090F16);
  static const Color textSecondary = Color(0xFF6E7582);
  static const Color textSubtle = Color(0xFF9AA1B0);

  // Neumorphic shadows
  static const Color shadowDark = Color(0xFFD1D9E6);
  static const Color shadowLight = Color(0xFFFFFFFF);

  // Status colors
  static const Color present = Color(0xFF22C55E);
  static const Color absent = Color(0xFFEF4444);
  static const Color halfDay = Color(0xFFF59E0B);
  static const Color holiday = Color(0xFF0EA5E9);

  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    colors: [lime, vibrantGreen],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient mintGradient = LinearGradient(
    colors: [mintBgTop, mintBgBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF144D37), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient presentGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient absentGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient halfDayGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient holidayGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.screenBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.forestGreen,
        secondary: AppColors.vibrantGreen,
        surface: AppColors.cardWhite,
      ),
      textTheme: _textTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.vibrantGreen,
        secondary: AppColors.lime,
        surface: const Color(0xFF161B22),
      ),
      textTheme: _textThemeDark(base.textTheme),
      cardTheme: const CardThemeData(
        color: Color(0xFF161B22),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFFE6EDF3),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    TextStyle s(double size, FontWeight w,
            {Color c = AppColors.textPrimary, double ls = 0}) =>
        TextStyle(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);
    return base.copyWith(
      displayLarge: s(36, FontWeight.w700, ls: -1),
      headlineSmall: s(22, FontWeight.w600, ls: -0.5),
      titleLarge: s(20, FontWeight.w600),
      titleMedium: s(18, FontWeight.w700),
      bodyLarge: s(15, FontWeight.w500, c: AppColors.textSecondary),
      bodyMedium: s(14, FontWeight.w400, c: AppColors.textSecondary),
      bodySmall: s(12, FontWeight.w400, c: AppColors.textSubtle),
    );
  }

  static TextTheme _textThemeDark(TextTheme base) {
    const primary = Color(0xFFE6EDF3);
    const secondary = Color(0xFF8B949E);
    const subtle = Color(0xFF484F58);
    TextStyle s(double size, FontWeight w, {Color c = primary, double ls = 0}) =>
        TextStyle(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);
    return base.copyWith(
      displayLarge: s(36, FontWeight.w700, ls: -1),
      headlineSmall: s(22, FontWeight.w600, ls: -0.5),
      titleLarge: s(20, FontWeight.w600),
      titleMedium: s(18, FontWeight.w700),
      bodyLarge: s(15, FontWeight.w500, c: secondary),
      bodyMedium: s(14, FontWeight.w400, c: secondary),
      bodySmall: s(12, FontWeight.w400, c: subtle),
    );
  }
}

/// Reusable neumorphic decoration helper.
BoxDecoration neumorphic({
  double radius = 20,
  Color color = AppColors.screenBg,
  bool pressed = false,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: pressed
        ? [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.1),
              offset: const Offset(2, 2),
              blurRadius: 8,
            ),
          ]
        : [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.1),
              offset: const Offset(6, 6),
              blurRadius: 22,
            ),
            const BoxShadow(
              color: AppColors.shadowLight,
              offset: Offset(-6, -6),
              blurRadius: 22,
            ),
          ],
  );
}

BoxDecoration softCard({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        offset: const Offset(0, 10),
        blurRadius: 22,
      ),
    ],
  );
}

BoxDecoration glassCard({double radius = 20, Color? color}) {
  return BoxDecoration(
    color: (color ?? Colors.white).withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.3),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        offset: const Offset(0, 12),
        blurRadius: 24,
      ),
    ],
  );
}
