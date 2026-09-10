import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/onboarding_api.dart';
import '../../theme/nuru_theme.dart';
import '../../widgets/nuru_primary_button.dart';

/// Web only: shown instead of [SplashScreen] when the app cold-boots at the
/// Mono redirect URL (a *new browser tab* opened for linking, per
/// ConnectScreen's web flow — see main.dart's kIsWeb check for how this gets
/// selected over the normal splash/auth routing).
///
/// SharedPreferences on web is backed by localStorage, which this tab shares
/// with the original one on the same origin, so the auth token is already
/// there — no separate sign-in needed to complete the exchange.
class MonoCallbackScreen extends ConsumerStatefulWidget {
  final String code;

  const MonoCallbackScreen({super.key, required this.code});

  @override
  ConsumerState<MonoCallbackScreen> createState() => _MonoCallbackScreenState();
}

class _MonoCallbackScreenState extends ConsumerState<MonoCallbackScreen> {
  bool _loading = true;
  bool _success = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _complete();
  }

  Future<void> _complete() async {
    try {
      await ref.read(onboardingApiProvider).monoCallback(code: widget.code);
      if (!mounted) return;
      setState(() {
        _success = true;
        _message = 'Your account is linked. You can close this tab and return to NURU.';
      });
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not finish linking that account. Try again from NURU.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const CircularProgressIndicator(color: NuruTheme.primary)
                else ...[
                  Icon(
                    _success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: _success ? NuruTheme.healthyGreen : NuruTheme.dangerRed,
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _success ? 'Account connected' : 'Something went wrong',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: NuruTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _message,
                    style: const TextStyle(fontSize: 14, color: NuruTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  NuruPrimaryButton(
                    label: 'Return to NURU',
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.home, (r) => false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
