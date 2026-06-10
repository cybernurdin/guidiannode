import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.trustBlue,
        systemNavigationBarColor: AppColors.trustBlue,
      ),
      child: Scaffold(
        backgroundColor: AppColors.trustBlue,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final screenWidth = constraints.maxWidth;
              final isCompact = screenHeight < 620;
              final topSpacing = (screenHeight * 0.09).clamp(28.0, 76.0);
              final logoSize = (screenWidth * 0.31).clamp(96.0, 120.0);
              final sectionSpacing = isCompact ? AppSpacing.md : AppSpacing.lg;

              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: topSpacing),
                        PhysicalShape(
                          clipper: const _SplashShieldClipper(),
                          color: AppColors.cleanWhite,
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.24),
                          child: SizedBox(
                            width: logoSize,
                            height: logoSize,
                            child: Image.asset(
                              'assets/images/guardian_node_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.shield_rounded,
                                    color: AppColors.trustBlue,
                                    size: logoSize * 0.64,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: sectionSpacing),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'GuardianNode',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.cleanWhite,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            'Help is one tap away.\nStronger together,\nsafer Bamenda.',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.cleanWhite,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        SizedBox(height: sectionSpacing),
                        SizedBox(
                          width: 92,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: const LinearProgressIndicator(
                              minHeight: 3,
                              color: AppColors.cleanWhite,
                              backgroundColor: Color(0x4DFFFFFF),
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: (screenHeight * 0.06).clamp(20.0, 52.0),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SplashShieldClipper extends CustomClipper<Path> {
  const _SplashShieldClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.5, 0)
      ..cubicTo(
        size.width * 0.63,
        size.height * 0.12,
        size.width * 0.75,
        size.height * 0.17,
        size.width * 0.87,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.84, size.height * 0.55)
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.76,
        size.width * 0.66,
        size.height * 0.9,
        size.width * 0.5,
        size.height,
      )
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.9,
        size.width * 0.2,
        size.height * 0.76,
        size.width * 0.16,
        size.height * 0.55,
      )
      ..lineTo(size.width * 0.13, size.height * 0.22)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.17,
        size.width * 0.37,
        size.height * 0.12,
        size.width * 0.5,
        0,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
