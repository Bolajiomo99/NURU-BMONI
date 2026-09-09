import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuru_app/providers/auth_provider.dart';
import 'package:nuru_app/routes/app_routes.dart';
import 'package:nuru_app/services/auth_api.dart';
import 'package:nuru_app/services/onboarding_api.dart';
import 'package:nuru_app/widgets/nuru_primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An [AuthApi] backed by [MockClient], answering by request path so tests
/// read like the API contract instead of HTTP plumbing.
AuthApi mockAuthApi(Map<String, http.Response> byPath) {
  return AuthApi(
    client: MockClient((request) async {
      final response = byPath[request.url.path];
      if (response == null) {
        fail('Unhandled request in test: ${request.method} ${request.url}');
      }
      return response;
    }),
  );
}

http.Response jsonResponse(Map<String, dynamic> body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// An [OnboardingApi] whose /onboarding/status/ always returns [nextRoute]
/// (or a network failure when null, matching OnboardingApi.status()'s
/// documented "unknown" contract).
OnboardingApi mockOnboardingApi(String? nextRoute) {
  return OnboardingApi(
    client: MockClient((request) async {
      if (nextRoute == 'ERROR') return http.Response('', 500);
      return jsonResponse({'next_route': nextRoute}, 200);
    }),
  );
}

Widget buildApp({
  required String initialRoute,
  required AuthApi authApi,
  required OnboardingApi onboardingApi,
}) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(authApi),
      onboardingApiProvider.overrideWithValue(onboardingApi),
    ],
    child: MaterialApp(
      initialRoute: initialRoute,
      routes: buildRoutes(),
      onGenerateRoute: onGenerateRoute,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthChoiceScreen', () {
    testWidgets('Create Account leads to the signup form', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.authChoice,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Let\'s get you set up'), findsOneWidget);
    });

    testWidgets('"I already have an account" leads to login', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.authChoice,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('SignupScreen', () {
    testWidgets('empty submit shows validation errors and calls no API',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.signup,
        authApi: mockAuthApi({}), // any request here would fail the test
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
      expect(find.text('Confirm your password'), findsOneWidget);
    });

    testWidgets('mismatched passwords are caught client-side', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.signup,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Zainab Wahab');
      await tester.enterText(fields.at(1), 'zainab@example.com');
      await tester.enterText(fields.at(2), 'correcthorsebattery');
      await tester.enterText(fields.at(3), 'somethingelse');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('successful signup navigates to OTP with the entered email',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.signup,
        authApi: mockAuthApi({
          '/api/auth/signup/': jsonResponse(
            {'email': 'zainab@example.com', 'message': 'Verification code sent.'},
            201,
          ),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Zainab Wahab');
      await tester.enterText(fields.at(1), 'zainab@example.com');
      await tester.enterText(fields.at(2), 'correcthorsebattery');
      await tester.enterText(fields.at(3), 'correcthorsebattery');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter the code'), findsOneWidget);
      expect(find.textContaining('zainab@example.com'), findsOneWidget);
    });

    testWidgets('a rejected signup shows the backend message and stays put',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.signup,
        authApi: mockAuthApi({
          // A raw DRF serializer-validation 400 has no 'error'/'message' key —
          // just the field-error dict, exactly as SignupView returns it.
          '/api/auth/signup/': jsonResponse(
            {'email': ['An account with this email already exists.']},
            400,
          ),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Zainab Wahab');
      await tester.enterText(fields.at(1), 'zainab@example.com');
      await tester.enterText(fields.at(2), 'correcthorsebattery');
      await tester.enterText(fields.at(3), 'correcthorsebattery');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('An account with this email already exists.'), findsOneWidget);
      expect(find.text('Let\'s get you set up'), findsOneWidget); // still on signup
    });
  });

  group('OtpScreen (reached via signup)', () {
    Future<void> signUp(WidgetTester tester, AuthApi authApi, OnboardingApi onboardingApi) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.signup,
        authApi: authApi,
        onboardingApi: onboardingApi,
      ));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Zainab Wahab');
      await tester.enterText(fields.at(1), 'zainab@example.com');
      await tester.enterText(fields.at(2), 'correcthorsebattery');
      await tester.enterText(fields.at(3), 'correcthorsebattery');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();
    }

    testWidgets('a correct code verifies and lands on the resumed onboarding step',
        (tester) async {
      await signUp(
        tester,
        mockAuthApi({
          '/api/auth/signup/': jsonResponse({'email': 'zainab@example.com'}, 201),
          '/api/auth/verify-otp/': jsonResponse({
            'token': 'tok_123',
            'user': {'id': 1, 'name': 'Zainab Wahab', 'email': 'zainab@example.com'},
          }, 200),
        }),
        mockOnboardingApi('business'),
      );

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      // BusinessScreen is built now (CP6) — assert its content directly
      // rather than the CP6-placeholder's route-name text.
      expect(find.text('Tell us about your business'), findsOneWidget);
    });

    testWidgets('an incorrect code shows the attempts-remaining message and clears the boxes',
        (tester) async {
      await signUp(
        tester,
        mockAuthApi({
          '/api/auth/signup/': jsonResponse({'email': 'zainab@example.com'}, 201),
          '/api/auth/verify-otp/': jsonResponse({
            'error': 'invalid_code',
            'attempts_remaining': 4,
            'message': 'Incorrect code. 4 attempts remaining.',
          }, 400),
        }),
        mockOnboardingApi(null),
      );

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.pumpAndSettle();

      expect(find.text('Incorrect code. 4 attempts remaining.'), findsOneWidget);
    });

    testWidgets('resend calls the API and shows a confirmation', (tester) async {
      await signUp(
        tester,
        mockAuthApi({
          '/api/auth/signup/': jsonResponse({'email': 'zainab@example.com'}, 201),
          '/api/auth/resend-otp/': jsonResponse(
            {'email': 'zainab@example.com', 'message': 'Verification code sent.'},
            200,
          ),
        }),
        mockOnboardingApi(null),
      );

      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();

      expect(find.text('A new code is on its way.'), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('empty submit shows validation errors', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.login,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('wrong credentials show the backend message', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.login,
        authApi: mockAuthApi({
          '/api/auth/login/': jsonResponse(
            {'error': 'invalid_credentials', 'message': 'Incorrect email or password.'},
            400,
          ),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'zainab@example.com');
      await tester.enterText(fields.at(1), 'wrongpassword');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });

    testWidgets('a correct password on an unverified account routes to OTP',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.login,
        authApi: mockAuthApi({
          '/api/auth/login/': jsonResponse({
            'error': 'email_not_verified',
            'email': 'zainab@example.com',
            'message': 'Verify your email to continue. We sent you a new code.',
          }, 403),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'zainab@example.com');
      await tester.enterText(fields.at(1), 'correcthorsebattery');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter the code'), findsOneWidget);
      expect(find.textContaining('zainab@example.com'), findsOneWidget);
    });

    testWidgets('a fully onboarded login goes straight home', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.login,
        authApi: mockAuthApi({
          '/api/auth/login/': jsonResponse({
            'token': 'tok_123',
            'user': {'id': 1, 'name': 'Zainab Wahab', 'email': 'zainab@example.com'},
          }, 200),
        }),
        onboardingApi: mockOnboardingApi(null), // next_route null -> home
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'zainab@example.com');
      await tester.enterText(fields.at(1), 'correcthorsebattery');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Log In'), findsNothing);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('empty submit is caught client-side', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.forgotPassword,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('submitting shows the generic confirmation and hides the form',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.forgotPassword,
        authApi: mockAuthApi({
          '/api/auth/forgot-password/': jsonResponse(
            {'message': 'If an account exists for that email, a reset link is on its way.'},
            200,
          ),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'zainab@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('reset link is on its way'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsNothing);
    });

    testWidgets('the reset-code link leads to ResetPasswordScreen', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.forgotPassword,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Already have a reset code? Enter it here'));
      await tester.pumpAndSettle();

      expect(find.text('Set a new password'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('empty submit is caught client-side', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.resetPassword,
        authApi: mockAuthApi({}),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Paste your reset code'), findsOneWidget);
      expect(find.text('Enter a new password'), findsOneWidget);
    });

    testWidgets('a valid token updates the password and offers to log in',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.resetPassword,
        authApi: mockAuthApi({
          '/api/auth/reset-password/': jsonResponse(
            {'message': 'Password updated. You can now log in.'},
            200,
          ),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'raw-token-abc');
      await tester.enterText(fields.at(1), 'brandnewpassword');
      await tester.enterText(fields.at(2), 'brandnewpassword');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password updated'), findsOneWidget);

      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('an expired or invalid token shows the backend message',
        (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.resetPassword,
        authApi: mockAuthApi({
          '/api/auth/reset-password/': jsonResponse(
            {'error': 'invalid_token', 'message': 'That reset link is invalid or has expired.'},
            400,
          ),
        }),
        onboardingApi: mockOnboardingApi(null),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'expired-token');
      await tester.enterText(fields.at(1), 'brandnewpassword');
      await tester.enterText(fields.at(2), 'brandnewpassword');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('That reset link is invalid or has expired.'), findsOneWidget);
    });
  });
}
