import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../emergency/screens/dashboard_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth 900ms cinematic entry animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await AppPreferences.ensureInitialized();
    // Slightly longer delay for the user to admire the premium opening animation
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) {
      return;
    }

    final destination = SessionService.isAuthenticated
        ? const DashboardScreen()
        : AppPreferences.hasSeenOnboarding
        ? const LoginScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B19), // Ultra deep modern slate navy
      body: Stack(
        children: [
          // Positioned mesh radial gradient blobs
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
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
            bottom: -100,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF312E81,
                    ).withValues(alpha: 0.55), // Indigo 900
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.error.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central animated content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      const _SplashMark(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'GuardianNode',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: AppColors.cleanWhite,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Real-time protection & emergency routing',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.cleanWhite.withValues(alpha: 0.75),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.cleanWhite,
                          strokeWidth: 2.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Connecting you to Bamenda safety network',
                        style: GoogleFonts.inter(
                          color: AppColors.cleanWhite.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: AppColors.cleanWhite.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.cleanWhite.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.trustBlue.withValues(alpha: 0.22),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_moon_outlined,
        color: AppColors.cleanWhite,
        size: 52,
      ),
    );
  }
}
