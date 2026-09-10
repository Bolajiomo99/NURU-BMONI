import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_session.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_primary_button.dart';
import '../../widgets/nuru_text_field.dart';

/// Create-account form. Signup itself does not sign the user in — it emails
/// a 6-digit code and the account stays inactive until [OtpScreen] verifies
/// it, so this screen only ever navigates forward to /auth/otp.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
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

    final email = _emailCtrl.text.trim().toLowerCase();

    try {
      await ref.read(authApiProvider).signup(
            name: _nameCtrl.text.trim(),
            email: email,
            password: _passwordCtrl.text,
            confirmPassword: _confirmCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.otp, arguments: {'email': email});
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
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Let\'s get you set up',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We\'ll email you a code to verify your account.',
                  style: TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
                ),
                const SizedBox(height: 28),
                NuruFormBanner(message: _error),
                NuruTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                NuruTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter your email';
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                NuruTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                NuruTextField(
                  label: 'Confirm Password',
                  controller: _confirmCtrl,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                NuruPrimaryButton(
                  label: 'Create Account',
                  isLoading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.login),
                    child: const Text(
                      'Already have an account? Log in',
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
