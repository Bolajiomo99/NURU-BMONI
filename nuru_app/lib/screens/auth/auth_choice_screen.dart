import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_primary_button.dart';

/// Landing screen for a signed-out user: create an account or log in.
///
/// Reached only via [SplashScreen]'s pushReplacementNamed, so there is
/// nothing beneath it on the stack — no back button.
class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: NuruTheme.heroGradient),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 20, 28, bottomPadding > 0 ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: NuruTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            color: Color(0xFF0A0E1A),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'NURU',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: NuruTheme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: NuruTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Create an account or log in to manage your money across borders.',
                  style: TextStyle(
                    fontSize: 16,
                    color: NuruTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const Spacer(flex: 3),
                NuruPrimaryButton(
                  label: 'Create Account',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.signup),
                ),
                const SizedBox(height: 14),
                NuruSecondaryButton(
                  label: 'I already have an account',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
