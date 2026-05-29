import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'elevation.dart';
import 'radii.dart';
import 'spacing.dart';
import 'typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.trustBlue,
      onPrimary: AppColors.cleanWhite,
      secondary: AppColors.engagementOrange,
      onSecondary: AppColors.cleanWhite,
      tertiary: AppColors.communityYellow,
      onTertiary: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.cleanWhite,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      splashFactory: InkRipple.splashFactory,
      highlightColor: AppColors.trustBlue.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.trustBlue,
          foregroundColor: AppColors.cleanWhite,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: AppTypography.textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.trustBlue,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: AppTypography.textTheme.labelLarge!.copyWith(
            color: AppColors.trustBlue,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.trustBlue,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: AppTypography.textTheme.titleSmall!.copyWith(
            color: AppColors.trustBlue,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: AppTypography.textTheme.bodyMedium!.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.textTheme.bodyMedium!.copyWith(
          color: AppColors.textTertiary,
        ),
        helperStyle: AppTypography.textTheme.bodySmall,
        errorStyle: AppTypography.textTheme.bodySmall!.copyWith(
          color: AppColors.error,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.button,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.button,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.button,
          borderSide: BorderSide(color: AppColors.trustBlue, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.button,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.button,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.button,
          borderSide: BorderSide(color: AppColors.divider),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadow.withValues(alpha: 0.08),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cleanWhite,
        indicatorColor: AppColors.trustBlueSurface,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.trustBlue : AppColors.textSecondary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return AppTypography.textTheme.labelMedium!.copyWith(
            color: isSelected ? AppColors.trustBlue : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cleanWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.cleanWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.trustBlueDark,
        contentTextStyle: AppTypography.textTheme.bodyMedium!.copyWith(
          color: AppColors.cleanWhite,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceTint,
        selectedColor: AppColors.trustBlueSurface,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        labelStyle: AppTypography.textTheme.bodySmall!,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.engagementOrange,
        foregroundColor: AppColors.cleanWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static BoxDecoration elevatedSurface({
    Color color = AppColors.surface,
    BorderRadius borderRadius = AppRadii.card,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: Border.all(color: AppColors.border),
      boxShadow: AppElevation.soft,
    );
  }
}
