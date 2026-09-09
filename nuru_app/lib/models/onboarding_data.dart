/// A single choice-vocabulary entry (business size, spend category, revenue
/// range) — value is what the API accepts back, label is what to display.
class ChoiceOption {
  final String value;
  final String label;

  const ChoiceOption({required this.value, required this.label});

  factory ChoiceOption.fromJson(Map<String, dynamic> json) {
    return ChoiceOption(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

/// The value vocabularies for the business form's choice fields, echoed by
/// every onboarding endpoint that returns them so the client has one source
/// of truth instead of hardcoding options.
class OnboardingChoices {
  final List<ChoiceOption> businessSize;
  final List<ChoiceOption> spendCategories;
  final List<ChoiceOption> revenueRanges;

  const OnboardingChoices({
    required this.businessSize,
    required this.spendCategories,
    required this.revenueRanges,
  });

  factory OnboardingChoices.fromJson(Map<String, dynamic>? json) {
    final map = json ?? {};
    List<ChoiceOption> parse(String key) => ((map[key] as List?) ?? [])
        .map((e) => ChoiceOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return OnboardingChoices(
      businessSize: parse('business_size'),
      spendCategories: parse('spend_categories'),
      revenueRanges: parse('revenue_ranges'),
    );
  }
}

class BusinessProfile {
  final String businessName;
  final String businessSize;
  final bool? hasEmployees;
  final double? avgEmployeePay;
  final List<String> spendCategories;
  final String avgMonthlyRevenueRange;
  final String description;
  final bool onboardingStepCompleted;

  const BusinessProfile({
    required this.businessName,
    required this.businessSize,
    required this.hasEmployees,
    required this.avgEmployeePay,
    required this.spendCategories,
    required this.avgMonthlyRevenueRange,
    required this.description,
    required this.onboardingStepCompleted,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      businessName: json['business_name'] as String? ?? '',
      businessSize: json['business_size'] as String? ?? '',
      hasEmployees: json['has_employees'] as bool?,
      avgEmployeePay: (json['avg_employee_pay'] as num?)?.toDouble(),
      spendCategories: ((json['spend_categories'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      avgMonthlyRevenueRange: json['avg_monthly_revenue_range'] as String? ?? '',
      description: json['description'] as String? ?? '',
      onboardingStepCompleted: json['onboarding_step_completed'] as bool? ?? false,
    );
  }
}

class BusinessGoal {
  final int id;
  final String goalText;
  final String createdAt;

  const BusinessGoal({required this.id, required this.goalText, required this.createdAt});

  factory BusinessGoal.fromJson(Map<String, dynamic> json) {
    return BusinessGoal(
      id: (json['id'] as num?)?.toInt() ?? 0,
      goalText: json['goal_text'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class Loan {
  final int id;
  final double amount;
  final double? interestRate;
  final String dateTaken;
  final String? dueDate;
  final String lenderName;

  const Loan({
    required this.id,
    required this.amount,
    required this.interestRate,
    required this.dateTaken,
    required this.dueDate,
    required this.lenderName,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interest_rate'] as num?)?.toDouble(),
      dateTaken: json['date_taken'] as String? ?? '',
      dueDate: json['due_date'] as String?,
      lenderName: json['lender_name'] as String? ?? '',
    );
  }
}

class ConnectedAccount {
  final int id;
  final String institutionName;
  final String accountName;
  final String accountNumberMasked;
  final String status;

  const ConnectedAccount({
    required this.id,
    required this.institutionName,
    required this.accountName,
    required this.accountNumberMasked,
    required this.status,
  });

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) {
    return ConnectedAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      institutionName: json['institution_name'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNumberMasked: json['account_number_masked'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

/// GET /onboarding/status/ - which sections hold data, for resuming.
class OnboardingStatus {
  final bool business;
  final bool goals;
  final bool accounts;
  final bool loans;
  final bool complete;
  final String? nextRoute;
  final OnboardingChoices choices;

  const OnboardingStatus({
    required this.business,
    required this.goals,
    required this.accounts,
    required this.loans,
    required this.complete,
    required this.nextRoute,
    required this.choices,
  });

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      business: json['business'] as bool? ?? false,
      goals: json['goals'] as bool? ?? false,
      accounts: json['accounts'] as bool? ?? false,
      loans: json['loans'] as bool? ?? false,
      complete: json['complete'] as bool? ?? false,
      nextRoute: json['next_route'] as String?,
      choices: OnboardingChoices.fromJson(json['choices'] as Map<String, dynamic>?),
    );
  }
}
