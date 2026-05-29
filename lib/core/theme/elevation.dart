import 'package:flutter/material.dart';

import 'colors.dart';

class AppElevation {
  const AppElevation._();

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.02),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.08),
      blurRadius: 36,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
