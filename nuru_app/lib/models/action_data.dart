class NuruAction {
  final String type; // 'transfer' or 'swap'
  final Map<String, dynamic> data;

  NuruAction({
    required this.type,
    required this.data,
  });

  factory NuruAction.fromJson(Map<String, dynamic> json) {
    return NuruAction(
      type: json['type'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  double get amount => (data['amount'] ?? 0.0).toDouble();
  String get currency => data['currency'] ?? data['from_currency'] ?? 'USD';
  String get description => data['description'] ?? '';
  String get to => data['to'] ?? '';
  String get accountNumber => data['account_number'] ?? '';
  String get bankName => data['bank_name'] ?? '';
  String get accountName => data['account_name'] ?? '';
  String get fromCurrency => data['from_currency'] ?? 'USD';
  String get toCurrency => data['to_currency'] ?? 'NGN';
}
