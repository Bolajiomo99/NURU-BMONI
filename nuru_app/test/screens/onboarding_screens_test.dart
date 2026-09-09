import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuru_app/providers/auth_provider.dart';
import 'package:nuru_app/routes/app_routes.dart';
import 'package:nuru_app/services/onboarding_api.dart';
import 'package:nuru_app/widgets/nuru_primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Map<String, dynamic> body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// An [OnboardingApi] backed by [MockClient], answering by "METHOD path" so
/// tests read like the API contract instead of HTTP plumbing.
OnboardingApi mockOnboardingApi(Map<String, http.Response> byMethodAndPath) {
  return OnboardingApi(
    client: MockClient((request) async {
      final key = '${request.method} ${request.url.path}';
      final response = byMethodAndPath[key];
      if (response == null) {
        fail('Unhandled request in test: $key');
      }
      return response;
    }),
  );
}

Widget buildApp({required String initialRoute, required OnboardingApi onboardingApi}) {
  return ProviderScope(
    overrides: [onboardingApiProvider.overrideWithValue(onboardingApi)],
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

  group('BusinessScreen', () {
    testWidgets('prefills from an existing business profile', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingBusiness,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/business/': jsonResponse({
            'business': {
              'business_name': 'Zainab Textiles',
              'business_size': 'small',
              'has_employees': true,
              'avg_employee_pay': 150000.0,
              'spend_categories': ['inventory', 'rent'],
              'avg_monthly_revenue_range': '500k_2m',
              'description': 'Fabric wholesaler',
              'onboarding_step_completed': true,
            },
            'choices': {
              'business_size': [
                {'value': 'small', 'label': 'Small (2-10 people)'},
              ],
              'spend_categories': [
                {'value': 'inventory', 'label': 'Inventory & stock'},
              ],
              'revenue_ranges': [
                {'value': '500k_2m', 'label': '₦500,000 - ₦2,000,000'},
              ],
            },
          }, 200),
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Zainab Textiles'), findsOneWidget);
    });

    testWidgets('empty name is rejected on Continue, without saving', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingBusiness,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/business/': jsonResponse({'business': null, 'choices': {}}, 200),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter your business name'), findsOneWidget);
    });

    testWidgets('Skip moves on without calling the API at all', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingBusiness,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/business/': jsonResponse({'business': null, 'choices': {}}, 200),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('What are you working toward?'), findsOneWidget);
    });

    testWidgets('Continue with a name saves and advances to Goals', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingBusiness,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/business/': jsonResponse({'business': null, 'choices': {}}, 200),
          'PATCH /api/onboarding/business/': jsonResponse({
            'business_name': 'New Shop',
            'business_size': '',
            'has_employees': null,
            'avg_employee_pay': null,
            'spend_categories': [],
            'avg_monthly_revenue_range': '',
            'description': '',
            'onboarding_step_completed': true,
          }, 200),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'New Shop');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('What are you working toward?'), findsOneWidget);
    });

    testWidgets('a save rejection shows the backend message and stays put', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingBusiness,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/business/': jsonResponse({'business': null, 'choices': {}}, 200),
          'PATCH /api/onboarding/business/': jsonResponse(
            {'business_name': ['Business name is required.']},
            400,
          ),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'X');
      await tester.tap(find.byType(NuruPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Business name is required.'), findsOneWidget);
      expect(find.text('Tell us about your business'), findsOneWidget);
    });
  });

  group('GoalsScreen', () {
    testWidgets('lists existing goals', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingGoals,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/goals/': jsonResponse({
            'goals': [
              {'id': 1, 'goal_text': 'Save for new equipment', 'created_at': '2026-01-01'},
            ],
          }, 200),
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Save for new equipment'), findsOneWidget);
    });

    testWidgets('adding a goal calls the API and shows it in the list', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingGoals,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/goals/': jsonResponse({'goals': []}, 200),
          'POST /api/onboarding/goals/': jsonResponse(
            {'id': 5, 'goal_text': 'Hire a second tailor', 'created_at': '2026-01-02'},
            201,
          ),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hire a second tailor');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Hire a second tailor'), findsOneWidget);
    });

    testWidgets('deleting a goal removes it from the list', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingGoals,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/goals/': jsonResponse({
            'goals': [
              {'id': 1, 'goal_text': 'Save for new equipment', 'created_at': '2026-01-01'},
            ],
          }, 200),
          'DELETE /api/onboarding/goals/1/': http.Response('', 204),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Save for new equipment'), findsNothing);
    });

    testWidgets('Skip and Continue both advance to Connect', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingGoals,
        onboardingApi: mockOnboardingApi({
          'GET /api/onboarding/goals/': jsonResponse({'goals': []}, 200),
          'GET /api/mono/accounts/': jsonResponse({'accounts': []}, 200),
          'GET /api/onboarding/loans/': jsonResponse({'loans': []}, 200),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('Connect your finances'), findsOneWidget);
    });
  });

  group('ConnectScreen', () {
    testWidgets('shows a linked account instead of the connect button', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingConnect,
        onboardingApi: mockOnboardingApi({
          'GET /api/mono/accounts/': jsonResponse({
            'accounts': [
              {
                'id': 1,
                'provider': 'mono',
                'institution_name': 'GTBank',
                'account_name': 'Zainab Wahab',
                'account_number_masked': '4521',
                'status': 'connected',
                'created_at': '2026-01-01',
              },
            ],
          }, 200),
          'GET /api/onboarding/loans/': jsonResponse({'loans': []}, 200),
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('GTBank'), findsOneWidget);
      expect(find.text('Connect Bank Account'), findsNothing);
    });

    testWidgets('an initiate failure shows an error banner', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingConnect,
        onboardingApi: mockOnboardingApi({
          'GET /api/mono/accounts/': jsonResponse({'accounts': []}, 200),
          'GET /api/onboarding/loans/': jsonResponse({'loans': []}, 200),
          'POST /api/mono/connect/initiate/': jsonResponse(
            {'error': 'mono_not_configured', 'message': 'Account linking is not available right now.'},
            503,
          ),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect Bank Account'));
      await tester.pumpAndSettle();

      expect(find.text('Account linking is not available right now.'), findsOneWidget);
    });

    testWidgets('adding a loan via the sheet shows it in the list', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingConnect,
        onboardingApi: mockOnboardingApi({
          'GET /api/mono/accounts/': jsonResponse({'accounts': []}, 200),
          'GET /api/onboarding/loans/': jsonResponse({'loans': []}, 200),
          'POST /api/onboarding/loans/': jsonResponse({
            'id': 9,
            'amount': 200000.0,
            'interest_rate': null,
            'date_taken': '2026-01-01',
            'due_date': null,
            'lender_name': 'Aunty Bisi',
            'created_at': '2026-01-01',
          }, 201),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '200000');
      await tester.enterText(fields.at(2), 'Aunty Bisi');
      // Date Taken is a picker, not a text field — tap it and accept today.
      await tester.tap(find.text('Select date').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Loan'));
      await tester.pumpAndSettle();

      expect(find.text('Aunty Bisi'), findsOneWidget);
    });

    testWidgets('Continue and Skip both finish onboarding at /home', (tester) async {
      await tester.pumpWidget(buildApp(
        initialRoute: AppRoutes.onboardingConnect,
        onboardingApi: mockOnboardingApi({
          'GET /api/mono/accounts/': jsonResponse({'accounts': []}, 200),
          'GET /api/onboarding/loans/': jsonResponse({'loans': []}, 200),
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Connect your finances'), findsNothing);
    });
  });
}
