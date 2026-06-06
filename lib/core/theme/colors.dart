import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color trustBlue = Color(0xFF1D4289);
  static const Color safetyGreen = Color(0xFF009639);
  static const Color engagementOrange = Color(0xFFDC582A);
  static const Color communityYellow = Color(0xFFFFC845);
  static const Color cleanWhite = Color(0xFFFFFFFF);

  static const Color trustBlueDark = Color(0xFF0B2C67);
  static const Color trustBlueSurface = Color(0xFFEAF1FF);
  static const Color safetyGreenSurface = Color(0xFFEAF8EF);
  static const Color engagementOrangeSurface = Color(0xFFFFEEE8);
  static const Color communityYellowSurface = Color(0xFFFFF7DA);

  static const Color background = Color(0xFFF7FAFF);
  static const Color backgroundAlt = Color(0xFFEFF4FB);
  static const Color surface = cleanWhite;
  static const Color surfaceMuted = Color(0xFFF8FBFF);
  static const Color surfaceTint = trustBlueSurface;

  static const Color textPrimary = Color(0xFF071B3A);
  static const Color textSecondary = Color(0xFF526173);
  static const Color textTertiary = Color(0xFF7D8896);
  static const Color textOnDark = cleanWhite;

  static const Color border = Color(0xFFDDE5F0);
  static const Color divider = Color(0xFFEAF0F7);
  static const Color disabled = Color(0xFFBBC6D4);
  static const Color shadow = Color(0xFF10213D);

  static const Color error = Color(0xFFE23D28);
  static const Color errorSurface = Color(0xFFFFECE8);
  static const Color success = safetyGreen;
  static const Color warning = communityYellow;
  static const Color warningSurface = communityYellowSurface;
  static const Color info = trustBlue;
  static const Color infoSurface = trustBlueSurface;

  static const List<Color> emergencyGradient = [
    trustBlue,
    trustBlueDark,
    Color(0xFF08204D),
  ];
}
