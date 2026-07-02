import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import 'buttons.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final iconBackground = AppColors.isDark(context)
        ? AppColors.trustBlue.withValues(alpha: 0.2)
        : AppColors.trustBlueSurface;
    final iconColor = AppColors.isDark(context)
        ? Theme.of(context).colorScheme.primary
        : AppColors.trustBlueDark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AppRadii.card,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryFor(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(text: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel = 'Retry',
    this.onRetry,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: title,
      message: message,
      icon: Icons.signal_wifi_off_rounded,
      actionLabel: onRetry == null ? null : actionLabel,
      onAction: onRetry,
    );
  }
}

class LoadingPlaceholder extends StatefulWidget {
  const LoadingPlaceholder({
    super.key,
    this.height = 20,
    this.width = double.infinity,
  });

  final double height;
  final double width;

  @override
  State<LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
      lowerBound: 0.55,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.backgroundAltFor(context),
          borderRadius: AppRadii.card,
        ),
      ),
    );
  }
}

class LoadingCardList extends StatelessWidget {
  const LoadingCardList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == count - 1 ? 0 : AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.card,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingPlaceholder(width: math.max(120, 200 - index * 16)),
                const SizedBox(height: AppSpacing.sm),
                const LoadingPlaceholder(width: 180),
                const SizedBox(height: AppSpacing.md),
                const LoadingPlaceholder(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
