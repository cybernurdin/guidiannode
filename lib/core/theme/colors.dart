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

  static const Color darkBackground = Color(0xFF08111E);
  static const Color darkBackgroundAlt = Color(0xFF0C1626);
  static const Color darkSurface = Color(0xFF101B2D);
  static const Color darkSurfaceMuted = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF162238);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF263449);
  static const Color darkDisabled = Color(0xFF64748B);
  static const Color darkError = Color(0xFFEF4444);

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

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffold(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color backgroundFor(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color backgroundAltFor(BuildContext context) =>
      isDark(context) ? darkBackgroundAlt : backgroundAlt;

  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color surfaceMutedFor(BuildContext context) =>
      isDark(context) ? darkSurfaceMuted : surfaceMuted;

  static Color elevatedSurfaceFor(BuildContext context) =>
      isDark(context) ? darkSurfaceElevated : cleanWhite;

  static Color textPrimaryFor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textTertiaryFor(BuildContext context) =>
      isDark(context) ? darkTextTertiary : textTertiary;

  static Color borderFor(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color dividerFor(BuildContext context) =>
      isDark(context) ? darkDivider : divider;

  static Color disabledFor(BuildContext context) =>
      isDark(context) ? darkDisabled : disabled;

  static Color errorFor(BuildContext context) =>
      isDark(context) ? darkError : error;

  static Color overlaySurfaceFor(BuildContext context, {double alpha = 0.96}) =>
      (isDark(context) ? darkSurfaceElevated : cleanWhite).withValues(
        alpha: alpha,
      );

  static Color brandSurfaceFor(BuildContext context, Color color) =>
      color.withValues(alpha: isDark(context) ? 0.18 : 0.1);
}
