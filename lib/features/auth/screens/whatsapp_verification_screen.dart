import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import '../widgets/auth_scaffold.dart';

class WhatsappVerificationScreen extends StatefulWidget {
  const WhatsappVerificationScreen({
    super.key,
    required this.verificationId,
    required this.token,
    required this.whatsappUrl,
    required this.phoneNumber,
    required this.purpose,
    required this.onVerified,
    required this.onRequestNew,
    this.onAuthRuleFailure,
    this.confirmClickLoader,
    this.whatsappLauncher,
    this.statusLoader,
    this.expiresAt,
    this.title = 'Verify with WhatsApp',
    this.subtitle =
        'Send the prepared message and GuardianNode will continue automatically.',
  });

  final String verificationId;
  final String token;
  final String whatsappUrl;
  final String phoneNumber;
  final String purpose;
  final Future<void> Function(Map<String, dynamic>) onVerified;
  final Future<Map<String, dynamic>> Function() onRequestNew;
  final void Function(String code)? onAuthRuleFailure;
  final Future<Map<String, dynamic>> Function({
    required String verificationId,
    required String phoneNumber,
  })?
  confirmClickLoader;
  final Future<bool> Function(Uri uri)? whatsappLauncher;
  final Future<Map<String, dynamic>> Function(String verificationId)?
  statusLoader;
  final String? expiresAt;
  final String title;
  final String subtitle;

  @override
  State<WhatsappVerificationScreen> createState() =>
      _WhatsappVerificationScreenState();
}

class _WhatsappVerificationScreenState
    extends State<WhatsappVerificationScreen> {
  late String _verificationId;
  late String _token;
  late String _whatsappUrl;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _lastCheckedTimer;

  bool _isPolling = false;
  bool _isOpeningWhatsapp = false;
  bool _isRequestingNew = false;
  bool _whatsappOpened = false;
  String _status = 'pending';
  String _message = 'Waiting for your WhatsApp verification message.';

  Duration _timeLeft = const Duration(minutes: 10);
  DateTime? _expiryTime;
  DateTime _lastCheckedTime = DateTime.now();
  int _secondsElapsedSinceStart = 0;

  void _logVerification(String message) {
    if (kDebugMode) {
      debugPrint('[VERIFY_SCREEN] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _token = widget.token;
    _whatsappUrl = widget.whatsappUrl;
    _initExpiry();
    _startTimers();
    unawaited(_pollStatus());
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _initExpiry() {
    try {
      final expAt = widget.expiresAt;
      if (expAt != null) {
        _expiryTime = DateTime.parse(expAt).toLocal();
        _timeLeft = _expiryTime!.difference(DateTime.now());
        if (_timeLeft.isNegative) {
          _timeLeft = Duration.zero;
          _status = 'expired';
        }
        return;
      }
    } catch (e) {
      // Fall through
    }
    _expiryTime = DateTime.now().add(const Duration(minutes: 10));
    _timeLeft = const Duration(minutes: 10);
  }

  void _startTimers() {
    _cancelTimers();

    // Poll status every 3 seconds as required
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );

    // Expiry countdown timer every 1 second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsedSinceStart++;
        if (_expiryTime != null) {
          _timeLeft = _expiryTime!.difference(DateTime.now());
          if (_timeLeft.isNegative) {
            _timeLeft = Duration.zero;
            _status = 'expired';
            _cancelTimers();
            _message =
                'Your verification link has expired. Please request a new one.';
          }
        }
      });
    });

    // Rebuild UI every second to update "Last checked X seconds ago" dynamically
    _lastCheckedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _lastCheckedTimer?.cancel();
    _pollTimer = null;
    _countdownTimer = null;
    _lastCheckedTimer = null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatLastChecked() {
    final difference = DateTime.now().difference(_lastCheckedTime).inSeconds;
    if (difference < 4) {
      return 'just now';
    }
    return '$difference seconds ago';
  }

  Future<void> _pollStatus({bool manual = false}) async {
    if (_isPolling || (['expired', 'failed'].contains(_status) && !manual)) {
      return;
    }

    setState(() {
      _isPolling = true;
    });
    _logVerification('checking verificationId=$_verificationId');

    try {
      final response =
          await (widget.statusLoader ?? ApiService.getVerificationStatus)(
            _verificationId,
          );

      if (!mounted) return;

      setState(() {
        _lastCheckedTime = DateTime.now();
      });

      if (response['success'] != true) {
        setState(() {
          _message =
              response['message']?.toString() ??
              'Verification status could not be refreshed.';
        });
        return;
      }

      final status = response['status']?.toString() ?? 'pending';
      _logVerification('status=$status');

      if (response['verified'] == true || status == 'verified') {
        final session = _sessionFromVerifiedResponse(response);
        _logVerification(
          'authToken received=${session?['access_token'] != null ? 'yes' : 'no'}',
        );

        if (session != null) {
          _cancelTimers();
          _logVerification('navigating to dashboard');
          await widget.onVerified(session);
          return;
        }

        final authStillCompleting =
            response['authReady'] == false ||
            response['nextStep']?.toString() == 'completing_auth';

        if (authStillCompleting) {
          setState(() {
            _status = 'verified';
            _message = 'WhatsApp verified. Finishing secure sign-in...';
          });
          return;
        }

        _cancelTimers();
        setState(() {
          _status = 'failed';
          _message =
              'WhatsApp verification completed, but secure sign-in could not be created. Generate a new link and try again.';
        });
        return;
      }

      if (status == 'expired') {
        _cancelTimers();
        setState(() {
          _status = 'expired';
          _timeLeft = Duration.zero;
          _message =
              'Your verification link has expired. Please request a new one.';
        });
        return;
      }

      if (status == 'failed') {
        _cancelTimers();
        setState(() {
          _status = 'failed';
          _message =
              response['message']?.toString() ??
              'Verification failed. Please generate a new link.';
        });
        return;
      }

      setState(() {
        _status = status;
        _message = 'Waiting for your WhatsApp verification message.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Connection error. Retrying...';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPolling = false;
        });
      }
    }
  }

  Future<void> _handleConfirmWhatsappClick() async {
    try {
      final response =
          await (widget.confirmClickLoader ?? ApiService.confirmWhatsappClick)(
            verificationId: _verificationId,
            phoneNumber: widget.phoneNumber,
          );

      if (!mounted) return;

      if (response['success'] == true) {
        final session = _sessionFromVerifiedResponse(response);
        if (session != null) {
          _cancelTimers();
          _logVerification('navigating to dashboard via confirm-click');
          await widget.onVerified(session);
          return;
        }

        _cancelTimers();
        setState(() {
          _status = 'failed';
          _message =
              'WhatsApp verification succeeded, but a secure session was not returned.';
        });
        return;
      }

      final code = response['code']?.toString();
      if (code == 'PHONE_NOT_REGISTERED' ||
          code == 'PHONE_ALREADY_EXISTS' ||
          code == 'ACCOUNT_NOT_ALLOWED') {
        await _showAuthRuleError(code!);
        return;
      }

      StatusSnackbar.show(
        context,
        message:
            response['message']?.toString() ??
            'Verification could not be confirmed.',
        tone: StatusTone.error,
      );
    } catch (e) {
      _logVerification('confirm-whatsapp-click error: $e');
      if (mounted) {
        StatusSnackbar.show(
          context,
          message: ApiClient.friendlyMessage(e),
          tone: StatusTone.error,
        );
      }
    }
  }

  Future<void> _showAuthRuleError(String code) async {
    _cancelTimers();
    final isMissingAccount = code == 'PHONE_NOT_REGISTERED';
    final isExistingAccount = code == 'PHONE_ALREADY_EXISTS';
    final title = isMissingAccount
        ? 'Account Not Found'
        : isExistingAccount
        ? 'Account Already Exists'
        : 'Sign In Not Allowed';
    final message = isMissingAccount
        ? 'This phone number is not registered. Please create an account first.'
        : isExistingAccount
        ? 'This phone number is already registered. Please login instead.'
        : 'This account is not allowed to sign in. Please contact support.';
    final actionLabel = isMissingAccount
        ? 'Create account'
        : isExistingAccount
        ? 'Go to login'
        : 'Close';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              final callback = widget.onAuthRuleFailure;
              if (callback != null) {
                callback(code);
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsapp() async {
    setState(() {
      _isOpeningWhatsapp = true;
      _whatsappOpened = true;
    });

    try {
      final uri = Uri.parse(_whatsappUrl);
      final launched = widget.whatsappLauncher != null
          ? await widget.whatsappLauncher!(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        if (mounted) {
          StatusSnackbar.show(
            context,
            message: 'WhatsApp could not be opened on this device.',
            tone: StatusTone.error,
          );
        }
        return;
      }

      await _handleConfirmWhatsappClick();
    } finally {
      if (mounted) {
        setState(() => _isOpeningWhatsapp = false);
      }
    }
  }

  Future<void> _requestNew() async {
    setState(() => _isRequestingNew = true);

    try {
      final response = await widget.onRequestNew();

      if (!mounted) return;

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message:
              response['message']?.toString() ??
              'A new verification link could not be created.',
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
      final purpose = response['purpose']?.toString();

      if (verificationId == null ||
          token == null ||
          whatsappUrl == null ||
          (purpose != null && purpose != widget.purpose)) {
        StatusSnackbar.show(
          context,
          message: 'The backend returned an invalid verification link.',
          tone: StatusTone.error,
        );
        return;
      }

      setState(() {
        _verificationId = verificationId;
        _token = token;
        _whatsappUrl = whatsappUrl;
        _status = 'pending';
        _whatsappOpened = false;
        _secondsElapsedSinceStart = 0;
        _message = 'Waiting for your WhatsApp verification message.';
        _lastCheckedTime = DateTime.now();
        if (expiresAt != null) {
          _expiryTime = DateTime.parse(expiresAt).toLocal();
        } else {
          _expiryTime = DateTime.now().add(const Duration(minutes: 10));
        }
        _timeLeft = _expiryTime!.difference(DateTime.now());
        if (_timeLeft.isNegative) {
          _timeLeft = Duration.zero;
        }
      });
      _startTimers();
      unawaited(_pollStatus());
    } finally {
      if (mounted) {
        setState(() => _isRequestingNew = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isExpired = _status == 'expired';
    final isFailed = _status == 'failed';
    final showWarning =
        !isExpired && !isFailed && _secondsElapsedSinceStart > 30;

    return AuthScaffold(
      eyebrow: 'WhatsApp authentication',
      title: widget.title,
      subtitle: widget.subtitle,
      badge: AuthHeroBadge(
        label: isExpired
            ? 'Link expired'
            : isFailed
            ? 'Verification failed'
            : 'Waiting on WhatsApp',
        tone: isExpired || isFailed ? StatusTone.warning : StatusTone.action,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: isExpired
                    ? (AppColors.isDark(context)
                          ? const Color(0xFF332B12)
                          : AppColors.communityYellowSurface)
                    : (AppColors.isDark(context)
                          ? const Color(0xFF0F2D24)
                          : AppColors.safetyGreenSurface),
                borderRadius: AppRadii.card,
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Icon(
                isExpired
                    ? Icons.schedule_rounded
                    : Icons.mark_chat_read_outlined,
                color: isExpired
                    ? const Color(0xFF8A5A00)
                    : AppColors.safetyGreen,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Tap the button below to send your verification message on WhatsApp. Once sent, this page will update automatically.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.card,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                Text(
                  'Verification message',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  _token,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            title: isExpired
                ? 'Expired'
                : 'Expires in: ${_formatDuration(_timeLeft)}',
            message: 'This verification link is active for 10 minutes.',
          ),
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            title: isExpired
                ? 'Expired'
                : isFailed
                ? 'Verification failed'
                : 'Waiting for WhatsApp',
            message: showWarning
                ? 'Still waiting. Make sure the message was sent to the GuardianNode business number (+237 6 57 26 20 38).'
                : _message,
            tone: isExpired || isFailed
                ? StatusTone.warning
                : (showWarning ? StatusTone.warning : StatusTone.info),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!isExpired && !isFailed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last checked: ${_formatLastChecked()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiaryFor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Checking every 3 seconds',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiaryFor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            text: _whatsappOpened ? 'Open WhatsApp again' : 'Open WhatsApp',
            icon: Icons.chat_rounded,
            isLoading: _isOpeningWhatsapp,
            onPressed: (isExpired || isFailed) ? null : _openWhatsapp,
          ),
          if (!isExpired && !isFailed) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'I have sent the message \u2014 Check now',
              icon: Icons.check_circle_outline_rounded,
              tone: AppButtonTone.secondary,
              isLoading: _isPolling,
              onPressed: () => _pollStatus(manual: true),
            ),
          ],
          if (isExpired || isFailed) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Generate new link',
              icon: Icons.refresh_rounded,
              tone: AppButtonTone.outline,
              isLoading: _isRequestingNew,
              onPressed: _requestNew,
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? _sessionFromVerifiedResponse(
    Map<String, dynamic> response,
  ) {
    final session = response['session'];
    if (session is Map) {
      return Map<String, dynamic>.from(session);
    }

    final authToken = response['authToken']?.toString();
    final user = response['user'];
    if (authToken == null || authToken.isEmpty || user is! Map) {
      return null;
    }

    return {
      'access_token': authToken,
      'token_type': 'Bearer',
      'user': Map<String, dynamic>.from(user),
    };
  }
}
