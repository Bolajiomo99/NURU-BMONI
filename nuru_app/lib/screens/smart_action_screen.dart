import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/nuru_theme.dart';
import '../providers/nuru_providers.dart';
import '../widgets/transaction_auth_sheet.dart';
import 'confirmation_screen.dart';

class SmartActionScreen extends ConsumerWidget {
  const SmartActionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(activeActionProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    if (action == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart Action')),
        body: const Center(child: Text('No action selected')),
      );
    }

    final isTransfer = action.type == 'transfer';
    final amount = action.amount;
    final currency = action.currency;

    double currentBalance = 2305.55;
    double safeWeekly = 478.0;

    dashboardAsync.whenData((data) {
      currentBalance = data.balances.usd;
      safeWeekly = data.safeWeeklySpendUsd;
    });

    final balanceAfter = currentBalance - amount;

    return Scaffold(
      backgroundColor: NuruTheme.background,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ──────────────────
          SliverAppBar(
            backgroundColor: NuruTheme.background,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NuruTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: NuruTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
            title: const Text(
              'Review Action',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NuruTheme.textPrimary,
              ),
            ),
            centerTitle: true,
            pinned: true,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ─── Hero Amount ──────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: NuruTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: NuruTheme.divider),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: NuruTheme.primarySubtle,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            isTransfer
                                ? Icons.send_rounded
                                : Icons.swap_horiz_rounded,
                            color: NuruTheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '\$${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: NuruTheme.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isTransfer
                              ? 'Transfer $currency'
                              : 'Convert USD → ${action.toCurrency}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: NuruTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isTransfer && action.to.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'To: ${action.to}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: NuruTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Recipient Account Details ──────────
                  if (isTransfer) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: NuruTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NuruTheme.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_rounded, size: 18, color: NuruTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'Recipient Account Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: NuruTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ImpactRow(
                            label: 'Account Name',
                            value: action.accountName.isNotEmpty ? action.accountName : (action.to.isNotEmpty ? action.to : 'Beneficiary'),
                            color: NuruTheme.textPrimary,
                          ),
                          if (action.bankName.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _ImpactRow(
                              label: 'Bank Name',
                              value: action.bankName,
                              color: NuruTheme.textPrimary,
                            ),
                          ],
                          if (action.accountNumber.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _ImpactRow(
                              label: 'Account Number',
                              value: action.accountNumber,
                              color: NuruTheme.primaryLight,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Financial Impact ─────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: NuruTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NuruTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Financial Impact',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: NuruTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ImpactRow(
                          label: 'Current Balance',
                          value: '\$${currentBalance.toStringAsFixed(2)}',
                          color: NuruTheme.textPrimary,
                        ),
                        const SizedBox(height: 12),
                        _ImpactRow(
                          label: 'After This Action',
                          value: '\$${balanceAfter.toStringAsFixed(2)}',
                          color: NuruTheme.primaryLight,
                        ),
                        const SizedBox(height: 12),
                        _ImpactRow(
                          label: 'Safe Weekly Budget',
                          value: '\$${safeWeekly.toStringAsFixed(0)}/wk',
                          color: NuruTheme.textMuted,
                        ),
                        const SizedBox(height: 16),
                        // Visual progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (balanceAfter / currentBalance).clamp(0.0, 1.0),
                            backgroundColor: NuruTheme.surfaceLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              balanceAfter > safeWeekly
                                  ? NuruTheme.healthyGreen
                                  : NuruTheme.warningAmber,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Why NURU Recommends ───
                  _ReasonCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: NuruTheme.healthyGreen,
                    title: 'Within Safe Range',
                    detail:
                        'Remaining \$${balanceAfter.toStringAsFixed(0)} stays above your \$${safeWeekly.toStringAsFixed(0)} weekly threshold.',
                  ),
                  const SizedBox(height: 10),
                  _ReasonCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: NuruTheme.primary,
                    title: 'Positive Cash Flow',
                    detail:
                        'Your income grew this month, providing ample liquidity buffer.',
                  ),
                  const SizedBox(height: 10),
                  _ReasonCard(
                    icon: Icons.shield_rounded,
                    iconColor: NuruTheme.accent,
                    title: 'Secure Execution',
                    detail:
                        'Private keys never leave your device. Signed in Secure Enclave.',
                  ),
                  // ─── Authorize Action (PIN + Face 2FA) ─────
                  _AuthorizeActionButton(
                    isTransfer: isTransfer,
                    amount: amount,
                    currency: currency,
                    onAuthorized: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const ConfirmationScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Impact Row ────────────────────────────────────────────────────
class _ImpactRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ImpactRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: NuruTheme.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Reason Card ───────────────────────────────────────────────────
class _ReasonCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;

  const _ReasonCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NuruTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NuruTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Authorize Action Button (PIN & Face 2FA) ─────────────────────
class _AuthorizeActionButton extends StatelessWidget {
  final bool isTransfer;
  final double amount;
  final String currency;
  final VoidCallback onAuthorized;

  const _AuthorizeActionButton({
    required this.isTransfer,
    required this.amount,
    required this.currency,
    required this.onAuthorized,
  });

  @override
  Widget build(BuildContext context) {
    final title = isTransfer
        ? 'Authorize Transfer ($currency ${amount.toStringAsFixed(0)})'
        : 'Authorize Swap ($currency ${amount.toStringAsFixed(0)})';
    final detail = isTransfer
        ? '2FA Security Authorization for outgoing transfer'
        : '2FA Security Authorization for currency conversion';

    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: NuruTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: NuruTheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            TransactionAuthSheet.show(
              context,
              actionTitle: title,
              actionDetail: detail,
              onAuthorized: onAuthorized,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: NuruTheme.background,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: NuruTheme.background,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: NuruTheme.background,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
