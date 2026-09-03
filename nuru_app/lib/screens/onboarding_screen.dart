import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/nuru_theme.dart';
import 'bottom_nav_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
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
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ));
  }

  void _navigateToDashboard() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondary) => const BottomNavShell(),
        transitionsBuilder: (context, animation, secondary, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: NuruTheme.heroGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 20, 28, bottomPadding > 0 ? 12 : 24),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              'by BMONI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: NuruTheme.textMuted,
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
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: NuruTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: NuruTheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _navigateToDashboard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0A0E1A),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Color(0xFF0A0E1A),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                              'Secured by BMONI Infrastructure',
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
