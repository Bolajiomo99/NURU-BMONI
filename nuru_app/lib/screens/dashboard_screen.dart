import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/nuru_theme.dart';
import '../models/dashboard_data.dart';
import '../providers/nuru_providers.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: NuruTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'NURU',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: NuruTheme.primaryLight),
            tooltip: 'Server Connection Settings',
            onPressed: () => _showServerSettingsDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardProvider);
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NuruTheme.primary),
        ),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: NuruTheme.dangerRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not connect to NURU servers',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure the Django backend is running at http://localhost:8000',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.refresh(dashboardProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NuruTheme.primary,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardProvider),
          color: NuruTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting & Health Header
                _HeaderSection(user: data.user),
                const SizedBox(height: 20),

                // Financial Health Card
                _HealthScoreCard(
                  score: data.healthScore,
                  status: data.healthStatus,
                  safeWeekly: data.safeWeeklySpendUsd,
                ),
                const SizedBox(height: 20),

                // Total Balances Card (USD + NGN)
                _BalancesCard(balances: data.balances),
                const SizedBox(height: 20),

                // This Month Income / Spending Summary
                _MonthlySummaryCard(summary: data.thisMonth),
                const SizedBox(height: 20),

                // AI Insight Banner
                _AiInsightCard(
                  insight: data.aiInsight,
                  onExplainPressed: () => _showExplainBottomSheet(context, ref),
                ),
                const SizedBox(height: 24),

                // Quick Ask AI Action Button
                _AskNuruButton(),
                const SizedBox(height: 28),

                // Recent Activity
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                ...data.recentTransactions.map((tx) => _TransactionTile(tx: tx)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context, WidgetRef ref) async {
    final currentUrl = await ApiService.getBaseUrl();
    final controller = TextEditingController(text: currentUrl);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NuruTheme.surface,
        title: Row(
          children: const [
            Icon(Icons.settings_ethernet, color: NuruTheme.primaryLight),
            SizedBox(width: 8),
            Text('Server Connection', style: TextStyle(color: NuruTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter NURU backend URL for physical device testing over Wi-Fi:',
              style: TextStyle(fontSize: 13, color: NuruTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: NuruTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'http://192.168.43.33:8000/api',
                hintStyle: const TextStyle(color: NuruTheme.textMuted),
                filled: true,
                fillColor: NuruTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mac Wi-Fi IP: 192.168.43.33:8000',
              style: TextStyle(fontSize: 11, color: NuruTheme.primaryLight),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: NuruTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.setBaseUrl(controller.text);
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(dashboardProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Server URL updated!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: NuruTheme.primary),
            child: const Text('Save & Reconnect'),
          ),
        ],
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
                      color: NuruTheme.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.psychology, color: NuruTheme.primaryLight, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Explain My Finances',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: NuruTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                            height: 1.6,
                            color: NuruTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NuruTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Close Story'),
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

class _HeaderSection extends StatelessWidget {
  final UserInfo user;
  const _HeaderSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting 👋',
              style: const TextStyle(
                fontSize: 14,
                color: NuruTheme.textSecondary,
              ),
            ),
            Text(
              user.firstName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: NuruTheme.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: NuruTheme.surfaceLight.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: NuruTheme.primaryLight),
        ),
      ],
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String status;
  final double safeWeekly;

  const _HealthScoreCard({
    required this.score,
    required this.status,
    required this.safeWeekly,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = score >= 70
        ? NuruTheme.healthyGreen
        : score >= 40
            ? NuruTheme.warningYellow
            : NuruTheme.dangerRed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: NuruTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NuruTheme.surfaceLight),
      ),
      child: Row(
        children: [
          // Circular Health Score Gauge
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 8,
                    backgroundColor: NuruTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: NuruTheme.textPrimary,
                      ),
                    ),
                    const Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 10,
                        color: NuruTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Financial Health',
                      style: TextStyle(
                        fontSize: 14,
                        color: NuruTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        '🟢 $status',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Safe Weekly Spend: \$${safeWeekly.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NuruTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Based on your income & upcoming commitments',
                  style: TextStyle(
                    fontSize: 11,
                    color: NuruTheme.textMuted,
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

class _BalancesCard extends StatelessWidget {
  final Balances balances;
  const _BalancesCard({required this.balances});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,##0.00');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: NuruTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: NuruTheme.primary.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'TOTAL AVAILABLE BALANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white70,
                ),
              ),
              Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${currencyFmt.format(balances.totalUsdEquivalent)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white24,
          ),
          const SizedBox(height: 12),

          // Individual Currency Breakdowns
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'USD Account',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${currencyFmt.format(balances.usd)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NGN Account',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${currencyFmt.format(balances.ngn)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final MonthSummary summary;
  const _MonthlySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NuruTheme.surfaceLight),
      ),
      child: Row(
        children: [
          // Income
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NuruTheme.healthyGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward, color: NuruTheme.healthyGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Income', style: TextStyle(fontSize: 12, color: NuruTheme.textMuted)),
                    Text(
                      '+\$${summary.incomeUsd.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NuruTheme.healthyGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(width: 1, height: 36, color: NuruTheme.surfaceLight),

          // Spending
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NuruTheme.dangerRed.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, color: NuruTheme.dangerRed, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Spent', style: TextStyle(fontSize: 12, color: NuruTheme.textMuted)),
                    Text(
                      '-\$${summary.spendingUsd.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NuruTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  final String insight;
  final VoidCallback onExplainPressed;

  const _AiInsightCard({
    required this.insight,
    required this.onExplainPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NuruTheme.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NuruTheme.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: NuruTheme.accentLight, size: 20),
              SizedBox(width: 8),
              Text(
                'AI INSIGHT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: NuruTheme.accentLight,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.isNotEmpty ? insight : 'Analyzing your transaction history...',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: NuruTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onExplainPressed,
              icon: const Icon(Icons.psychology, size: 18),
              label: const Text('Explain My Money'),
              style: TextButton.styleFrom(
                foregroundColor: NuruTheme.accentLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskNuruButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text(
          'Ask NURU AI',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: NuruTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final RecentTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == 'credit';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit
                  ? NuruTheme.healthyGreen.withOpacity(0.12)
                  : NuruTheme.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? NuruTheme.healthyGreen : NuruTheme.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
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
                ),
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
          Text(
            '${isCredit ? '+' : '-'}${tx.currency == 'USD' ? '\$' : '₦'}${tx.amount.toStringAsFixed(tx.currency == 'USD' ? 2 : 0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isCredit ? NuruTheme.healthyGreen : NuruTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
