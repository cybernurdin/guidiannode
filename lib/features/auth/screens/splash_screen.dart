import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/guardian_components.dart';
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
      backgroundColor: AppColors.trustBlue,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 190,
            child: CustomPaint(painter: _BamendaSilhouettePainter()),
          ),
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
                      const GuardianLogo(
                        size: 118,
                        showWordmark: true,
                        onDark: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Help is one tap away.\nStronger together,\nsafer Bamenda.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.cleanWhite,
                          fontWeight: FontWeight.w800,
                          height: 1.26,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        width: 128,
                        height: 3,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.trustBlueDark,
                              AppColors.safetyGreen,
                              AppColors.engagementOrange,
                              AppColors.communityYellow,
                            ],
                          ),
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
                        "Bamenda, We've Got You.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.cleanWhite.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
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

class _BamendaSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mountainPaint = Paint()
      ..color = AppColors.cleanWhite.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final townPaint = Paint()
      ..color = AppColors.cleanWhite.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final monumentPaint = Paint()
      ..color = AppColors.cleanWhite.withValues(alpha: 0.28)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final mountains = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.34,
        size.width * 0.42,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.28,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountains, mountainPaint);

    for (var i = 0; i < 7; i++) {
      final left = size.width * (0.18 + i * 0.09);
      final top = size.height * (0.72 - (i.isEven ? 0.04 : 0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, size.width * 0.055, size.height * 0.12),
          const Radius.circular(3),
        ),
        townPaint,
      );
    }

    final center = Offset(size.width * 0.5, size.height * 0.48);
    canvas.drawLine(
      Offset(center.dx, center.dy + 54),
      Offset(center.dx, center.dy - 20),
      monumentPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 17, center.dy + 54),
      Offset(center.dx + 17, center.dy + 54),
      monumentPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 20),
      Offset(center.dx + 11, center.dy - 5),
      monumentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
