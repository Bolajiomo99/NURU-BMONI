import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'api_service.dart';

/// Auth endpoints.
///
/// An instance class, not static like [ApiService] — it takes an injectable
/// [http.Client] so screens can be tested against `MockClient` with no network.
class AuthApi {
  final http.Client _client;

  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${ApiService.baseUrl}$path');

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    late final http.Response res;
    try {
      res = await _client
          .post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException(
        code: 'network_error',
        message: 'Could not reach NURU. Check your connection and try again.',
      );
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json = {};
    try {
      final body = res.body.trim();
      if (body.startsWith('{')) json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      // Fall through to the status check with an empty body.
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    throw AuthException(
      code: json['error'] as String? ?? 'request_failed',
      message: json['message'] as String? ?? _fallbackMessage(res.statusCode, json),
      attemptsRemaining: (json['attempts_remaining'] as num?)?.toInt(),
      // Only 'email_not_verified' sends email as a plain string; a raw DRF
      // serializer-validation response sends {'email': [...]} instead, which
      // an unconditional cast would crash on.
      email: json['email'] is String ? json['email'] as String : null,
      fieldErrors: _fieldErrors(json),
    );
  }

  /// DRF serializer errors arrive as {"field": ["msg", ...]} alongside any
  /// top-level error code, so pull out anything list-shaped.
  Map<String, List<String>> _fieldErrors(Map<String, dynamic> json) {
    final out = <String, List<String>>{};
    json.forEach((key, value) {
      if (value is List) {
        out[key] = value.map((e) => e.toString()).toList();
      }
    });
    return out;
  }

  String _fallbackMessage(int status, Map<String, dynamic> json) {
    for (final value in json.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
    }
    if (status >= 500) return 'NURU is having trouble right now. Try again shortly.';
    return 'Something went wrong. Please try again.';
  }

  // ── Endpoints ───────────────────────────────────────────────────

  /// Creates an inactive account and emails a 6-digit code.
  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    await _post('/auth/signup/', {
      'name': name,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    });
  }

  /// Activates the account and persists the returned token.
  Future<AuthSession> verifyOtp({required String email, required String code}) async {
    final json = await _post('/auth/verify-otp/', {'email': email, 'code': code});
    final session = AuthSession.fromJson(json);
    await ApiService.setAuthToken(session.token);
    return session;
  }

  Future<void> resendOtp({required String email, String purpose = 'signup'}) async {
    await _post('/auth/resend-otp/', {'email': email, 'purpose': purpose});
  }

  Future<AuthSession> login({required String email, required String password}) async {
    final json = await _post('/auth/login/', {'email': email, 'password': password});
    final session = AuthSession.fromJson(json);
    await ApiService.setAuthToken(session.token);
    return session;
  }

  Future<void> forgotPassword({required String email}) async {
    await _post('/auth/forgot-password/', {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _post('/auth/reset-password/', {
      'token': token,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }

  /// Restores a session on cold start. Returns null when the stored token is
  /// missing or no longer valid.
  Future<AuthSession?> me() async {
    final token = await ApiService.getAuthToken();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await _client.get(
        _uri('/auth/me/'),
        headers: {..._jsonHeaders, 'Authorization': 'Token $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return AuthSession.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
          token: token,
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        // The token was revoked (a password reset does this) — drop it so the
        // app falls back to the signed-out flow instead of looping on 401s.
        await ApiService.clearAuthToken();
      }
    } catch (_) {
      // Offline on cold start: keep the token and treat the session as
      // unknown rather than signing the user out.
    }
    return null;
  }

  Future<void> logout() => ApiService.logout();
}
