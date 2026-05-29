import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color safetyGreen = Color(0xFF10B981);
  static const Color trustBlue = Color(0xFF2563EB);
  static const Color engagementOrange = Color(0xFFF97316);
  static const Color communityYellow = Color(0xFFF59E0B);
  static const Color cleanWhite = Color(0xFFFFFFFF);

  static const Color trustBlueDark = Color(0xFF0F172A);
  static const Color trustBlueSurface = Color(0xFFEFF6FF);
  static const Color safetyGreenSurface = Color(0xFFECFDF5);
  static const Color engagementOrangeSurface = Color(0xFFFFF7ED);
  static const Color communityYellowSurface = Color(0xFFFEF3C7);

  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundAlt = Color(0xFFF1F5F9);
  static const Color surface = cleanWhite;
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color surfaceTint = Color(0xFFEFF6FF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textOnDark = cleanWhite;

  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color shadow = Color(0xFF0F172A);

  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFFFEF2F2);
  static const Color success = safetyGreen;
  static const Color warning = communityYellow;
  static const Color warningSurface = communityYellowSurface;
  static const Color info = trustBlue;
  static const Color infoSurface = trustBlueSurface;

  static const List<Color> emergencyGradient = [
    Color(0xFF1E1B4B), // Deep royal indigo
    Color(0xFF312E81), // Saturated indigo
    Color(0xFFE11D48), // Bright crimson
  ];
}
