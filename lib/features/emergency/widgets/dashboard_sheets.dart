import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/bottom_sheets.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/guardian_components.dart';

class DashboardSheets {
  const DashboardSheets._();

  static void showEmergencyCategories(
    BuildContext context,
    Future<void> Function(String emergencyType, {String? description})
    onTrigger,
  ) {
    const categories = [
      _EmergencyCategory(
        type: 'security',
        title: 'Security',
        subtitle: 'Threat or crime',
        icon: Icons.shield_rounded,
        color: AppColors.trustBlue,
      ),
      _EmergencyCategory(
        type: 'medical',
        title: 'Medical',
        subtitle: 'Health emergency',
        icon: Icons.local_hospital_rounded,
        color: AppColors.safetyGreen,
      ),
      _EmergencyCategory(
        type: 'fire',
        title: 'Fire',
        subtitle: 'Fire incident',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.engagementOrange,
      ),
      _EmergencyCategory(
        type: 'accident',
        title: 'Accident',
        subtitle: 'Traffic accident',
        icon: Icons.car_crash_rounded,
        color: AppColors.communityYellow,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) {
        var selected = categories.first;
        return StatefulBuilder(
          builder: (context, setSheetState) => AppBottomSheet(
            title: "What's the emergency?",
            subtitle: 'Select the type of help you need.',
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.94,
                  children: [
                    for (final category in categories)
                      _SelectableCategoryCard(
                        category: category,
                        selected: selected.type == category.type,
                        onTap: () => setSheetState(() => selected = category),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  text: 'Next',
                  onPressed: () {
                    Navigator.of(context).pop();
                    onTrigger(selected.type);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showMapLegend(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const AppBottomSheet(
        title: 'Map legend',
        subtitle:
            'Use the map to see your position, active alerts, and response access points.',
        child: Column(
          children: [
            _LegendRow(
              color: AppColors.safetyGreen,
              label: 'Your current location',
            ),
            SizedBox(height: AppSpacing.sm),
            _LegendRow(color: AppColors.error, label: 'Active SOS alert'),
            SizedBox(height: AppSpacing.sm),
            _LegendRow(
              color: AppColors.communityYellow,
              label: 'Support and awareness overlay',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCategory {
  const _EmergencyCategory({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _SelectableCategoryCard extends StatelessWidget {
  const _SelectableCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _EmergencyCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(
          color: selected ? AppColors.trustBlue : Colors.transparent,
          width: 2,
        ),
      ),
      child: EmergencyCategoryCard(
        title: category.title,
        subtitle: category.subtitle,
        icon: category.icon,
        color: category.color,
        onTap: onTap,
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
      ],
    );
  }
}
