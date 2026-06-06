import 'package:flutter/material.dart';

import 'colors.dart';

class AppElevation {
  const AppElevation._();

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}
