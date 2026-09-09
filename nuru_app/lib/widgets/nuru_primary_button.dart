import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/nuru_theme.dart';

/// The app's primary CTA: gradient fill, haptics, and a loading state that
/// swaps the label for a spinner while keeping the button's height stable.
///
/// Lifted from the pattern the splash screen used inline, so every screen gets
/// the same button instead of re-declaring the gradient + shadow each time.
class NuruPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const NuruPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 56,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _enabled ? NuruTheme.primaryGradient : null,
          color: _enabled ? null : NuruTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: NuruTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: _enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  onPressed!();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0A0E1A)),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _enabled
                            ? const Color(0xFF0A0E1A)
                            : NuruTheme.textMuted,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        icon,
                        size: 20,
                        color: _enabled
                            ? const Color(0xFF0A0E1A)
                            : NuruTheme.textMuted,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary action: outlined, no fill. Used for "I already have an account"
/// and the onboarding Skip actions.
class NuruSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const NuruSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: NuruTheme.textPrimary,
          side: const BorderSide(color: NuruTheme.surfaceElevated, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
