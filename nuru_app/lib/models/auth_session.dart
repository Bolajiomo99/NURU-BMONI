/// The signed-in account, as returned by verify-otp / login / me.
class AuthSession {
  final String token;
  final int userId;
  final String name;
  final String email;

  const AuthSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json, {String? token}) {
    final user = (json['user'] as Map<String, dynamic>?) ?? json;
    return AuthSession(
      token: token ?? (json['token'] as String? ?? ''),
      userId: (user['id'] as num?)?.toInt() ?? 0,
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
    );
  }
}

/// A failed auth call, carrying the backend's machine-readable `error` code so
/// the UI can branch on it rather than parsing prose.
///
/// Codes in use: `invalid_credentials`, `email_not_verified`, `invalid_code`,
/// `expired`, `too_many_attempts`, `no_code`, `cooldown`, `invalid_token`.
class AuthException implements Exception {
  final String code;
  final String message;

  /// Present on `invalid_code` — how many tries are left before the OTP burns.
  final int? attemptsRemaining;

  /// Present on `email_not_verified` — lets the app route to the OTP screen.
  final String? email;

  /// Field-level validation errors, keyed by field name.
  final Map<String, List<String>> fieldErrors;

  const AuthException({
    required this.code,
    required this.message,
    this.attemptsRemaining,
    this.email,
    this.fieldErrors = const {},
  });

  /// The first error for [field], if the backend rejected it.
  String? errorFor(String field) {
    final errors = fieldErrors[field];
    return (errors != null && errors.isNotEmpty) ? errors.first : null;
  }

  @override
  String toString() => message;
}
