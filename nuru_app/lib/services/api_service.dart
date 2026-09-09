import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';
import '../models/chat_message.dart';

/// Thrown when a BMONI login lookup (by user ID or phone) comes back 404 -
/// distinct from a network/server error so the UI can show the
/// "no BMONI account found" state instead of a generic failure toast.
class BmoniAccountNotFoundException implements Exception {
  final String message;
  BmoniAccountNotFoundException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const String _urlKey = 'nuru_backend_api_url';
  static const String _currentUserIdKey = 'nuru_current_bmoni_user_id';
  static String? _cachedUrl;
  static String? _cachedCurrentUserId;

  /// Candidate URLs to test if primary fails
  static List<String> get _candidateUrls {
    final list = <String>[];
    if (kIsWeb) {
      final webOrigin = Uri.base.origin;
      if (webOrigin.isNotEmpty && webOrigin != 'null') {
        list.add('$webOrigin/api');
      }
    }
    list.add('https://nuru.up.railway.app/api');
    return list.toSet().toList();
  }

  /// Get active API base URL
  static Future<String> getBaseUrl() async {
    if (_cachedUrl != null &&
        _cachedUrl!.isNotEmpty &&
        !_cachedUrl!.contains('nuru-bmoni')) {
      return _cachedUrl!;
    }

    if (kIsWeb) {
      final webOrigin = Uri.base.origin;
      if (webOrigin.isNotEmpty && webOrigin != 'null') {
        _cachedUrl = '$webOrigin/api';
        return _cachedUrl!;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_urlKey);

    if (savedUrl != null &&
        savedUrl.isNotEmpty &&
        !savedUrl.contains('nuru-bmoni') &&
        !savedUrl.contains('192.168.') &&
        !savedUrl.contains('localhost') &&
        !savedUrl.contains('127.0.0.1') &&
        !savedUrl.contains('10.0.2.2')) {
      _cachedUrl = savedUrl;
      return savedUrl;
    }

    _cachedUrl = 'https://nuru.up.railway.app/api';
    await prefs.setString(_urlKey, _cachedUrl!);
    return _cachedUrl!;
  }

  /// Update backend URL for physical device testing
  static Future<void> setBaseUrl(String newUrl) async {
    String formatted = newUrl.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    if (!formatted.endsWith('/api')) {
      formatted = '$formatted/api';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, formatted);
    _cachedUrl = formatted;
    debugPrint('⚙️ Updated NURU backend URL to: $formatted');
  }

  /// The bmoni_user_id of whoever last logged in via [loginBmoniUser], sent
  /// on every subsequent request so the backend knows who "current user"
  /// means. Null before any real login - the backend then falls back to
  /// its seeded demo persona.
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

  static Future<void> _setCurrentUserId(String bmoniUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, bmoniUserId);
    _cachedCurrentUserId = bmoniUserId;
  }

  static Future<Map<String, String>> get _headers async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final userId = await getCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      headers['X-Bmoni-User-Id'] = userId;
    }
    return headers;
  }

  /// Helper to execute GET with auto-fallback to alternate URLs if connection fails.
  /// Returns the response even for non-200 status codes so callers can handle them.
  static Future<http.Response> _getWithFallback(
    String path, {
    Duration timeout = const Duration(seconds: 18),
  }) async {
    final primary = await getBaseUrl();

    try {
      final res = await http
          .get(Uri.parse('$primary$path'), headers: await _headers)
          .timeout(timeout);
      _cachedUrl = primary;
      return res;
    } catch (e) {
      if (primary.startsWith('https://') && '$e'.contains('TimeoutException')) {
        throw Exception('Analysis is taking longer than expected. Please try again.');
      }

      final urls = _candidateUrls.where((u) => u != primary).toList();
      Object? lastException = e;
      for (final base in urls) {
        if (kIsWeb && primary.startsWith('https://') && base.startsWith('http://')) {
          continue;
        }
        try {
          final res = await http
              .get(Uri.parse('$base$path'), headers: await _headers)
              .timeout(const Duration(seconds: 12));
          _cachedUrl = base;
          return res;
        } catch (err) {
          lastException = err;
        }
      }
      throw Exception('Unable to reach NURU servers. Please check connection ($lastException)');
    }
  }

  /// Helper to execute POST with auto-fallback to alternate URLs if connection fails.
  /// Returns the response even for non-200 status codes so callers can
  /// handle 404, 400, 502, etc. — only network/socket errors trigger fallback.
  static Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final primary = await getBaseUrl();

    try {
      final res = await http
          .post(
            Uri.parse('$primary$path'),
            headers: await _headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      _cachedUrl = primary;
      return res;
    } catch (e) {
      if (primary.startsWith('https://') && '$e'.contains('TimeoutException')) {
        throw Exception('Request timed out. Please try again.');
      }

      final urls = _candidateUrls.where((u) => u != primary).toList();
      Object? lastException = e;
      for (final base in urls) {
        if (kIsWeb && primary.startsWith('https://') && base.startsWith('http://')) {
          continue;
        }
        try {
          final res = await http
              .post(
                Uri.parse('$base$path'),
                headers: await _headers,
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 15));
          _cachedUrl = base;
          return res;
        } catch (err) {
          lastException = err;
        }
      }
      throw Exception('Unable to reach NURU servers. Please check connection ($lastException)');
    }
  }

  /// Fetch dashboard summary
  static Future<DashboardData> fetchDashboard() async {
    final url = await getBaseUrl();
    final uid = await getCurrentUserId();
    debugPrint('🔍 fetchDashboard URL: $url | userId: $uid');
    final response = await _getWithFallback('/dashboard/');
    debugPrint('🔍 fetchDashboard code: ${response.statusCode} | body: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return DashboardData.fromJson(json);
    } else {
      throw Exception('Failed to load dashboard: ${response.body}');
    }
  }

  /// Send message to NURU AI
  static Future<ChatMessageItem> sendMessage(String message) async {
    final response = await _postWithFallback(
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
    final response = await _getWithFallback('/chat/');

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
    final url = await getBaseUrl();
    await http.delete(Uri.parse('$url/chat/'), headers: await _headers);
  }

  /// Generate Explain My Money story
  static Future<Map<String, dynamic>> explainFinances() async {
    final response = await _getWithFallback(
      '/explain/',
      timeout: const Duration(seconds: 30),
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
    final response = await _postWithFallback('/action/transfer/', {
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
    final response = await _postWithFallback('/action/swap/', {
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

  /// Register / Connect BMONI Account & Perform BVN Onboarding
  static Future<Map<String, dynamic>> registerBmoniUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String bvn,
  }) async {
    final response = await _postWithFallback('/bmoni/user/', {
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
        await _setCurrentUserId(resolvedId);
      }
      return jsonBody;
    } else {
      final msg = jsonBody['message'] ?? jsonBody['error'] ?? 'Registration could not be completed. Please try again.';
      throw Exception(msg);
    }
  }

  /// Connect / Log in existing BMONI user using Phone Number, Email, Name, or BMONI User ID
  static Future<Map<String, dynamic>> loginBmoniUser({
    String? identifier,
    String? bmoniUserId,
    String? phoneNumber,
  }) async {
    final input = identifier ?? bmoniUserId ?? phoneNumber ?? '';
    final response = await _postWithFallback('/bmoni/login/', {
      'identifier': input,
      'bmoni_user_id': bmoniUserId ?? '',
      'phone_number': phoneNumber ?? '',
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
        await _setCurrentUserId(resolvedId);
      }
      return jsonBody;
    } else if (response.statusCode == 404) {
      throw BmoniAccountNotFoundException(
        jsonBody['message'] as String? ??
            'No BMONI account found for that phone number, email, or identifier.',
      );
    } else {
      final msg = jsonBody['message'] ?? jsonBody['error'] ?? 'Login failed. Please try again.';
      throw Exception(msg);
    }
  }

  /// Reset session context back to unauthenticated guest mode and clear cached URLs
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.setString(_currentUserIdKey, '');
    _cachedUrl = null;
    _cachedCurrentUserId = null;
  }

  // ─── 2FA Security: Transaction PIN & Face Recognition ──────────

  /// Get 2FA security status (has_pin, face_enrolled)
  static Future<Map<String, dynamic>> getSecurityStatus() async {
    try {
      final response = await _getWithFallback('/auth/security-status/');
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
    final response = await _postWithFallback('/auth/pin/setup/', {'pin': pin});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? data['pin']?[0] ?? 'Failed to setup PIN');
  }

  /// Verify transaction PIN against stored hash
  static Future<Map<String, dynamic>> verifyTransactionPin(String pin) async {
    final response = await _postWithFallback('/auth/pin/verify/', {'pin': pin});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Incorrect PIN');
  }

  /// Enroll reference face image for 2FA
  static Future<Map<String, dynamic>> enrollFace(String base64Image) async {
    final response = await _postWithFallback('/auth/face/enroll/', {'face_image': base64Image});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to enroll Face ID');
  }

  /// Verify live face image for 2FA
  static Future<Map<String, dynamic>> verifyFace(String base64Image) async {
    final response = await _postWithFallback('/auth/face/verify/', {'face_image': base64Image});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Face verification failed');
  }
}
