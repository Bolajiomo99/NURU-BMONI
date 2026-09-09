import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Onboarding endpoints.
///
/// Only `status()` exists at CP5 — the splash needs it to decide where to land
/// a returning user. The business/goals/loans calls arrive with the onboarding
/// screens at CP6.
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

  /// Which onboarding sections hold data, plus `next_route` and the choice
  /// vocabularies. Returns null if the call fails — callers treat that as
  /// "unknown" rather than "not started", so a blip cannot bounce a fully
  /// onboarded user back to the first form.
  Future<Map<String, dynamic>?> status() async {
    try {
      final res = await _client
          .get(
            Uri.parse('${await ApiService.getBaseUrl()}/onboarding/status/'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Offline or server error — unknown, not "unstarted".
    }
    return null;
  }
}
