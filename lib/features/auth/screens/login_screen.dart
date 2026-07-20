import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../emergency/services/emergency_coordinator.dart';
import '../utils/post_auth_flow.dart';
import '../widgets/auth_scaffold.dart';
import 'registration_screen.dart';
import 'whatsapp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefillLocationEnabled = false});

  final bool prefillLocationEnabled;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final EmergencyCoordinator _emergencyCoordinator =
      EmergencyCoordinator.instance;

  bool _isLocationEnabled = false;
  bool _isLoading = false;
  bool _isQuickLoginLoading = false;
  bool _isEmailRegisterMode = false;
  int _selectedTab = 0;
  final _fullNameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLocationEnabled = widget.prefillLocationEnabled;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _registerPhoneController.dispose();
    _registerEmailController.dispose();
    super.dispose();
  }

  Future<void> _applySessionAndRoute(Map<String, dynamic> response) async {
    final session = response['session'];
    if (session is Map) {
      await SessionService.setSession(Map<String, dynamic>.from(session));
    }

    if (!mounted) {
      return;
    }

    _routeAfterVerification();
  }

  /// Demo/competition-only shortcut: signs in with just a registered phone
  /// number, no password or OTP required.
  Future<void> _handleQuickPhoneLogin() async {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.trim().replaceAll(' ', '').length < 8) {
      StatusSnackbar.show(
        context,
        message: 'Enter a valid phone number first.',
        tone: StatusTone.error,
      );
      return;
    }

    setState(() => _isQuickLoginLoading = true);

    try {
      final response = await ApiService.loginPhoneOnly(phoneNumber);

      if (!mounted) {
        return;
      }

      setState(() => _isQuickLoginLoading = false);

      if (response['success'] != true) {
        if (response['code'] == 'PHONE_NOT_REGISTERED') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  RegistrationScreen(prefillLocationEnabled: _isLocationEnabled),
            ),
          );
          return;
        }

        StatusSnackbar.show(
          context,
          message: response['message']?.toString() ?? 'Could not sign in.',
          tone: StatusTone.error,
        );
        return;
      }

      await _applySessionAndRoute(response);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isQuickLoginLoading = false);
      StatusSnackbar.show(
        context,
        message: ApiClient.friendlyMessage(error),
        tone: StatusTone.error,
      );
    }
  }

  Future<void> _handleEmailPasswordLogin() async {
    final password = _passwordController.text;

    if (_isEmailRegisterMode) {
      final fullName = _fullNameController.text.trim();
      final phoneNumber = _registerPhoneController.text.trim();

      if (fullName.isEmpty || phoneNumber.isEmpty || password.isEmpty) {
        StatusSnackbar.show(
          context,
          message: 'Enter your name, phone number, and a password.',
          tone: StatusTone.error,
        );
        return;
      }
    } else {
      final identifier = _emailController.text.trim();

      if (identifier.isEmpty || password.isEmpty) {
        StatusSnackbar.show(
          context,
          message: 'Enter your email/phone and password.',
          tone: StatusTone.error,
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final response = _isEmailRegisterMode
          ? await ApiService.registerWithPassword(
              fullName: _fullNameController.text.trim(),
              phoneNumber: _registerPhoneController.text.trim(),
              password: password,
              email: _registerEmailController.text.trim().isEmpty
                  ? null
                  : _registerEmailController.text.trim(),
            )
          : await ApiService.loginWithPassword(
              identifier: _emailController.text.trim(),
              password: password,
            );

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message:
              response['message']?.toString() ?? 'Could not sign in.',
          tone: StatusTone.error,
        );
        return;
      }

      await _applySessionAndRoute(response);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      StatusSnackbar.show(
        context,
        message: ApiClient.friendlyMessage(error),
        tone: StatusTone.error,
      );
    }
  }

  Future<void> _toggleLocationSharing(bool value) async {
    if (!value) {
      setState(() => _isLocationEnabled = false);
      return;
    }

    final permissionResult = await _emergencyCoordinator
        .previewLocationPermission(true);

    if (!mounted) {
      return;
    }

    setState(() => _isLocationEnabled = permissionResult.granted);

    if (!permissionResult.granted && permissionResult.message != null) {
      StatusSnackbar.show(
        context,
        message: permissionResult.message!,
        tone: StatusTone.error,
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phoneNumber = _phoneController.text.trim();
      final response = await ApiService.startLoginVerification(phoneNumber);

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (response['success'] != true) {
        if (response['code'] == 'PHONE_NOT_REGISTERED') {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Account Not Found'),
                content: const Text(
                  'This phone number is not registered. Please create an account first.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RegistrationScreen(
                            prefillLocationEnabled: _isLocationEnabled,
                          ),
                        ),
                      );
                    },
                    child: const Text('Create account'),
                  ),
                ],
              );
            },
          );
          return;
        }

        StatusSnackbar.show(
          context,
          message:
              response['message']?.toString() ??
              'WhatsApp verification could not be started.',
          tone: StatusTone.error,
        );
        return;
      }

      final verificationId = response['verificationId']?.toString();
      final token = response['token']?.toString();
      final whatsappUrl = response['whatsappUrl']?.toString();
      final expiresAt =
          response['expiresAt']?.toString() ??
          response['expires_at']?.toString();

      if (verificationId == null || token == null || whatsappUrl == null) {
        StatusSnackbar.show(
          context,
          message: 'The backend returned an incomplete verification link.',
          tone: StatusTone.error,
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WhatsappVerificationScreen(
            verificationId: verificationId,
            token: token,
            whatsappUrl: whatsappUrl,
            phoneNumber: phoneNumber,
            purpose: 'login',
            expiresAt: expiresAt,
            title: 'Verify your login',
            subtitle:
                'Send the prepared message from WhatsApp to securely continue.',
            onRequestNew: () => ApiService.startLoginVerification(phoneNumber),
            onAuthRuleFailure: (code) {
              Navigator.of(context).pop();

              if (code == 'PHONE_NOT_REGISTERED') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RegistrationScreen(
                      prefillLocationEnabled: _isLocationEnabled,
                    ),
                  ),
                );
              }
            },
            onVerified: (session) async {
              await SessionService.setSession(session);

              if (!mounted) {
                return;
              }

              _routeAfterVerification();
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      StatusSnackbar.show(
        context,
        message: ApiClient.friendlyMessage(error),
        tone: StatusTone.error,
      );
    }
  }

  void _routeAfterVerification() {
    PostAuthFlow.routeAfterVerification(
      context,
      bootstrapLocationSharing: _isLocationEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AuthScaffold(
      showBackButton: false,
      title: context.tr('welcome_back'),
      subtitle: context.tr('login_continue'),
      badge: AuthHeroBadge(
        label: _isLocationEnabled ? 'Location ready' : 'WhatsApp sign-in',
        tone: _isLocationEnabled ? StatusTone.success : StatusTone.info,
      ),
      footer: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RegistrationScreen(
                  prefillLocationEnabled: _isLocationEnabled,
                ),
              ),
            );
          },
          child: const Text('Create a GuardianNode account'),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 184,
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAltFor(context),
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? colors.surface
                                : Colors.transparent,
                            borderRadius: AppRadii.pill,
                          ),
                          child: Text(
                            'Phone',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: _selectedTab == 0
                                      ? AppColors.trustBlue
                                      : colors.onSurfaceVariant,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? colors.surface
                                : Colors.transparent,
                            borderRadius: AppRadii.pill,
                          ),
                          child: Text(
                            'Email',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: _selectedTab == 1
                                      ? AppColors.trustBlue
                                      : colors.onSurfaceVariant,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_selectedTab == 0) ...[
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+237 6 75 12 34 56',
                  prefixIcon: Icon(Icons.phone_iphone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your phone number';
                  }
                  if (value.replaceAll(' ', '').length < 8) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.card,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: SwitchListTile.adaptive(
                  value: _isLocationEnabled,
                  onChanged: _isLoading ? null : _toggleLocationSharing,
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                  title: const Text('Keep location ready for emergencies'),
                  subtitle: Text(
                    _isLocationEnabled
                        ? 'Faster routing after login.'
                        : 'You can enable this later.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  secondary: const Icon(Icons.location_searching_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: context.tr('continue_whatsapp'),
                icon: Icons.chat_rounded,
                isLoading: _isLoading,
                onPressed: _isQuickLoginLoading ? null : _handleLogin,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlineActionButton(
                text: 'Quick sign in (phone only)',
                icon: Icons.flash_on_rounded,
                onPressed: _isLoading || _isQuickLoginLoading
                    ? null
                    : _handleQuickPhoneLogin,
              ),
            ] else ...[
              if (_isEmailRegisterMode) ...[
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _registerPhoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+237 6 75 12 34 56',
                    prefixIcon: Icon(Icons.phone_iphone_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _registerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
              ] else
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                onFieldSubmitted: (_) =>
                    _isLoading ? null : _handleEmailPasswordLogin(),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _isEmailRegisterMode = !_isEmailRegisterMode),
                  child: Text(
                    _isEmailRegisterMode
                        ? 'Have an account? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                text: _isEmailRegisterMode ? 'Create account' : 'Sign in',
                icon: _isEmailRegisterMode
                    ? Icons.person_add_alt_1_rounded
                    : Icons.login_rounded,
                isLoading: _isLoading,
                onPressed: _handleEmailPasswordLogin,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
