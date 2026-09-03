import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/nuru_theme.dart';
import '../providers/nuru_providers.dart';
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
      appBar: AppBar(
        title: const Text(
          'SMART ACTION',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Action Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: NuruTheme.cardGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NuruTheme.primary.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: NuruTheme.primary.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NuruTheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTransfer ? Icons.send : Icons.swap_horiz,
                      color: NuruTheme.primaryLight,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTransfer
                        ? 'Transfer \$${amount.toStringAsFixed(2)} $currency'
                        : 'Convert \$${amount.toStringAsFixed(2)} USD → ${action.toCurrency}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: NuruTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTransfer
                        ? 'Recipient: ${action.to.isNotEmpty ? action.to : "Family support"}'
                        : 'Local currency liquidity management',
                    style: const TextStyle(fontSize: 14, color: NuruTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Why NURU Recommends This
            Text(
              'Why NURU Recommends This',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NuruTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NuruTheme.surfaceLight),
              ),
              child: Column(
                children: [
                  _ReasonRow(
                    icon: Icons.check_circle_outline,
                    title: 'Within Safe Spending Range',
                    detail:
                        'After this \$${amount.toStringAsFixed(0)} operation, your remaining USD balance (\$${balanceAfter.toStringAsFixed(2)}) stays well above your safe weekly threshold (\$${safeWeekly.toStringAsFixed(0)}).',
                  ),
                  const Divider(height: 24, color: NuruTheme.surfaceLight),
                  _ReasonRow(
                    icon: Icons.trending_up,
                    title: 'Positive Cash Flow',
                    detail: 'Your freelance income grew 28.7% this month, providing ample liquidity buffer.',
                  ),
                  const Divider(height: 24, color: NuruTheme.surfaceLight),
                  _ReasonRow(
                    icon: Icons.security,
                    title: 'On-Device Key Security',
                    detail: 'Private signing keys never leave your device Secure Enclave / Keystore.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Financial Impact Summary
            Text(
              'Financial Impact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NuruTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Current Balance', style: TextStyle(fontSize: 12, color: NuruTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NuruTheme.textPrimary),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: NuruTheme.textMuted),
                  Column(
                    children: [
                      const Text('After Operation', style: TextStyle(fontSize: 12, color: NuruTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${balanceAfter.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NuruTheme.primaryLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Confirm Execute Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const ConfirmationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NuruTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Execute via BMONI',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.lock_clock),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _ReasonRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: NuruTheme.healthyGreen, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
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
    );
  }
}
