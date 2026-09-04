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
    list.addAll([
      'https://nuru-bmoni.up.railway.app/api',
      'http://localhost:8000/api',
      'http://127.0.0.1:8000/api',
      'http://10.0.2.2:8000/api',
      'http://192.168.43.33:8000/api',
    ]);
    return list.toSet().toList();
  }

  /// Get active API base URL
  static Future<String> getBaseUrl() async {
    if (_cachedUrl != null && _cachedUrl!.isNotEmpty) {
      return _cachedUrl!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_urlKey);

    if (savedUrl != null && savedUrl.isNotEmpty) {
      _cachedUrl = savedUrl;
      return savedUrl;
    }

    if (kIsWeb) {
      final webOrigin = Uri.base.origin;
      if (webOrigin.isNotEmpty && webOrigin != 'null') {
        _cachedUrl = '$webOrigin/api';
        return _cachedUrl!;
      }
    }

    _cachedUrl = 'https://nuru-bmoni.up.railway.app/api';
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
    if (_cachedCurrentUserId != null) return _cachedCurrentUserId;
    final prefs = await SharedPreferences.getInstance();
    _cachedCurrentUserId = prefs.getString(_currentUserIdKey);
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

  /// Helper to execute GET with auto-fallback to alternate URLs if connection fails
  static Future<http.Response> _getWithFallback(String path) async {
    final primary = await getBaseUrl();
    final urls = {primary, ..._candidateUrls}.toList();

    Object? lastException;
    for (final base in urls) {
      try {
        final res = await http
            .get(Uri.parse('$base$path'), headers: await _headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _cachedUrl = base;
          return res;
        }
      } catch (e) {
        lastException = e;
      }
    }
    throw Exception('Unable to reach NURU servers. Please check connection ($lastException)');
  }

  /// Helper to execute POST with auto-fallback to alternate URLs if connection fails.
  /// Returns the response even for non-200 status codes so callers can
  /// handle 404, 400, 502, etc. — only network/socket errors trigger fallback.
  static Future<http.Response> _postWithFallback(String path, Map<String, dynamic> body) async {
    final primary = await getBaseUrl();
    final urls = {primary, ..._candidateUrls}.toList();

    Object? lastException;
    for (final base in urls) {
      try {
        final res = await http
            .post(
              Uri.parse('$base$path'),
              headers: await _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
        // Server responded — cache this working URL and return immediately.
        // Let the caller decide what to do with non-200 status codes.
        _cachedUrl = base;
        return res;
      } catch (e) {
        lastException = e;
      }
    }
    throw Exception('Unable to reach NURU servers. Please check connection ($lastException)');
  }

  /// Fetch dashboard summary
  static Future<DashboardData> fetchDashboard() async {
    final response = await _getWithFallback('/dashboard/');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return DashboardData.fromJson(json);
    } else {
      throw Exception('Failed to load dashboard: ${response.body}');
    }
  }

  /// Send message to NURU AI
  static Future<ChatMessageItem> sendMessage(String message) async {
    final response = await _postWithFallback('/chat/', {'message': message});

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
    final response = await _getWithFallback('/explain/');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate financial story');
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

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final resolvedId = json['user']?['bmoni_user_id'] as String?;
      if (resolvedId != null && resolvedId.isNotEmpty) {
        await _setCurrentUserId(resolvedId);
      }
      return json;
    } else {
      throw Exception('BMONI Registration failed: ${response.body}');
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

    final json = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode == 200) {
      final resolvedId = json['user']?['bmoni_user_id'] as String?;
      if (resolvedId != null && resolvedId.isNotEmpty) {
        await _setCurrentUserId(resolvedId);
      }
      return json;
    } else if (response.statusCode == 404) {
      throw BmoniAccountNotFoundException(
        json['message'] as String? ??
            'No BMONI account found for that phone number, email, or identifier.',
      );
    } else {
      throw Exception('BMONI Login failed: ${json["message"] ?? response.body}');
    }
  }
}
