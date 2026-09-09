import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuru_app/main.dart';
import 'package:nuru_app/providers/auth_provider.dart';
import 'package:nuru_app/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Without this the SharedPreferences platform channel throws
    // MissingPluginException inside the startup check.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NuruApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NuruApp()));
    expect(find.text('NURU'), findsOneWidget);
  });

  testWidgets('splash paints the brand mark on the very first frame',
      (WidgetTester tester) async {
    // No pumpAndSettle: this asserts against frame one specifically. If the
    // splash ever becomes an async gate, the first frame would be a spinner
    // and this fails.
    await tester.pumpWidget(const ProviderScope(child: NuruApp()));
    expect(find.text('NURU'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('signed-out user lands on /auth from Get Started',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith(
            (ref) async => const StartupState(StartDestination.auth),
          ),
        ],
        child: const NuruApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.authChoice), findsWidgets);
    expect(find.text('NURU'), findsNothing);
  });

  testWidgets('a returning user mid-onboarding resumes at their step',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith(
            (ref) async => const StartupState(
              StartDestination.onboarding,
              onboardingStep: 'goals',
            ),
          ),
        ],
        child: const NuruApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.onboardingGoals), findsWidgets);
  });

  testWidgets('a fully onboarded user goes straight to the dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith(
            (ref) async => const StartupState(StartDestination.home),
          ),
        ],
        child: const NuruApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pump();

    // BottomNavShell mounted, so the splash is gone.
    expect(find.text('Get Started'), findsNothing);
  });
}
