import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';
import '../models/chat_message.dart';

class ApiService {
  static const String _urlKey = 'nuru_backend_api_url';
  static String? _cachedUrl;

  /// Candidate URLs to test if primary fails
  static List<String> get _candidateUrls {
    return [
      'https://nuru-bmoni.up.railway.app/api',
      'http://192.168.43.33:8000/api',
      'http://10.0.2.2:8000/api',
      'http://localhost:8000/api',
      'http://127.0.0.1:8000/api',
    ];
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

    _cachedUrl = 'https://nuru-bmoni.up.railway.app/api';
    return _cachedUrl!;
  }

  /// Update backend URL for physical device testing
  static Future<void> setBaseUrl(String newUrl) async {
    String formatted = newUrl.trim();
    // Strip any trailing slash before normalising, so ".../api/" does not
    // become ".../api/api".
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

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Helper to execute GET with auto-fallback to alternate URLs if connection fails
  static Future<http.Response> _getWithFallback(String path) async {
    final primary = await getBaseUrl();
    try {
      final res = await http
          .get(Uri.parse('$primary$path'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return res;
    } catch (_) {}

    // Fallback search across candidate URLs
    for (final candidate in _candidateUrls) {
      if (candidate == primary) continue;
      try {
        final res = await http
            .get(Uri.parse('$candidate$path'), headers: _headers)
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          await setBaseUrl(candidate);
          return res;
        }
      } catch (_) {}
    }

    // Try primary one last time to surface exact error
    return await http
        .get(Uri.parse('$primary$path'), headers: _headers)
        .timeout(const Duration(seconds: 8));
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
    final url = await getBaseUrl();
    final response = await http
        .post(
          Uri.parse('$url/chat/'),
          headers: _headers,
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 20));

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
    await http.delete(Uri.parse('$url/chat/'), headers: _headers);
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
    String description = '',
  }) async {
    final url = await getBaseUrl();
    final response = await http
        .post(
          Uri.parse('$url/action/transfer/'),
          headers: _headers,
          body: jsonEncode({
            'amount': amount,
            'currency': currency,
            'to_address': toAddress,
            'description': description,
          }),
        )
        .timeout(const Duration(seconds: 15));

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
    final url = await getBaseUrl();
    final response = await http
        .post(
          Uri.parse('$url/action/swap/'),
          headers: _headers,
          body: jsonEncode({
            'amount': amount,
            'from_currency': fromCurrency,
            'to_currency': toCurrency,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Swap action failed: ${response.body}');
    }
  }
}
