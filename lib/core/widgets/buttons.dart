import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

enum AppButtonTone { primary, secondary, outline, danger }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.tone = AppButtonTone.primary,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonTone tone;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
      setState(() => _isPressed = false);
      HapticFeedback.lightImpact();
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final TextStyle textStyle = switch (widget.tone) {
      AppButtonTone.primary => Theme.of(context).textTheme.labelLarge!.copyWith(
        color: AppColors.cleanWhite,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      AppButtonTone.secondary =>
        Theme.of(context).textTheme.labelLarge!.copyWith(
          color: AppColors.trustBlueDark,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      AppButtonTone.outline => Theme.of(context).textTheme.labelLarge!.copyWith(
        color: AppColors.trustBlue,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      AppButtonTone.danger => Theme.of(context).textTheme.labelLarge!.copyWith(
        color: AppColors.cleanWhite,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    };

    final decoration = switch (widget.tone) {
      AppButtonTone.primary => BoxDecoration(
        borderRadius: AppRadii.button,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEnabled
              ? [AppColors.trustBlue, AppColors.trustBlueDark]
              : [AppColors.disabled, AppColors.disabled.withValues(alpha: 0.8)],
        ),
        boxShadow: isEnabled && !_isPressed
            ? [
                BoxShadow(
                  color: AppColors.trustBlue.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      AppButtonTone.secondary => BoxDecoration(
        borderRadius: AppRadii.button,
        color: isEnabled
            ? AppColors.trustBlueSurface
            : AppColors.disabled.withValues(alpha: 0.15),
      ),
      AppButtonTone.outline => BoxDecoration(
        borderRadius: AppRadii.button,
        color: Colors.transparent,
        border: Border.all(
          color: isEnabled ? AppColors.border : AppColors.disabled,
          width: 1.5,
        ),
      ),
      AppButtonTone.danger => BoxDecoration(
        borderRadius: AppRadii.button,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEnabled
              ? [AppColors.engagementOrange, const Color(0xFFC44920)]
              : [AppColors.disabled, AppColors.disabled.withValues(alpha: 0.8)],
        ),
        boxShadow: isEnabled && !_isPressed
            ? [
                BoxShadow(
                  color: AppColors.engagementOrange.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
    };

    final child = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color:
                  widget.tone == AppButtonTone.primary ||
                      widget.tone == AppButtonTone.danger
                  ? AppColors.cleanWhite
                  : AppColors.trustBlue,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color:
                      widget.tone == AppButtonTone.primary ||
                          widget.tone == AppButtonTone.danger
                      ? AppColors.cleanWhite
                      : widget.tone == AppButtonTone.secondary
                      ? AppColors.trustBlueDark
                      : AppColors.trustBlue,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ],
          );

    Widget button = ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          height: 56,
          decoration: decoration,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: child,
        ),
      ),
    );

    if (!widget.expand) {
      return IntrinsicWidth(child: button);
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: text,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: text,
      icon: icon,
      onPressed: onPressed,
      tone: AppButtonTone.secondary,
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: text,
      icon: icon,
      onPressed: onPressed,
      tone: AppButtonTone.outline,
    );
  }
}

class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: text,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      tone: AppButtonTone.danger,
    );
  }
}

class CommunityActionButton extends StatelessWidget {
  const CommunityActionButton({
    super.key,
    required this.onPressed,
    this.label = 'I Am Coming',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notify the victim that you are responding',
      child: AppButton(
        label: label,
        icon: Icons.route_rounded,
        onPressed: onPressed,
        tone: AppButtonTone.secondary,
      ),
    );
  }
}

class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    this.isSafeState = false,
    this.isBusy = false,
    this.label,
    this.subtitle,
  });

  final VoidCallback onPressed;
  final bool isSafeState;
  final bool isBusy;
  final String? label;
  final String? subtitle;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Continuous 2.4-second linear cycle for the radar wave expansion
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSafe = widget.isSafeState;
    final accentColor = isSafe
        ? AppColors.safetyGreen
        : AppColors.engagementOrange;
    final ringColor = accentColor.withValues(alpha: 0.2);
    final label = widget.label ?? (isSafe ? 'Protected' : 'SOS');
    final subtitle =
        widget.subtitle ??
        (isSafe ? 'Location sharing is active' : 'Send emergency alert now');

    return Semantics(
      button: true,
      label: isSafe
          ? 'Emergency safeguards are active'
          : 'Send SOS emergency alert',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;

          // Smooth physical core breathing scale (sine wave)
          final coreScale = widget.isBusy
              ? 1.0
              : 1.0 + 0.035 * math.sin(value * 2 * math.pi);

          return GestureDetector(
            onTap: widget.isBusy
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    widget.onPressed();
                  },
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Radar Pulse 1 (starts at size 180, expands to 260, fades out)
                  _PulseRing(
                    size: 180 + (80 * value),
                    color: ringColor.withValues(alpha: 0.15 * (1.0 - value)),
                    strokeWidth: 1.5,
                  ),
                  // Middle Radar Pulse 2 (offset by 0.5 phase)
                  _PulseRing(
                    size: 180 + (80 * ((value + 0.5) % 1.0)),
                    color: ringColor.withValues(
                      alpha: 0.25 * (1.0 - ((value + 0.5) % 1.0)),
                    ),
                    strokeWidth: 2.0,
                  ),
                  // Inner Halo Glow (constant breathing scale)
                  _PulseRing(
                    size: 176 + (14 * math.sin(value * 2 * math.pi).abs()),
                    color: ringColor.withValues(alpha: 0.28),
                    strokeWidth: 2.5,
                  ),

                  // Central Interactive Core
                  Transform.scale(
                    scale: coreScale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment.topLeft,
                          radius: 0.85,
                          colors: [
                            accentColor.withValues(alpha: 0.98),
                            accentColor.darken(0.12),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.cleanWhite.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(
                              alpha:
                                  0.32 +
                                  0.08 * math.sin(value * 2 * math.pi).abs(),
                            ),
                            blurRadius:
                                28 + 8 * math.sin(value * 2 * math.pi).abs(),
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 176,
                        height: 176,
                        child: Center(
                          child: widget.isBusy
                              ? const CircularProgressIndicator(
                                  color: AppColors.cleanWhite,
                                  strokeWidth: 3.2,
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge
                                          ?.copyWith(
                                            color: AppColors.cleanWhite,
                                            fontSize: 38,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                      child: Text(
                                        subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.cleanWhite
                                                  .withValues(alpha: 0.88),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.size,
    required this.color,
    required this.strokeWidth,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: strokeWidth),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

extension ColorDarken on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
