import 'package:flutter/material.dart';

import '../theme/nuru_theme.dart';

enum NuruBannerKind { error, success, info }

/// Inline status banner for form-level messages.
///
/// Used instead of a SnackBar for auth errors: the message needs to stay
/// visible while the user corrects the field, and it must not cover the
/// keyboard or the submit button.
class NuruFormBanner extends StatelessWidget {
  final String? message;
  final NuruBannerKind kind;

  const NuruFormBanner({
    super.key,
    required this.message,
    this.kind = NuruBannerKind.error,
  });

  Color get _color => switch (kind) {
        NuruBannerKind.error => NuruTheme.dangerRed,
        NuruBannerKind.success => NuruTheme.healthyGreen,
        NuruBannerKind.info => NuruTheme.accentLight,
      };

  IconData get _icon => switch (kind) {
        NuruBannerKind.error => Icons.error_outline_rounded,
        NuruBannerKind.success => Icons.check_circle_outline_rounded,
        NuruBannerKind.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final text = message;
    // Collapses to nothing when there is no message, so callers can render it
    // unconditionally without juggling SizedBox.shrink().
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 18, color: _color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: _color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
