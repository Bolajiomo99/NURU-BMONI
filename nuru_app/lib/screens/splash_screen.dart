import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../theme/nuru_theme.dart';
import '../widgets/nuru_primary_button.dart';

/// Branded landing screen and the app's entry point.
///
/// Renders synchronously — the brand mark is on the first frame, never a
/// spinner — while [startupProvider] resolves the stored token in the
/// background. Where "Get Started" leads depends on that result:
/// signed out -> /auth, mid-onboarding -> the step they left off at,
/// fully set up -> /home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  Timer? _slideTimer;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeController.forward();
    _slideTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Animation<double> _staggerFade(double begin, double end) {
    return CurvedAnimation(
      parent: _fadeController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Animation<Offset> _staggerSlide(double begin, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  /// Where a returning user belongs. Falls back to the signed-out flow while
  /// startup is still resolving, so the button is never dead.
  String _destinationRoute() {
    final startup = ref.read(startupProvider);
    return startup.maybeWhen(
      data: (state) {
        switch (state.destination) {
          case StartDestination.home:
            return AppRoutes.home;
          case StartDestination.onboarding:
            return AppRoutes.fromOnboardingStep(state.onboardingStep) ??
                AppRoutes.onboardingBusiness;
          case StartDestination.auth:
            return AppRoutes.authChoice;
        }
      },
      orElse: () => AppRoutes.authChoice,
    );
  }

  Future<void> _continue() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    HapticFeedback.mediumImpact();

    // Give the in-flight startup check a moment to land so a signed-in user
    // is not bounced to /auth, but never block the tap on it.
    try {
      await ref
          .read(startupProvider.future)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Slow or failed: fall through to the signed-out flow.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(_destinationRoute());
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: NuruTheme.heroGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        20,
                        28,
                        bottomPadding > 0 ? 12 : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),

                          // Brand mark
                          FadeTransition(
                            opacity: _staggerFade(0.0, 0.4),
                            child: SlideTransition(
                              position: _staggerSlide(0.0, 0.4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: NuruTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'N',
                                        style: TextStyle(
                                          color: Color(0xFF0A0E1A),
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NURU',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: NuruTheme.textPrimary,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      Text(
                                        'AI Financial Copilot',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: NuruTheme.primary,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Headline
                          FadeTransition(
                            opacity: _staggerFade(0.15, 0.55),
                            child: SlideTransition(
                              position: _staggerSlide(0.15, 0.55),
                              child: const Text(
                                'Your AI\nFinancial\nCopilot',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: NuruTheme.textPrimary,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Subtitle
                          FadeTransition(
                            opacity: _staggerFade(0.25, 0.65),
                            child: SlideTransition(
                              position: _staggerSlide(0.25, 0.65),
                              child: const Text(
                                'Understand your money, decide smarter, and move confidently across borders.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: NuruTheme.textSecondary,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Feature pills
                          FadeTransition(
                            opacity: _staggerFade(0.4, 0.75),
                            child: SlideTransition(
                              position: _staggerSlide(0.4, 0.75),
                              child: Column(
                                children: [
                                  _FeatureRow(
                                    icon: Icons.insights_rounded,
                                    label: 'AI-powered spending analysis',
                                  ),
                                  const SizedBox(height: 14),
                                  _FeatureRow(
                                    icon: Icons.currency_exchange_rounded,
                                    label: 'Smart USD ↔ NGN management',
                                  ),
                                  const SizedBox(height: 14),
                                  _FeatureRow(
                                    icon: Icons.fingerprint_rounded,
                                    label: 'On-device secure execution',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(flex: 3),

                          // CTA Button
                          FadeTransition(
                            opacity: _staggerFade(0.6, 1.0),
                            child: SlideTransition(
                              position: _staggerSlide(0.6, 1.0),
                              child: Column(
                                children: [
                                  NuruPrimaryButton(
                                    label: 'Get Started',
                                    icon: Icons.arrow_forward_rounded,
                                    height: 58,
                                    isLoading: _navigating,
                                    onPressed: _continue,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock_rounded,
                                        size: 14,
                                        color: NuruTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Bank-level encryption',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: NuruTheme.textMuted,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: NuruTheme.primarySubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: NuruTheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: NuruTheme.textPrimary,
            ),
          ),
        ),
        const Icon(
          Icons.check_circle_rounded,
          color: NuruTheme.primary,
          size: 18,
        ),
      ],
    );
  }
}
