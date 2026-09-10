import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/onboarding_data.dart';
import 'api_service.dart';

/// A failed onboarding call, carrying the backend's field-level validation
/// errors so a screen can show them next to the offending input instead of
/// just a generic banner.
class OnboardingException implements Exception {
  final String message;
  final Map<String, List<String>> fieldErrors;

  const OnboardingException({required this.message, this.fieldErrors = const {}});

  String? errorFor(String field) {
    final errors = fieldErrors[field];
    return (errors != null && errors.isNotEmpty) ? errors.first : null;
  }

  @override
  String toString() => message;
}

/// Onboarding + Mono account-linking endpoints.
///
/// An instance class, not static like [ApiService] — it takes an injectable
/// [http.Client] so screens can be tested against `MockClient` with no network.
class OnboardingApi {
  final http.Client _client;

  OnboardingApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await ApiService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<Uri> _uri(String path) async => Uri.parse('${await ApiService.getBaseUrl()}$path');

  Map<String, dynamic> _decodeBody(http.Response res) {
    try {
      final body = res.body.trim();
      if (body.startsWith('{')) return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      // Fall through to an empty map.
    }
    return {};
  }

  /// DRF serializer errors arrive as {"field": ["msg", ...]}.
  Map<String, List<String>> _fieldErrors(Map<String, dynamic> json) {
    final out = <String, List<String>>{};
    json.forEach((key, value) {
      if (value is List) {
        out[key] = value.map((e) => e.toString()).toList();
      }
    });
    return out;
  }

  OnboardingException _errorFrom(http.Response res) {
    final json = _decodeBody(res);
    final fieldErrors = _fieldErrors(json);
    String message = json['message'] as String? ?? '';
    if (message.isEmpty) {
      for (final errors in fieldErrors.values) {
        if (errors.isNotEmpty) {
          message = errors.first;
          break;
        }
      }
    }
    if (message.isEmpty) {
      message = res.statusCode >= 500
          ? 'NURU is having trouble right now. Try again shortly.'
          : 'Something went wrong. Please try again.';
    }
    return OnboardingException(message: message, fieldErrors: fieldErrors);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    late final http.Response res;
    try {
      final uri = await _uri(path);
      res = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const OnboardingException(
        message: 'Could not reach NURU. Check your connection and try again.',
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return _decodeBody(res);
    throw _errorFrom(res);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    late final http.Response res;
    try {
      final uri = await _uri(path);
      final headers = await _headers();
      final encoded = body == null ? null : jsonEncode(body);
      res = await (method == 'PATCH'
              ? _client.patch(uri, headers: headers, body: encoded)
              : _client.post(uri, headers: headers, body: encoded))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const OnboardingException(
        message: 'Could not reach NURU. Check your connection and try again.',
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return _decodeBody(res);
    throw _errorFrom(res);
  }

  Future<void> _delete(String path) async {
    late final http.Response res;
    try {
      final uri = await _uri(path);
      res = await _client
          .delete(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const OnboardingException(
        message: 'Could not reach NURU. Check your connection and try again.',
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw _errorFrom(res);
  }

  // ── Status ──────────────────────────────────────────────────────

  /// Which onboarding sections hold data, plus `next_route` and the choice
  /// vocabularies. Returns null if the call fails — callers treat that as
  /// "unknown" rather than "not started", so a blip cannot bounce a fully
  /// onboarded user back to the first form.
  Future<Map<String, dynamic>?> status() async {
    try {
      final uri = await _uri('/onboarding/status/');
      final res = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return _decodeBody(res);
    } catch (_) {
      // Offline or server error — unknown, not "unstarted".
    }
    return null;
  }

  // ── Business ────────────────────────────────────────────────────

  Future<(BusinessProfile?, OnboardingChoices)> getBusiness() async {
    final json = await _get('/onboarding/business/');
    final businessJson = json['business'] as Map<String, dynamic>?;
    return (
      businessJson == null ? null : BusinessProfile.fromJson(businessJson),
      OnboardingChoices.fromJson(json['choices'] as Map<String, dynamic>?),
    );
  }

  Future<BusinessProfile> patchBusiness(Map<String, dynamic> data) async {
    final json = await _send('PATCH', '/onboarding/business/', body: data);
    return BusinessProfile.fromJson(json);
  }

  // ── Goals ───────────────────────────────────────────────────────

  Future<List<BusinessGoal>> getGoals() async {
    final json = await _get('/onboarding/goals/');
    return ((json['goals'] as List?) ?? [])
        .map((g) => BusinessGoal.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessGoal> createGoal(String goalText) async {
    final json = await _send('POST', '/onboarding/goals/', body: {'goal_text': goalText});
    return BusinessGoal.fromJson(json);
  }

  Future<void> deleteGoal(int id) => _delete('/onboarding/goals/$id/');

  // ── Loans ───────────────────────────────────────────────────────

  Future<List<Loan>> getLoans() async {
    final json = await _get('/onboarding/loans/');
    return ((json['loans'] as List?) ?? [])
        .map((l) => Loan.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<Loan> createLoan({
    required double amount,
    double? interestRate,
    required String dateTaken,
    String? dueDate,
    String lenderName = '',
  }) async {
    final json = await _send('POST', '/onboarding/loans/', body: {
      'amount': amount,
      'interest_rate': ?interestRate,
      'date_taken': dateTaken,
      'due_date': ?dueDate,
      'lender_name': lenderName,
    });
    return Loan.fromJson(json);
  }

  Future<void> deleteLoan(int id) => _delete('/onboarding/loans/$id/');

  // ── Mono account linking ───────────────────────────────────────

  /// Starts a Mono Connect session. Returns the widget URL to open, the ref
  /// to correlate it, and the redirect_url Mono will send the browser back
  /// to once linking finishes.
  Future<Map<String, String>> monoInitiate() async {
    final json = await _send('POST', '/mono/connect/initiate/');
    return {
      'mono_url': json['mono_url'] as String? ?? '',
      'ref': json['ref'] as String? ?? '',
      'redirect_url': json['redirect_url'] as String? ?? '',
    };
  }

  /// Exchanges the widget's authorisation code for a linked account.
  Future<ConnectedAccount> monoCallback({required String code, String ref = ''}) async {
    final json = await _send('POST', '/mono/connect/callback/', body: {
      'code': code,
      if (ref.isNotEmpty) 'ref': ref,
    });
    return ConnectedAccount.fromJson(json);
  }

  Future<List<ConnectedAccount>> monoAccounts() async {
    final json = await _get('/mono/accounts/');
    return ((json['accounts'] as List?) ?? [])
        .map((a) => ConnectedAccount.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}
