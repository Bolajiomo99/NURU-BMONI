import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_session.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_primary_button.dart';
import '../../widgets/nuru_text_field.dart';

/// Requests a password-reset email.
///
/// The backend always returns 200 here regardless of whether the email
/// exists, so there is no separate "not found" state to design for — success
/// is the only non-error outcome and the copy stays deliberately vague.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authApiProvider)
          .forgotPassword(email: _emailCtrl.text.trim().toLowerCase());
      if (mounted) setState(() => _sent = true);
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
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email and we\'ll send you a link to reset it.',
                  style: TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
                ),
                const SizedBox(height: 28),
                NuruFormBanner(message: _error),
                if (_sent)
                  const NuruFormBanner(
                    kind: NuruBannerKind.success,
                    message:
                        'If an account exists for that email, a reset link is on its way. '
                        'Check your inbox.',
                  ),
                if (!_sent) ...[
                  NuruTextField(
                    label: 'Email',
                    controller: _emailCtrl,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your email'
                        : null,
                  ),
                  const SizedBox(height: 28),
                  NuruPrimaryButton(
                    label: 'Send Reset Link',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRoutes.resetPassword),
                    child: const Text(
                      'Already have a reset code? Enter it here',
                      style: TextStyle(color: NuruTheme.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
