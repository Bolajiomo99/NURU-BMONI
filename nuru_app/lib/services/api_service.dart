import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';
import '../models/chat_message.dart';

class BmoniAccountNotFoundException implements Exception {
  final String message;
  BmoniAccountNotFoundException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  /// Backend API base URL — a build-time value, not a runtime guess.
  ///
  /// Defaults to the deployed Railway URL (production is unaffected unless
  /// a build explicitly overrides it). For local dev, pass
  /// --dart-define=API_URL=http://localhost:8000/api at build/run time.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://nuru-bmoni.up.railway.app/api',
  );

  static const String authTokenKey = 'nuru_auth_token';
  static String? _cachedAuthToken;

  static const String _currentUserIdKey = 'current_bmoni_user_id';
  static String? _cachedCurrentUserId;
  static String? _cachedUrl;

  /// The DRF auth token for the signed-in account, or null when signed out.
  static Future<String?> getAuthToken() async {
    if (_cachedAuthToken != null && _cachedAuthToken!.isNotEmpty) {
      return _cachedAuthToken;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(authTokenKey);
    _cachedAuthToken = token;
    return (token != null && token.isNotEmpty) ? token : null;
  }

  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(authTokenKey, token);
    _cachedAuthToken = token;
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
    _cachedAuthToken = null;
  }

  /// The bmoni_user_id of whoever last logged in via [loginBmoniUser], sent
  /// on every subsequent request so the backend knows who "current user"
  /// means. Defaults to Samson Jabo if unset.
  static Future<String?> getCurrentUserId() async {
    if (_cachedCurrentUserId != null && _cachedCurrentUserId!.isNotEmpty) {
      return _cachedCurrentUserId;
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedCurrentUserId = prefs.getString(_currentUserIdKey);
    if (_cachedCurrentUserId == null || _cachedCurrentUserId!.isEmpty) {
      _cachedCurrentUserId = '43fc704e-bfd9-4ad3-8edf-b189453773b0';
      await prefs.setString(_currentUserIdKey, _cachedCurrentUserId!);
    }
    return _cachedCurrentUserId;
  }

  static Future<void> setCurrentUserId(String bmoniUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, bmoniUserId);
    _cachedCurrentUserId = bmoniUserId;
  }

  /// Get active API base URL (detecting same-origin web or configured default)
  static Future<String> getBaseUrl() async {
    if (_cachedUrl != null && _cachedUrl!.isNotEmpty) {
      return _cachedUrl!;
    }
    if (kIsWeb) {
      final webOrigin = Uri.base.origin;
      if (webOrigin.isNotEmpty && webOrigin != 'null' && !webOrigin.startsWith('file://')) {
        _cachedUrl = '$webOrigin/api';
        return _cachedUrl!;
      }
    }
    _cachedUrl = baseUrl;
    return _cachedUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    _cachedUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nuru_backend_api_url', url);
  }

  static Future<Map<String, String>> get _headers async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    final userId = await getCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      headers['X-Bmoni-User-Id'] = userId;
    }
    return headers;
  }

  static Future<http.Response> _get(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final base = await getBaseUrl();
    return http
        .get(Uri.parse('$base$path'), headers: await _headers)
        .timeout(timeout);
  }

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final base = await getBaseUrl();
    return http
        .post(Uri.parse('$base$path'), headers: await _headers, body: jsonEncode(body))
        .timeout(timeout);
  }

  /// Fetch dashboard summary
  static Future<DashboardData> fetchDashboard() async {
    final response = await _get('/dashboard/');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return DashboardData.fromJson(json);
    } else {
      throw Exception('Failed to load dashboard: ${response.body}');
    }
  }

  /// Send message to NURU AI
  static Future<ChatMessageItem> sendMessage(String message) async {
    final response = await _post(
      '/chat/',
      {'message': message},
      timeout: const Duration(seconds: 25),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ChatMessageItem.fromJson(json);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  /// Get chat history
  static Future<List<ChatMessageItem>> fetchChatHistory() async {
    final response = await _get('/chat/');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List list = json['messages'] ?? [];
      return list.map((item) => ChatMessageItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  /// Clear chat history
  static Future<void> clearChatHistory() async {
    final base = await getBaseUrl();
    await http.delete(Uri.parse('$base/chat/'), headers: await _headers);
  }

  /// Generate Explain My Money story
  static Future<Map<String, dynamic>> explainFinances() async {
    final response = await _get(
      '/explain/',
      timeout: const Duration(seconds: 25),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate financial story (${response.statusCode})');
    }
  }

  /// Execute BMONI Transfer Action
  static Future<Map<String, dynamic>> executeTransfer({
    required double amount,
    required String currency,
    required String toAddress,
    String accountNumber = '',
    String bankName = '',
    String accountName = '',
    String description = '',
  }) async {
    final response = await _post('/action/transfer/', {
      'amount': amount,
      'currency': currency,
      'to_address': toAddress,
      'account_number': accountNumber,
      'bank_name': bankName,
      'account_name': accountName,
      'description': description,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Transfer action failed: ${response.body}');
    }
  }

  /// Execute BMONI Swap Action
  static Future<Map<String, dynamic>> executeSwap({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final response = await _post('/action/swap/', {
      'amount': amount,
      'from_currency': fromCurrency,
      'to_currency': toCurrency,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Swap action failed: ${response.body}');
    }
  }

  /// Connect / Log in BMONI user
  static Future<Map<String, dynamic>> loginBmoniUser({
    String? identifier,
    String? bmoniUserId,
    String? phoneNumber,
  }) async {
    final input = identifier ?? bmoniUserId ?? phoneNumber ?? '';
    final response = await _post('/bmoni/login/', {
      'identifier': input,
      'bmoni_user_id': bmoniUserId ?? '',
      'phone_number': phoneNumber ?? '',
    });

    Map<String, dynamic> jsonBody = {};
    try {
      if (response.body.trim().startsWith('{' )) {
        jsonBody = jsonDecode(response.body);
      }
    } catch (_) {}

    if (response.statusCode == 200) {
      final resolvedId = jsonBody['user']?['bmoni_user_id'] as String?;
      if (resolvedId != null && resolvedId.isNotEmpty) {
        await setCurrentUserId(resolvedId);
      }
      return jsonBody;
    } else if (response.statusCode == 404) {
      throw BmoniAccountNotFoundException(
        jsonBody['message'] as String? ?? 'No BMONI account found.',
      );
    } else {
      final msg = jsonBody['message'] ?? jsonBody['error'] ?? 'Login failed. Please try again.';
      throw Exception(msg);
    }
  }

  /// Register a user in BMONI system with BVN
  static Future<Map<String, dynamic>> registerBmoniUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String bvn,
  }) async {
    final response = await _post('/bmoni/user/', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'bvn': bvn,
    });

    Map<String, dynamic> jsonBody = {};
    try {
      if (response.body.trim().startsWith('{')) {
        jsonBody = jsonDecode(response.body);
      }
    } catch (_) {}

    if (response.statusCode == 200) {
      final resolvedId = jsonBody['user']?['bmoni_user_id'] as String?;
      if (resolvedId != null && resolvedId.isNotEmpty) {
        await setCurrentUserId(resolvedId);
      }
      return jsonBody;
    } else {
      final msg = jsonBody['message'] ?? jsonBody['error'] ?? 'Registration failed. Please try again.';
      throw Exception(msg);
    }
  }

  /// Reset session context back to unauthenticated guest mode
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
    await prefs.setString(_currentUserIdKey, '');
    _cachedAuthToken = null;
    _cachedCurrentUserId = null;
  }

  // ─── 2FA Security: Transaction PIN & Face Recognition ──────────

  /// Get 2FA security status (has_pin, face_enrolled)
  static Future<Map<String, dynamic>> getSecurityStatus() async {
    try {
      final response = await _get('/auth/security-status/');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('getSecurityStatus error: $e');
    }
    return {'has_pin': false, 'face_enrolled': false};
  }

  /// Create and hash initial transaction PIN
  static Future<Map<String, dynamic>> setupTransactionPin(String pin) async {
    final response = await _post('/auth/pin/setup/', {'pin': pin});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? data['pin']?[0] ?? 'Failed to setup PIN');
  }

  /// Verify transaction PIN against stored hash
  static Future<Map<String, dynamic>> verifyTransactionPin(String pin) async {
    final response = await _post('/auth/pin/verify/', {'pin': pin});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Incorrect PIN');
  }

  /// Enroll reference face image for 2FA
  static Future<Map<String, dynamic>> enrollFace(String base64Image) async {
    final response = await _post('/auth/face/enroll/', {'face_image': base64Image});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to enroll Face ID');
  }

  /// Verify live face image for 2FA
  static Future<Map<String, dynamic>> verifyFace(String base64Image) async {
    final response = await _post('/auth/face/verify/', {'face_image': base64Image});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Face verification failed');
  }

  /// Reset 2FA PIN and Face Biometrics for sandbox testing account
  static Future<Map<String, dynamic>> resetSandbox2FA() async {
    final response = await _post('/auth/sandbox/reset-2fa/', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to reset sandbox 2FA');
  }
}
