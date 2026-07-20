import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class BenefitSlideData {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;

  const BenefitSlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
  });
}

class BenefitsCarousel extends StatefulWidget {
  const BenefitsCarousel({super.key});

  @override
  State<BenefitsCarousel> createState() => _BenefitsCarouselState();
}

class _BenefitsCarouselState extends State<BenefitsCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  final List<BenefitSlideData> slides = [
    const BenefitSlideData(
      title: 'Instant Emergency Alerts',
      description:
          'Send SOS alerts within seconds and notify nearby responders immediately.',
      icon: Icons.radar_rounded, // or emergency, notifications_active
      iconColor: AppColors.safetyGreen,
    ),
    const BenefitSlideData(
      title: 'Real-Time Location Tracking',
      description:
          'Share your live location only during emergencies for fast assistance.',
      icon: Icons.location_on_rounded,
      iconColor: AppColors.engagementOrange,
    ),
    const BenefitSlideData(
      title: 'Community Protection Network',
      description:
          'Connect with nearby users and responders across Cameroon for faster help.',
      icon: Icons.handshake_rounded,
      iconColor: AppColors.trustBlue,
    ),
    const BenefitSlideData(
      title: 'Dual Communication System',
      description:
          'Alerts are delivered through Push Notifications and SMS for reliability.',
      icon: Icons.cell_tower_rounded,
      iconColor: AppColors.communityYellow,
    ),
    const BenefitSlideData(
      title: 'Trusted & Secure System',
      description:
          'Your data is encrypted and protected using secure authentication.',
      icon: Icons.security_rounded,
      iconColor: AppColors.trustBlue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      color: colors.surface,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(slide.icon, size: 48, color: slide.iconColor),
                      const SizedBox(height: 12),
                      Text(
                        slide.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slide.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  height: 8.0,
                  width: _currentPage == index ? 24.0 : 8.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.trustBlue
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4.0),
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
