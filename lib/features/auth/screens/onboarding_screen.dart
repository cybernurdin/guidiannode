import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import 'permissions_education_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _slides = const [
    _OnboardingSlide(
      title: 'Send help requests in seconds',
      message:
          'Your emergency action stays visible, direct, and usable even under stress.',
      icon: Icons.sos_rounded,
      tone: StatusTone.error,
    ),
    _OnboardingSlide(
      title: 'Share live location only when it matters',
      message:
          'GuardianNode uses your location to notify nearby people and guide responders faster.',
      icon: Icons.location_searching_rounded,
      tone: StatusTone.info,
    ),
    _OnboardingSlide(
      title: 'Build trust through community response',
      message:
          'Nearby residents can follow active alerts, see route guidance, and move toward safer outcomes.',
      icon: Icons.people_alt_outlined,
      tone: StatusTone.success,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_currentPage == _slides.length - 1) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PermissionsEducationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const StatusBadge(
                    label: 'GuardianNode Bamenda',
                    tone: StatusTone.info,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder<void>(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const PermissionsEducationScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 350),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final page = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadii.card,
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(
                              0xFF0F172A,
                            ), // Premium obsidian slate dark background
                          ),
                          child: Stack(
                            children: [
                              // Layered mesh gradient blobs inside the pane
                              Positioned(
                                top: -80,
                                right: -80,
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        page.color.withValues(alpha: 0.35),
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
                                        AppColors.trustBlue.withValues(
                                          alpha: 0.22,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Polished glass boundary line
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: AppRadii.card,
                                  border: Border.all(
                                    color: AppColors.cleanWhite.withValues(
                                      alpha: 0.14,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),

                              // Content Layer
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: AppColors.cleanWhite.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.cleanWhite
                                              .withValues(alpha: 0.22),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        page.icon,
                                        size: 32,
                                        color: AppColors.cleanWhite,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      page.title,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.cleanWhite,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      page.message,
                                      style: GoogleFonts.inter(
                                        color: AppColors.cleanWhite.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontSize: 14.5,
                                        height: 1.45,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.08,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? slide.color
                          : AppColors.disabled.withValues(alpha: 0.5),
                      borderRadius: AppRadii.pill,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: slide.color.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: _currentPage == _slides.length - 1
                    ? 'Continue to permissions'
                    : 'Continue',
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final StatusTone tone;

  Color get color => switch (tone) {
    StatusTone.success => AppColors.safetyGreen,
    StatusTone.warning => AppColors.communityYellow,
    StatusTone.error => AppColors.error,
    StatusTone.info => AppColors.trustBlue,
    StatusTone.action => AppColors.engagementOrange,
  };
}
