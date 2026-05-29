import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import 'buttons.dart';
import 'status_widgets.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor = AppColors.trustBlue,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return _ScaleFeedback(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.card,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: AppElevation.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.icon,
    this.tone = StatusTone.info,
  });

  final String label;
  final String value;
  final String? helper;
  final IconData? icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      StatusTone.success => AppColors.safetyGreenSurface,
      StatusTone.warning => AppColors.communityYellowSurface,
      StatusTone.error => AppColors.errorSurface,
      StatusTone.info => AppColors.trustBlueSurface,
      StatusTone.action => AppColors.engagementOrangeSurface,
    };
    final foreground = switch (tone) {
      StatusTone.success => AppColors.safetyGreen,
      StatusTone.warning => AppColors.textPrimary,
      StatusTone.error => AppColors.error,
      StatusTone.info => AppColors.trustBlueDark,
      StatusTone.action => AppColors.engagementOrange,
    };

    return Container(
      decoration: BoxDecoration(
        color: palette,
        borderRadius: AppRadii.card,
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.card,
        child: Stack(
          children: [
            // Left saturated accent boundary indicator
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: foreground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                ),
              ),
            ),
            // Core content
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 2,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: foreground),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: foreground.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  if (helper != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      helper!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.neighborhood,
    required this.locationEnabled,
  });

  final String name;
  final String phoneNumber;
  final String neighborhood;
  final bool locationEnabled;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.trustBlueSurface,
                  borderRadius: AppRadii.card,
                  border: Border.all(
                    color: AppColors.trustBlue.withValues(alpha: 0.15),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? 'G' : name.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.trustBlueDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phoneNumber,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: locationEnabled ? 'Active' : 'Offline',
                tone: locationEnabled ? StatusTone.success : StatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.xs),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    neighborhood.isEmpty
                        ? 'Neighborhood not set'
                        : neighborhood,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyContactCard extends StatelessWidget {
  const EmergencyContactCard({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });

  final String name;
  final String phoneNumber;
  final String relationship;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.engagementOrangeSurface,
              borderRadius: AppRadii.card,
              border: Border.all(
                color: AppColors.engagementOrange.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.contact_phone_outlined,
              color: AppColors.engagementOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phoneNumber,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (relationship.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      relationship.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.distance,
    required this.time,
    this.statusLabel = 'Active nearby',
    this.onTap,
    this.actionLabel = 'I Am Coming',
    this.onAction,
    this.tone = StatusTone.error,
  });

  final String title;
  final String subtitle;
  final String distance;
  final String time;
  final String statusLabel;
  final VoidCallback? onTap;
  final String actionLabel;
  final VoidCallback? onAction;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(label: statusLabel, tone: tone),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.near_me_rounded,
                size: 14,
                color: AppColors.trustBlue,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                distance,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            CommunityActionButton(onPressed: onAction!, label: actionLabel),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return _ScaleFeedback(onTap: onTap, child: cardContent);
    }

    return cardContent;
  }
}

class IncidentCard extends StatelessWidget {
  const IncidentCard({
    super.key,
    required this.title,
    required this.distance,
    required this.time,
    required this.onAction,
    this.severityColor = AppColors.error,
    this.subtitle = 'Emergency reported nearby',
  });

  final String title;
  final String distance;
  final String time;
  final Color severityColor;
  final VoidCallback onAction;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tone = severityColor == AppColors.safetyGreen
        ? StatusTone.success
        : StatusTone.error;
    return AlertCard(
      title: title,
      subtitle: subtitle,
      distance: distance,
      time: time,
      onAction: onAction,
      tone: tone,
    );
  }
}

class ResponderCard extends StatelessWidget {
  const ResponderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final List<StatTile> metrics;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: metrics
                .map((metric) => SizedBox(width: 114, child: metric))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class SafeZoneCard extends StatelessWidget {
  const SafeZoneCard({
    super.key,
    required this.locationName,
    required this.distance,
    this.subtitle = 'Verified assistance point',
    this.onTap,
  });

  final String locationName;
  final String distance;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final innerContent = ListTile(
      dense: false,
      minVerticalPadding: 0,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.safetyGreenSurface,
          borderRadius: AppRadii.card,
          border: Border.all(
            color: AppColors.safetyGreen.withValues(alpha: 0.15),
          ),
        ),
        child: const Icon(
          Icons.local_police_outlined,
          color: AppColors.safetyGreen,
          size: 22,
        ),
      ),
      title: Text(
        locationName,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '$subtitle • $distance',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
    );

    final card = _SurfaceCard(child: innerContent);

    if (onTap != null) {
      return _ScaleFeedback(onTap: onTap, child: card);
    }

    return card;
  }
}

class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.location_on_outlined,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.trustBlueSurface,
              borderRadius: AppRadii.card,
              border: Border.all(
                color: AppColors.trustBlue.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: AppColors.trustBlueDark, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class CommunityUpdateCard extends StatelessWidget {
  const CommunityUpdateCard({super.key, required this.updateText});

  final String updateText;

  @override
  Widget build(BuildContext context) {
    return StatusBanner.info(message: updateText);
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: AppElevation.soft,
      ),
      child: child,
    );
  }
}

class _ScaleFeedback extends StatefulWidget {
  const _ScaleFeedback({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_ScaleFeedback> createState() => _ScaleFeedbackState();
}

class _ScaleFeedbackState extends State<_ScaleFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTap != null ? _controller.forward() : null,
      onTapUp: (_) {
        if (widget.onTap != null) {
          _controller.reverse();
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      onTapCancel: () => widget.onTap != null ? _controller.reverse() : null,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
