import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';
import '../models/chat_message.dart';

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

  static Future<Map<String, String>> get _headers async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  static Future<http.Response> _get(String path) async {
    return http
        .get(Uri.parse('$baseUrl$path'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return http
        .post(Uri.parse('$baseUrl$path'), headers: await _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
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
    final response = await _post('/chat/', {'message': message});

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
    await http.delete(Uri.parse('$baseUrl/chat/'), headers: await _headers);
  }

  /// Generate Explain My Money story
  static Future<Map<String, dynamic>> explainFinances() async {
    final response = await _get('/explain/');

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

  /// Whether the signed-in account has a transaction PIN set
  static Future<Map<String, dynamic>> getSecurityStatus() async {
    final response = await _get('/security/status/');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load security status');
    }
  }

  /// Set (or replace) the 4-digit transaction PIN
  static Future<void> setupTransactionPin(String pin) async {
    final response = await _post('/security/pin/setup/', {'pin': pin});

    if (response.statusCode != 200) {
      throw Exception('Failed to set transaction PIN');
    }
  }

  /// Verify the 4-digit transaction PIN before authorizing an action
  static Future<void> verifyTransactionPin(String pin) async {
    final response = await _post('/security/pin/verify/', {'pin': pin});

    if (response.statusCode != 200) {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Incorrect PIN');
    }
  }

  /// Record the face-2FA check for the current transaction authorization
  static Future<void> verifyFace(String imagePayload) async {
    final response = await _post('/security/face/verify/', {'image': imagePayload});

    if (response.statusCode != 200) {
      throw Exception('Face verification failed');
    }
  }

  /// Reset session context back to unauthenticated guest mode
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
    _cachedAuthToken = null;
  }
}
