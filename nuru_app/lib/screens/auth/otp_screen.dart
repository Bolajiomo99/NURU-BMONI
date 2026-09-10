import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_session.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_otp_input.dart';
import '../../widgets/nuru_primary_button.dart';

/// Verifies the 6-digit code emailed by /auth/signup (or re-sent by /auth/login
/// when it discovers the account is still inactive).
///
/// Expects `{'email': String}` as the route arguments. Falls back to /auth if
/// pushed without one — there is nothing useful this screen can do without it.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpKey = GlobalKey<NuruOtpInputState>();
  String _code = '';
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  String? _emailArg(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] is String) return args['email'] as String;
    return null;
  }

  Future<void> _verify(String email, String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(email: email, code: code);
      if (!mounted) return;
      final route = await resolvePostAuthRoute(ref.read(onboardingApiProvider));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } on AuthException catch (e) {
      _otpKey.currentState?.clear();
      setState(() => _error = e.message);
    } catch (_) {
      _otpKey.currentState?.clear();
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend(String email) async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authApiProvider).resendOtp(email: email);
      _otpKey.currentState?.clear();
      if (mounted) setState(() => _info = 'A new code is on its way.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not resend the code. Try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailArg(context);

    if (email == null) {
      // Pushed without an email to verify — nothing to do here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.authChoice,
            (r) => false,
          );
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: NuruTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to $email.',
                style: const TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
              ),
              const SizedBox(height: 28),
              NuruFormBanner(message: _error),
              NuruFormBanner(message: _info, kind: NuruBannerKind.success),
              NuruOtpInput(
                key: _otpKey,
                enabled: !_verifying,
                hasError: _error != null,
                onChanged: (code) => setState(() => _code = code),
                onCompleted: (code) => _verify(email, code),
              ),
              const SizedBox(height: 28),
              NuruPrimaryButton(
                label: 'Verify',
                isLoading: _verifying,
                onPressed:
                    (_verifying || _code.length != 6) ? null : () => _verify(email, _code),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: (_resending || _verifying) ? null : () => _resend(email),
                  child: Text(
                    _resending ? 'Sending…' : 'Resend code',
                    style: const TextStyle(color: NuruTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
