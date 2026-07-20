import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/profile_models.dart';
import '../services/profile_api_service.dart';
import '../services/role_api_service.dart';
import '../widgets/role_request_sheet.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationshipController = TextEditingController();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _bootstrapFromSession();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _neighborhoodController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationshipController.dispose();
    super.dispose();
  }

  void _bootstrapFromSession() {
    final currentUser = SessionService.currentUser;
    if (currentUser == null) {
      return;
    }

    final profile = UserProfile.fromJson(currentUser);
    _applyProfile(profile);
    _isLoading = false;
  }

  void _applyProfile(UserProfile profile) {
    _profile = profile;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber;
    _neighborhoodController.text = profile.neighborhood;
    _contactNameController.text = profile.emergencyContact?.contactName ?? '';
    _contactPhoneController.text = profile.emergencyContact?.phoneNumber ?? '';
    _contactRelationshipController.text =
        profile.emergencyContact?.relationship ?? '';
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    if (showSpinner || _profile == null) {
      setState(() => _isLoading = true);
    }

    try {
      final profile = await ProfileApiService.fetchCurrentProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _applyProfile(profile);
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = ApiClient.friendlyMessage(error);
      setState(() {
        _isLoading = false;
        _loadError = message;
      });

      if (_profile != null) {
        StatusSnackbar.show(context, message: message, tone: StatusTone.error);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedProfile = await ProfileApiService.updateCurrentProfile(
        fullName: _fullNameController.text.trim(),
        neighborhood: _neighborhoodController.text.trim(),
        emergencyContact: EmergencyContactProfile(
          contactName: _contactNameController.text.trim(),
          phoneNumber: _contactPhoneController.text.trim(),
          relationship: _contactRelationshipController.text.trim(),
        ),
      );

      SessionService.updateCurrentUserFields(
        updatedProfile.toSessionUserFields(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _applyProfile(updatedProfile);
        _isSaving = false;
        _loadError = null;
      });

      StatusSnackbar.show(context, message: 'Profile updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      StatusSnackbar.show(
        context,
        message: ApiClient.friendlyMessage(error),
        tone: StatusTone.error,
      );
    }
  }

  Future<void> _becomeCommunityHelper() async {
    try {
      final updated = await RoleApiService.requestRole(
        requestedRole: 'community_helper',
      );
      SessionService.updateCurrentUserFields({
        'role': updated.role,
        'verification_status': updated.verificationStatus,
      });

      if (!mounted) {
        return;
      }

      setState(() => _profile = updated);
      StatusSnackbar.show(
        context,
        message: 'You are now a Community Helper.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      StatusSnackbar.show(
        context,
        message: ApiClient.friendlyMessage(error),
        tone: StatusTone.error,
      );
    }
  }

  void _openRoleRequestSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => RoleRequestSheet(
        onSubmitted: () => _loadProfile(showSpinner: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null && _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: ErrorState(
          title: 'Profile unavailable',
          message: _loadError!,
          onRetry: _loadProfile,
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(showActions: true),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _ProfileHero(
              name: profile.fullName,
              neighborhood: profile.neighborhood,
            ),
            const SizedBox(height: AppSpacing.md),
            if (profile.locationPermission)
              const SuccessBanner(
                title: 'Location ready',
                message:
                    'Live location sharing is enabled and can support routing during active emergencies.',
              )
            else
              const WarningBanner(
                title: 'Location off',
                message:
                    'Turn on location sharing from the dashboard or settings when you want faster routing and nearby alert discovery.',
              ),
            if (_loadError != null) ...[
              const SizedBox(height: AppSpacing.md),
              WarningBanner(
                title: 'Latest refresh failed',
                message: 'Showing saved profile data. $_loadError',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'Community role',
              subtitle:
                  'Volunteer as a helper, or request a verified responder role.',
            ),
            const SizedBox(height: AppSpacing.md),
            _CommunityRoleCard(
              profile: profile,
              onBecomeHelper: _becomeCommunityHelper,
              onRequestRole: _openRoleRequestSheet,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'Profile details',
              subtitle:
                  'Review and update the information tied to your account.',
            ),
            const SizedBox(height: AppSpacing.md),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      helperText:
                          'Phone changes stay aligned with WhatsApp sign-in.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _neighborhoodController,
                    decoration: const InputDecoration(
                      labelText: 'Quarter / neighborhood',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Enter your neighborhood';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Emergency Contacts',
                    subtitle:
                        'These contacts will be notified during an emergency.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  EmergencyContactCard(
                    name: _contactNameController.text.isEmpty
                        ? 'No contact set'
                        : _contactNameController.text,
                    phoneNumber: _contactPhoneController.text.isEmpty
                        ? 'Add a valid phone number'
                        : _contactPhoneController.text,
                    relationship: _contactRelationshipController.text,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _contactNameController,
                    decoration: const InputDecoration(
                      labelText: 'Contact name',
                      prefixIcon: Icon(Icons.contact_page_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Enter a contact name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _contactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact phone number',
                      prefixIcon: Icon(Icons.contact_phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 8) {
                        return 'Enter a valid contact phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _contactRelationshipController,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      prefixIcon: Icon(Icons.people_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Describe the relationship';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    text: 'Save changes',
                    icon: Icons.save_outlined,
                    isLoading: _isSaving,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({bool showActions = false}) {
    return AppBar(
      titleSpacing: 0,
      title: const Row(
        children: [
          GuardianLogo(size: 38, padding: EdgeInsets.all(3)),
          SizedBox(width: AppSpacing.sm),
          Text('My Profile'),
        ],
      ),
      actions: showActions
          ? [
              IconButton(
                tooltip: 'Refresh profile',
                onPressed: _isLoading
                    ? null
                    : () => _loadProfile(showSpinner: false),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ]
          : null,
    );
  }
}

const Map<String, String> _roleLabels = {
  'citizen': 'Citizen',
  'community_helper': 'Community Helper',
  'verified_responder': 'Verified Responder',
  'medical_responder': 'Medical Responder',
  'security_responder': 'Security Responder',
  'humanitarian_responder': 'Humanitarian Responder',
  'moderator': 'Moderator',
  'administrator': 'Administrator',
};

class _CommunityRoleCard extends StatelessWidget {
  const _CommunityRoleCard({
    required this.profile,
    required this.onBecomeHelper,
    required this.onRequestRole,
  });

  final UserProfile profile;
  final VoidCallback onBecomeHelper;
  final VoidCallback onRequestRole;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final roleLabel = _roleLabels[profile.role] ?? 'Citizen';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current role: $roleLabel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (profile.hasPendingRoleRequest)
                const StatusBadge(label: 'PENDING', tone: StatusTone.warning)
              else if (profile.hasApprovedSensitiveRole)
                const StatusBadge(label: 'APPROVED', tone: StatusTone.success)
              else if (profile.verificationStatus == 'rejected')
                const StatusBadge(label: 'REJECTED', tone: StatusTone.error)
              else if (profile.verificationStatus == 'suspended')
                const StatusBadge(label: 'SUSPENDED', tone: StatusTone.error),
            ],
          ),
          if (profile.hasPendingRoleRequest) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your request for ${_roleLabels[profile.requestedRole] ?? profile.requestedRole} is awaiting administrator review.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (profile.role == 'citizen')
            OutlineActionButton(
              text: context.tr('become_helper'),
              icon: Icons.volunteer_activism_outlined,
              onPressed: onBecomeHelper,
            ),
          if (!profile.hasPendingRoleRequest) ...[
            if (profile.role == 'citizen') const SizedBox(height: AppSpacing.sm),
            OutlineActionButton(
              text: context.tr('request_responder_role'),
              icon: Icons.badge_outlined,
              onPressed: onRequestRole,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.name, required this.neighborhood});

  final String name;
  final String neighborhood;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.trustBlue,
        borderRadius: AppRadii.card,
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.cleanWhite,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cleanWhite, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.trustBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name.isEmpty ? 'GuardianNode Member' : name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.cleanWhite,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.safetyGreenSurface,
              borderRadius: AppRadii.pill,
            ),
            child: Text(
              'Verified Member',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.safetyGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              // TODO: Replace placeholder stats when a profile stats endpoint exists.
              ProfileStatCard(value: '0', label: 'Alerts', onDark: true),
              ProfileStatCard(value: '0', label: 'Helped', onDark: true),
              ProfileStatCard(value: '0', label: 'Following', onDark: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            neighborhood.isEmpty ? 'Cameroon' : neighborhood,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.cleanWhite.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
