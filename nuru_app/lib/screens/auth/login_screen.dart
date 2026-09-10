import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_session.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_form_banner.dart';
import '../../widgets/nuru_primary_button.dart';
import '../../widgets/nuru_text_field.dart';

/// Email + password login.
///
/// A password that is correct but belongs to an unverified account (backend
/// error `email_not_verified`) sends the user to [OtpScreen] instead of
/// showing a dead-end error — the backend has already queued them a fresh
/// code by the time this response arrives.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
      await ref.read(authControllerProvider.notifier).login(
            email: email,
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      final route = await resolvePostAuthRoute(ref.read(onboardingApiProvider));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } on AuthException catch (e) {
      if (e.code == 'email_not_verified' && e.email != null) {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamed(AppRoutes.otp, arguments: {'email': e.email});
        return;
      }
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
      appBar: AppBar(title: const Text('Log In')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 28),
                NuruFormBanner(message: _error),
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NuruTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NuruTheme.primary.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: NuruTheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Testing Login (Banks & Loans Linked)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: NuruTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Email: demo@nuru.com  •  Pass: Password123!',
                        style: TextStyle(fontSize: 12, color: NuruTheme.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.flash_on_rounded, size: 16, color: NuruTheme.primary),
                          label: const Text(
                            'Quick Fill Test Credentials',
                            style: TextStyle(color: NuruTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: NuruTheme.primary.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            setState(() {
                              _emailCtrl.text = 'demo@nuru.com';
                              _passwordCtrl.text = 'Password123!';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                NuruTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                ),
                const SizedBox(height: 16),
                NuruTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context)
                            .pushNamed(AppRoutes.forgotPassword),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: NuruTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                NuruPrimaryButton(
                  label: 'Log In',
                  isLoading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.signup),
                    child: const Text(
                      'Don\'t have an account? Create one',
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
