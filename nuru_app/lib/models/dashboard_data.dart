class UserInfo {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String bmoniUserId;
  final bool onboardingComplete;

  UserInfo({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.bmoniUserId,
    required this.onboardingComplete,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      firstName: json['first_name'] ?? 'User',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      bmoniUserId: json['bmoni_user_id'] ?? '',
      onboardingComplete: json['onboarding_complete'] ?? false,
    );
  }
}

class Balances {
  final double usd;
  final double ngn;
  final double totalUsdEquivalent;

  Balances({
    required this.usd,
    required this.ngn,
    required this.totalUsdEquivalent,
  });

  factory Balances.fromJson(Map<String, dynamic> json) {
    return Balances(
      usd: (json['usd'] ?? 0.0).toDouble(),
      ngn: (json['ngn'] ?? 0.0).toDouble(),
      totalUsdEquivalent: (json['total_usd_equivalent'] ?? 0.0).toDouble(),
    );
  }
}

class MonthSummary {
  final double incomeUsd;
  final double incomeNgn;
  final double spendingUsd;
  final double spendingNgn;
  final double netUsd;
  final double netNgn;

  MonthSummary({
    required this.incomeUsd,
    required this.incomeNgn,
    required this.spendingUsd,
    required this.spendingNgn,
    required this.netUsd,
    required this.netNgn,
  });

  factory MonthSummary.fromJson(Map<String, dynamic> json) {
    return MonthSummary(
      incomeUsd: (json['income_usd'] ?? 0.0).toDouble(),
      incomeNgn: (json['income_ngn'] ?? 0.0).toDouble(),
      spendingUsd: (json['spending_usd'] ?? 0.0).toDouble(),
      spendingNgn: (json['spending_ngn'] ?? 0.0).toDouble(),
      netUsd: (json['net_usd'] ?? 0.0).toDouble(),
      netNgn: (json['net_ngn'] ?? 0.0).toDouble(),
    );
  }
}

class CategorySpending {
  final String category;
  final String label;
  final double usd;
  final double ngn;
  final double totalUsdEquivalent;

  CategorySpending({
    required this.category,
    required this.label,
    required this.usd,
    required this.ngn,
    required this.totalUsdEquivalent,
  });

  factory CategorySpending.fromJson(Map<String, dynamic> json) {
    return CategorySpending(
      category: json['category'] ?? '',
      label: json['label'] ?? '',
      usd: (json['usd'] ?? 0.0).toDouble(),
      ngn: (json['ngn'] ?? 0.0).toDouble(),
      totalUsdEquivalent: (json['total_usd_equivalent'] ?? 0.0).toDouble(),
    );
  }
}

class RecentTransaction {
  final int id;
  final String description;
  final double amount;
  final String currency;
  final String type;
  final String category;
  final String categoryLabel;
  final String timestamp;

  RecentTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.currency,
    required this.type,
    required this.category,
    required this.categoryLabel,
    required this.timestamp,
  });

  factory RecentTransaction.fromJson(Map<String, dynamic> json) {
    return RecentTransaction(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
      type: json['type'] ?? 'debit',
      category: json['category'] ?? '',
      categoryLabel: json['category_label'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class DashboardData {
  final UserInfo user;
  final int healthScore;
  final String healthStatus;
  final Balances balances;
  final MonthSummary thisMonth;
  final double safeWeeklySpendUsd;
  final String aiInsight;
  final List<CategorySpending> categories;
  final List<RecentTransaction> recentTransactions;

  DashboardData({
    required this.user,
    required this.healthScore,
    required this.healthStatus,
    required this.balances,
    required this.thisMonth,
    required this.safeWeeklySpendUsd,
    required this.aiInsight,
    required this.categories,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      user: UserInfo.fromJson(json['user'] ?? {}),
      healthScore: json['health_score'] ?? 50,
      healthStatus: json['health_status'] ?? 'Good',
      balances: Balances.fromJson(json['balances'] ?? {}),
      thisMonth: MonthSummary.fromJson(json['this_month'] ?? {}),
      safeWeeklySpendUsd: (json['safe_weekly_spend_usd'] ?? 0.0).toDouble(),
      aiInsight: json['ai_insight'] ?? '',
      categories: (json['categories'] as List? ?? [])
          .map((c) => CategorySpending.fromJson(c))
          .toList(),
      recentTransactions: (json['recent_transactions'] as List? ?? [])
          .map((t) => RecentTransaction.fromJson(t))
          .toList(),
    );
  }
}
