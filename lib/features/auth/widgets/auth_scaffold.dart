import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/status_widgets.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow,
    this.footer,
    this.showBackButton = true,
    this.heroIcon = Icons.shield_outlined,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? eyebrow;
  final Widget? footer;
  final bool showBackButton;
  final IconData heroIcon;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Sweeping curved mesh header
            Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Dark slate base
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  // Layered mesh gradient blobs
                  Positioned(
                    top: -100,
                    right: -60,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.trustBlue.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -40,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.error.withValues(alpha: 0.16),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Polished bottom glass line separator
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 1.5,
                      color: AppColors.cleanWhite.withValues(alpha: 0.12),
                    ),
                  ),

                  // Header Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xl + 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showBackButton)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.cleanWhite.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.cleanWhite.withValues(
                                      alpha: 0.16,
                                    ),
                                    width: 1.2,
                                  ),
                                ),
                                child: IconButton(
                                  tooltip: 'Back',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  padding: const EdgeInsets.only(
                                    left: 6,
                                  ), // Offset for perfect icon alignment
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: AppColors.cleanWhite,
                                    size: 16,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 40, height: 40),
                            const Spacer(),
                            // ignore: use_null_aware_elements
                            if (badge != null) badge!,
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.cleanWhite.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.cleanWhite.withValues(
                                alpha: 0.22,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            heroIcon,
                            size: 28,
                            color: AppColors.cleanWhite,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (eyebrow != null) ...[
                          Text(
                            eyebrow!,
                            style: GoogleFonts.inter(
                              color: AppColors.cleanWhite.withValues(
                                alpha: 0.8,
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: AppColors.cleanWhite,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: AppColors.cleanWhite.withValues(alpha: 0.88),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthHeroBadge extends StatelessWidget {
  const AuthHeroBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.info,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: label, tone: tone);
  }
}
