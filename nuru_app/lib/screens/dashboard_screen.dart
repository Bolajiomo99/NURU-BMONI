import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/nuru_theme.dart';
import '../models/dashboard_data.dart';
import '../providers/nuru_providers.dart';
import '../services/api_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      body: dashboardAsync.when(
        loading: () => const _ShimmerDashboard(),
        error: (err, st) => _ErrorView(
          onRetry: () => ref.invalidate(dashboardProvider),
          onSettings: () => _showServerSettingsDialog(context, ref),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardProvider),
          color: NuruTheme.primary,
          backgroundColor: NuruTheme.surface,
          child: _DashboardContent(
            data: data,
            onExplain: () => _showExplainBottomSheet(context, ref),
            onSettings: () => _showServerSettingsDialog(context, ref, data.user),
            onBmoniSignup: () => _showBmoniSignupSheet(context, ref, data.user),
          ),
        ),
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context, WidgetRef ref, [UserInfo? user]) async {
    final currentUrl = await ApiService.getBaseUrl();
    final controller = TextEditingController(text: currentUrl);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NuruTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NuruTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Account & Server Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: NuruTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showBmoniSignupSheet(context, ref, user ?? UserInfo(
                  firstName: 'Bolaji',
                  lastName: 'Jimoh',
                  email: 'bolajijimoh8@gmail.com',
                  phoneNumber: '+2348123456789',
                  bmoniUserId: '',
                  onboardingComplete: false,
                ));
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NuruTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: NuruTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: NuruTheme.primary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMONI Sign Up & BVN Verification',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: NuruTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sign in with phone & verify BVN on BMONI API',
                            style: TextStyle(fontSize: 12, color: NuruTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: NuruTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Server Connection URL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NuruTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'http://192.168.43.33:8000/api',
                prefixIcon: Icon(Icons.link_rounded, color: NuruTheme.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NuruTheme.textSecondary,
                        side: const BorderSide(color: NuruTheme.surfaceLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ApiService.setBaseUrl(controller.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.invalidate(dashboardProvider);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBmoniSignupSheet(BuildContext context, WidgetRef ref, UserInfo user) {
    final firstNameCtrl = TextEditingController(text: user.firstName.isNotEmpty ? user.firstName : 'Bolaji');
    final lastNameCtrl = TextEditingController(text: user.lastName.isNotEmpty ? user.lastName : 'Jimoh');
    final emailCtrl = TextEditingController(text: user.email.isNotEmpty ? user.email : 'bolajijimoh8@gmail.com');
    final phoneCtrl = TextEditingController(text: user.phoneNumber.isNotEmpty ? user.phoneNumber : '+2348123456789');
    final bvnCtrl = TextEditingController(text: '22223333444');
    final bmoniIdCtrl = TextEditingController(text: user.bmoniUserId.isNotEmpty ? user.bmoniUserId : '');
    int activeTab = 0; // 0: Register, 1: Existing User Login
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NuruTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NuruTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: NuruTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: NuruTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMONI Account & BVN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: NuruTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Register new user or log in with live BMONI ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: NuruTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Segmented tab toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: NuruTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activeTab == 0 ? NuruTheme.surfaceElevated : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'New Signup',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: activeTab == 0 ? NuruTheme.textPrimary : NuruTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activeTab == 1 ? NuruTheme.surfaceElevated : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Existing BMONI ID',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: activeTab == 1 ? NuruTheme.textPrimary : NuruTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (activeTab == 0) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NuruTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NuruTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.science_rounded, size: 16, color: NuruTheme.primary),
                            SizedBox(width: 6),
                            Text(
                              'BMONI Sandbox Test Personas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: NuruTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  firstNameCtrl.text = 'Bunch';
                                  lastNameCtrl.text = 'Dillon';
                                  phoneCtrl.text = '08000000000';
                                  emailCtrl.text = 'bunch.dillon@example.com';
                                  bvnCtrl.text = '95888168924';
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: NuruTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: NuruTheme.surfaceLight),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Bunch Dillon\n(BVN: 95888168924)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: NuruTheme.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  firstNameCtrl.text = 'Samson';
                                  lastNameCtrl.text = 'Jabo';
                                  phoneCtrl.text = '08000000001';
                                  emailCtrl.text = 'samson.jabo@example.com';
                                  bvnCtrl.text = '22222222222';
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: NuruTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: NuruTheme.surfaceLight),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Samson Jabo\n(BVN: 22222222222)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: NuruTheme.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: firstNameCtrl,
                    style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: NuruTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameCtrl,
                    style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: NuruTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+2348123456789',
                      prefixIcon: Icon(Icons.phone_outlined, color: NuruTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined, color: NuruTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bvnCtrl,
                    style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    decoration: const InputDecoration(
                      labelText: 'Bank Verification Number (BVN)',
                      hintText: '11-digit BVN',
                      prefixIcon: Icon(Icons.badge_outlined, color: NuruTheme.textMuted),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              setState(() => isLoading = true);
                              try {
                                await ApiService.registerBmoniUser(
                                  firstName: firstNameCtrl.text.trim(),
                                  lastName: lastNameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  phoneNumber: phoneCtrl.text.trim(),
                                  bvn: bvnCtrl.text.trim(),
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ref.invalidate(dashboardProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.white),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'BMONI Account Connected & BVN Verified!',
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: NuruTheme.healthyGreen,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Onboarding failed: $e'),
                                      backgroundColor: NuruTheme.dangerRed,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_user_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Register & Verify BVN'),
                              ],
                            ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: bmoniIdCtrl,
                    style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Phone Number, Email, or Account Name',
                      hintText: 'e.g. 08071334123, ada.123@example.com, or Bolaji',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: NuruTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              setState(() => isLoading = true);
                              try {
                                final res = await ApiService.loginBmoniUser(
                                  identifier: bmoniIdCtrl.text.trim().isNotEmpty 
                                      ? bmoniIdCtrl.text.trim() 
                                      : phoneCtrl.text.trim(),
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ref.invalidate(dashboardProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Connected BMONI User (${res["user"]?["bmoni_user_id"] ?? "Active"})!',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: NuruTheme.healthyGreen,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } on BmoniAccountNotFoundException catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Colors.white),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '${e.message} Download the BMONI app to create an account first.',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: NuruTheme.textMuted,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Login failed: $e'),
                                      backgroundColor: NuruTheme.dangerRed,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Log In & Load Live Balances'),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExplainBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NuruTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          final storyAsync = ref.watch(explainStoryProvider);
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NuruTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: NuruTheme.accent, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Your Money Story',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: NuruTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                storyAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: NuruTheme.primary),
                    ),
                  ),
                  error: (err, st) => Text(
                    'Could not generate story: $err',
                    style: const TextStyle(color: NuruTheme.dangerRed),
                  ),
                  data: (storyData) {
                    final story = storyData['story'] ?? '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: NuruTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Dashboard Content ─────────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onExplain;
  final VoidCallback onSettings;
  final VoidCallback onBmoniSignup;

  const _DashboardContent({
    required this.data,
    required this.onExplain,
    required this.onSettings,
    required this.onBmoniSignup,
  });

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat('#,##0.00');

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ─── Header ─────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 0),
            child: _Header(
              user: data.user,
              onSettings: onSettings,
              onBmoniSignup: onBmoniSignup,
            ),
          ),
        ),

        // ─── Balance Card ───────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: _BalanceCard(balances: data.balances, currFmt: currFmt),
          ),
        ),

        // ─── Health + Monthly Row ───────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: _HealthCard(
                    score: data.healthScore,
                    status: data.healthStatus,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MonthlyCard(summary: data.thisMonth),
                ),
              ],
            ),
          ),
        ),

        // ─── AI Insight ─────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _InsightCard(insight: data.aiInsight, onExplain: onExplain),
          ),
        ),

        // ─── Transactions Header ────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${data.recentTransactions.length} transactions',
                  style: const TextStyle(
                    fontSize: 13,
                    color: NuruTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Transaction List ───────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final tx = data.recentTransactions[index];
                // Check if we need a date header
                final showDateHeader = index == 0 ||
                    NuruTheme.relativeDate(tx.timestamp) !=
                        NuruTheme.relativeDate(
                            data.recentTransactions[index - 1].timestamp);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) ...[
                      if (index > 0) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 4),
                        child: Text(
                          NuruTheme.relativeDate(tx.timestamp),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: NuruTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                    _TransactionTile(tx: tx),
                  ],
                );
              },
              childCount: data.recentTransactions.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Header with avatar ────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserInfo user;
  final VoidCallback onSettings;
  final VoidCallback onBmoniSignup;

  const _Header({
    required this.user,
    required this.onSettings,
    required this.onBmoniSignup,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final initials =
        '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}';

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: NuruTheme.primaryGradient,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              initials.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF0A0E1A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 13,
                  color: NuruTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.firstName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: NuruTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onBmoniSignup,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: user.onboardingComplete
                  ? NuruTheme.healthyGreen.withValues(alpha: 0.15)
                  : NuruTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: user.onboardingComplete
                    ? NuruTheme.healthyGreen.withValues(alpha: 0.4)
                    : NuruTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  user.onboardingComplete
                      ? Icons.verified_user_rounded
                      : Icons.badge_outlined,
                  color: user.onboardingComplete
                      ? NuruTheme.healthyGreen
                      : NuruTheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  user.onboardingComplete ? 'BMONI Live' : 'Verify BVN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: user.onboardingComplete
                        ? NuruTheme.healthyGreen
                        : NuruTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: NuruTheme.surfaceLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: NuruTheme.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Balance Card ──────────────────────────────────────────────────
class _BalanceCard extends StatefulWidget {
  final Balances balances;
  final NumberFormat currFmt;

  const _BalanceCard({required this.balances, required this.currFmt});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: NuruTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: NuruTheme.primary.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _hidden = !_hidden);
                },
                child: Icon(
                  _hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white60,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _hidden
                  ? '••••••'
                  : '\$${widget.currFmt.format(widget.balances.totalUsdEquivalent)}',
              key: ValueKey(_hidden),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _CurrencyPill(
                flag: '🇺🇸',
                label: 'USD',
                amount: _hidden
                    ? '••••'
                    : '\$${widget.currFmt.format(widget.balances.usd)}',
              ),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 12),
              _CurrencyPill(
                flag: '🇳🇬',
                label: 'NGN',
                amount: _hidden
                    ? '••••'
                    : '₦${widget.currFmt.format(widget.balances.ngn)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  final String flag;
  final String label;
  final String amount;

  const _CurrencyPill({
    required this.flag,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white60,
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Health Score Card with Custom Arc ──────────────────────────────
class _HealthCard extends StatelessWidget {
  final int score;
  final String status;

  const _HealthCard({required this.score, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = score >= 70
        ? NuruTheme.healthyGreen
        : score >= 40
            ? NuruTheme.warningAmber
            : NuruTheme.dangerRed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NuruTheme.divider),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _ArcGaugePainter(
                progress: score / 100.0,
                color: statusColor,
                bgColor: NuruTheme.surfaceLight,
              ),
              child: Center(
                child: Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: NuruTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Health Score',
            style: TextStyle(
              fontSize: 12,
              color: NuruTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _ArcGaugePainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = 2.3;
    const sweepAngle = 2 * math.pi - 1.0;

    // Background arc
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Monthly Summary Card ──────────────────────────────────────────
class _MonthlyCard extends StatelessWidget {
  final MonthSummary summary;

  const _MonthlyCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NuruTheme.divider),
      ),
      child: Column(
        children: [
          _MonthRow(
            icon: Icons.south_west_rounded,
            label: 'Income',
            value: '+\$${summary.incomeUsd.toStringAsFixed(0)}',
            color: NuruTheme.healthyGreen,
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: NuruTheme.divider),
          const SizedBox(height: 14),
          _MonthRow(
            icon: Icons.north_east_rounded,
            label: 'Spent',
            value: '-\$${summary.spendingUsd.toStringAsFixed(0)}',
            color: NuruTheme.dangerRed,
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: NuruTheme.divider),
          const SizedBox(height: 14),
          _MonthRow(
            icon: Icons.trending_up_rounded,
            label: 'Net',
            value: '\$${summary.netUsd.toStringAsFixed(0)}',
            color: summary.netUsd >= 0
                ? NuruTheme.healthyGreen
                : NuruTheme.dangerRed,
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MonthRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: NuruTheme.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── AI Insight Card ───────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final String insight;
  final VoidCallback onExplain;

  const _InsightCard({required this.insight, required this.onExplain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NuruTheme.accentSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NuruTheme.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: NuruTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: NuruTheme.accentLight,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Insight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NuruTheme.accentLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.isNotEmpty ? insight : 'Analyzing your transaction history...',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: NuruTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: TextButton.icon(
              onPressed: onExplain,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Explain my money'),
              style: TextButton.styleFrom(
                foregroundColor: NuruTheme.accentLight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: NuruTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Tile ──────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final RecentTransaction tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == 'credit';
    final catIcon = NuruTheme.categoryIcon(tx.category);
    final catColor = NuruTheme.categoryColor(tx.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(catIcon, color: catColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NuruTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  tx.categoryLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NuruTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${isCredit ? '+' : '-'}${tx.currency == 'USD' ? '\$' : '₦'}${tx.amount.toStringAsFixed(tx.currency == 'USD' ? 2 : 0)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isCredit ? NuruTheme.healthyGreen : NuruTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error View ────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  const _ErrorView({required this.onRetry, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: NuruTheme.dangerRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: NuruTheme.dangerRed,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connection Failed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: NuruTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure the Django backend is running\nand accessible from this device.',
              style: TextStyle(
                fontSize: 14,
                color: NuruTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ApiService.logout();
                      onRetry();
                    },
                    icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                    label: const Text('Reset Session'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NuruTheme.textSecondary,
                      side: const BorderSide(color: NuruTheme.surfaceLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NuruTheme.textSecondary,
                      side: const BorderSide(color: NuruTheme.surfaceLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer Loading Skeleton ──────────────────────────────────────
class _ShimmerDashboard extends StatelessWidget {
  const _ShimmerDashboard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: NuruTheme.surfaceLight,
      highlightColor: NuruTheme.surfaceElevated,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header skeleton
              Row(
                children: [
                  _shimmerBox(46, 46, 15),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(80, 12, 6),
                      const SizedBox(height: 6),
                      _shimmerBox(120, 20, 8),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Balance card skeleton
              _shimmerBox(double.infinity, 170, 24),
              const SizedBox(height: 16),
              // Health + Monthly row
              Row(
                children: [
                  Expanded(child: _shimmerBox(double.infinity, 165, 20)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(double.infinity, 165, 20)),
                ],
              ),
              const SizedBox(height: 16),
              // Insight skeleton
              _shimmerBox(double.infinity, 100, 20),
              const SizedBox(height: 24),
              // Transaction skeletons
              _shimmerBox(double.infinity, 62, 16),
              const SizedBox(height: 8),
              _shimmerBox(double.infinity, 62, 16),
              const SizedBox(height: 8),
              _shimmerBox(double.infinity, 62, 16),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _shimmerBox(double width, double height, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
