import 'package:flutter/material.dart';

import '../theme/nuru_theme.dart';
import 'nuru_primary_button.dart';

/// Shared chrome for the three onboarding screens: a step-N-of-3 progress
/// bar, title/subtitle, scrollable body, and a bottom bar with Continue and
/// a visible Skip.
///
/// Business, goals, and connect are each a self-contained local step — none
/// of them re-derive `next_route` from the server after an action. The step
/// after Connect always lands on /home directly; a truly abandoned flow
/// (skipped everywhere, app killed) is picked back up by the server's own
/// `next_route` on the next cold start via [startupProvider].
class OnboardingScaffold extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onContinue;
  final VoidCallback onSkip;
  final bool continueLoading;
  final String continueLabel;

  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onContinue,
    required this.onSkip,
    this.continueLoading = false,
    this.continueLabel = 'Continue',
  });

  static const int totalSteps = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 1; i <= totalSteps; i++) ...[
                    if (i > 1) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step ? NuruTheme.primary : NuruTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step $step of $totalSteps',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NuruTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: NuruTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  NuruPrimaryButton(
                    label: continueLabel,
                    isLoading: continueLoading,
                    onPressed: continueLoading ? null : onContinue,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: continueLoading ? null : onSkip,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: NuruTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
