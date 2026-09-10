import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_session.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_primary_button.dart';
import '../../widgets/nuru_text_field.dart';

/// Consumes a password-reset token and sets a new password.
///
/// The mobile app has no deep-link scheme configured, so the token field is
/// always user-editable — the email's "Reset password" link and pasted-code
/// fallback both land here. On web only, [_prefillTokenFromUrl] best-effort
/// reads `?token=` from the current URL, which is populated when the emailed
/// link itself opened this build (see email_service.send_password_reset_email).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillTokenFromUrl();
  }

  void _prefillTokenFromUrl() {
    if (!kIsWeb) return;
    try {
      // Hash-routed URLs (http://host/#/auth/reset?token=xyz) carry the query
      // string inside the fragment, not Uri.base's own query component.
      final fragment = Uri.base.fragment;
      final queryStart = fragment.indexOf('?');
      if (queryStart == -1) return;
      final token = Uri.splitQueryString(fragment.substring(queryStart + 1))['token'];
      if (token != null && token.isNotEmpty) _tokenCtrl.text = token;
    } catch (_) {
      // Malformed fragment: leave the field for the user to paste into.
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authApiProvider).resetPassword(
            token: _tokenCtrl.text.trim(),
            newPassword: _passwordCtrl.text,
            confirmPassword: _confirmCtrl.text,
          );
      if (mounted) setState(() => _done = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _done ? _buildDone(context) : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password updated',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: NuruTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been changed. Log in with your new password.',
          style: TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
        ),
        const SizedBox(height: 28),
        NuruPrimaryButton(
          label: 'Log In',
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set a new password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: NuruTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste the reset code from your email, then choose a new password.',
            style: TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
          ),
          const SizedBox(height: 28),
          NuruFormBanner(message: _error),
          NuruTextField(
            label: 'Reset Code',
            controller: _tokenCtrl,
            prefixIcon: Icons.vpn_key_outlined,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Paste your reset code' : null,
          ),
          const SizedBox(height: 16),
          NuruTextField(
            label: 'New Password',
            controller: _passwordCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          NuruTextField(
            label: 'Confirm New Password',
            controller: _confirmCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your new password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 28),
          NuruPrimaryButton(
            label: 'Update Password',
            isLoading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
