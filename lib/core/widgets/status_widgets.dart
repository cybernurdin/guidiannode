import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

enum StatusTone { success, warning, error, info, action }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    required this.tone,
    this.icon,
    this.title,
  });

  final String message;
  final StatusTone tone;
  final IconData? icon;
  final String? title;

  factory StatusBanner.success({required String message, String? title}) =>
      StatusBanner(message: message, title: title, tone: StatusTone.success);

  factory StatusBanner.warning({required String message, String? title}) =>
      StatusBanner(message: message, title: title, tone: StatusTone.warning);

  factory StatusBanner.error({required String message, String? title}) =>
      StatusBanner(message: message, title: title, tone: StatusTone.error);

  factory StatusBanner.info({required String message, String? title}) =>
      StatusBanner(message: message, title: title, tone: StatusTone.info);

  factory StatusBanner.action({required String message, String? title}) =>
      StatusBanner(message: message, title: title, tone: StatusTone.action);

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForTone(tone);

    return ClipRRect(
      borderRadius: AppRadii.card,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: AppRadii.card,
          border: Border.all(color: palette.foreground.withValues(alpha: 0.12)),
        ),
        child: Stack(
          children: [
            // Left decorative accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: palette.foreground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                ),
              ),
            ),
            // Banner content
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 4,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon ?? palette.icon,
                    color: palette.foreground,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              title!,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: palette.foreground,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                          ),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.foreground.withValues(
                                  alpha: 0.9,
                                ),
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuccessBanner extends StatelessWidget {
  const SuccessBanner({super.key, required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return StatusBanner.success(message: message, title: title);
  }
}

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return StatusBanner.warning(message: message, title: title);
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return StatusBanner.error(message: message, title: title);
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return StatusBanner.info(message: message, title: title);
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForTone(tone);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: AppRadii.pill,
          border: Border.all(color: palette.foreground.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon == null
                ? Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: palette.foreground,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: palette.foreground.withValues(alpha: 0.35),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                : Icon(icon, size: 13, color: palette.foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.foreground,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusSnackbar {
  const StatusSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    StatusTone tone = StatusTone.success,
  }) {
    final palette = _paletteForTone(tone);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: palette.foreground,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
        elevation: 6,
        margin: const EdgeInsets.all(AppSpacing.md),
        content: Row(
          children: [
            Icon(palette.icon, color: AppColors.cleanWhite, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.cleanWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

_StatusPalette _paletteForTone(StatusTone tone) {
  return switch (tone) {
    StatusTone.success => const _StatusPalette(
      background: AppColors.safetyGreenSurface,
      foreground: AppColors.safetyGreen,
      icon: Icons.check_circle_outline_rounded,
    ),
    StatusTone.warning => const _StatusPalette(
      background: AppColors.communityYellowSurface,
      foreground: Color(0xFF8A5A00),
      icon: Icons.warning_amber_rounded,
    ),
    StatusTone.error => const _StatusPalette(
      background: AppColors.errorSurface,
      foreground: AppColors.error,
      icon: Icons.error_outline_rounded,
    ),
    StatusTone.info => const _StatusPalette(
      background: AppColors.trustBlueSurface,
      foreground: AppColors.trustBlue,
      icon: Icons.info_outline_rounded,
    ),
    StatusTone.action => const _StatusPalette(
      background: AppColors.engagementOrangeSurface,
      foreground: AppColors.engagementOrange,
      icon: Icons.notifications_active_outlined,
    ),
  };
}
