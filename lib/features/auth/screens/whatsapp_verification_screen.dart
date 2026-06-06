import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
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
    required this.onVerified,
    required this.onRequestNew,
    this.title = 'Verify with WhatsApp',
    this.subtitle =
        'Send the prepared message and GuardianNode will continue automatically.',
  });

  final String verificationId;
  final String token;
  final String whatsappUrl;
  final ValueChanged<Map<String, dynamic>> onVerified;
  final Future<Map<String, dynamic>> Function() onRequestNew;
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
  bool _isPolling = false;
  bool _isOpeningWhatsapp = false;
  bool _isRequestingNew = false;
  String _status = 'pending';
  String _message = 'Waiting for your WhatsApp verification message.';

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _token = widget.token;
    _whatsappUrl = widget.whatsappUrl;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );
  }

  Future<void> _pollStatus() async {
    if (_isPolling || _status == 'expired') {
      return;
    }

    _isPolling = true;

    try {
      final response = await ApiService.getVerificationStatus(_verificationId);

      if (!mounted) {
        return;
      }

      if (response['success'] != true) {
        setState(() {
          _message =
              response['message']?.toString() ??
              'Verification status could not be refreshed.';
        });
        return;
      }

      final status = response['status']?.toString() ?? 'pending';

      if (response['verified'] == true || status == 'verified') {
        _pollTimer?.cancel();
        final session = response['session'];

        if (session is Map) {
          widget.onVerified(Map<String, dynamic>.from(session));
          return;
        }

        setState(() {
          _message = 'Verification succeeded, but no app session was returned.';
        });
        return;
      }

      if (status == 'expired') {
        _pollTimer?.cancel();
        setState(() {
          _status = 'expired';
          _message =
              'Your verification link has expired. Please request a new one.';
        });
        return;
      }

      setState(() {
        _status = status;
        _message = 'Waiting for your WhatsApp verification message.';
      });
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _openWhatsapp() async {
    setState(() => _isOpeningWhatsapp = true);

    try {
      final launched = await launchUrl(
        Uri.parse(_whatsappUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        StatusSnackbar.show(
          context,
          message: 'WhatsApp could not be opened on this device.',
          tone: StatusTone.error,
        );
      }
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

      if (!mounted) {
        return;
      }

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

      if (verificationId == null || token == null || whatsappUrl == null) {
        StatusSnackbar.show(
          context,
          message: 'The backend returned an incomplete verification link.',
          tone: StatusTone.error,
        );
        return;
      }

      setState(() {
        _verificationId = verificationId;
        _token = token;
        _whatsappUrl = whatsappUrl;
        _status = 'pending';
        _message = 'Waiting for your WhatsApp verification message.';
      });
      _startPolling();
    } finally {
      if (mounted) {
        setState(() => _isRequestingNew = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _status == 'expired';

    return AuthScaffold(
      heroIcon: Icons.chat_bubble_outline_rounded,
      eyebrow: 'WhatsApp authentication',
      title: widget.title,
      subtitle: widget.subtitle,
      badge: AuthHeroBadge(
        label: isExpired ? 'Link expired' : 'Waiting on WhatsApp',
        tone: isExpired ? StatusTone.warning : StatusTone.action,
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
                    ? AppColors.communityYellowSurface
                    : AppColors.safetyGreenSurface,
                borderRadius: AppRadii.card,
                border: Border.all(color: AppColors.border),
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
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.card,
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              _token,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.trustBlueDark,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const InfoBanner(
            title: 'Link expiry',
            message: 'This verification link expires in 10 minutes.',
          ),
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            title: isExpired ? 'Expired' : 'Waiting for WhatsApp',
            message: _message,
            tone: isExpired ? StatusTone.warning : StatusTone.info,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            text: 'Verify via WhatsApp',
            icon: Icons.chat_rounded,
            isLoading: _isOpeningWhatsapp,
            onPressed: isExpired ? null : _openWhatsapp,
          ),
          if (isExpired) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Request a new link',
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
}
