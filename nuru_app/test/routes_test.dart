import 'package:flutter_test/flutter_test.dart';
import 'package:nuru_app/routes/app_routes.dart';

void main() {
  group('AppRoutes', () {
    test('every declared route resolves to a builder', () {
      final routes = buildRoutes();
      for (final name in AppRoutes.all) {
        expect(
          routes.containsKey(name),
          isTrue,
          reason: 'AppRoutes.all lists "$name" but buildRoutes() has no builder '
              'for it — pushing it would hit onGenerateRoute instead.',
        );
      }
    });

    test('buildRoutes declares nothing that AppRoutes.all omits', () {
      for (final name in buildRoutes().keys) {
        expect(
          AppRoutes.all.contains(name),
          isTrue,
          reason: 'buildRoutes() has "$name" but AppRoutes.all omits it, so it '
              'is untested and unreachable by constant.',
        );
      }
    });

    test('route names are unique', () {
      expect(AppRoutes.all.toSet().length, AppRoutes.all.length);
    });

    test('every route name starts with a slash', () {
      for (final name in AppRoutes.all) {
        expect(name.startsWith('/'), isTrue, reason: '"$name" is not rooted');
      }
    });

    test('fromOnboardingStep maps the backend next_route values', () {
      expect(AppRoutes.fromOnboardingStep('business'), AppRoutes.onboardingBusiness);
      expect(AppRoutes.fromOnboardingStep('goals'), AppRoutes.onboardingGoals);
      expect(AppRoutes.fromOnboardingStep('connect'), AppRoutes.onboardingConnect);
      // null means onboarding is done — the caller sends them home.
      expect(AppRoutes.fromOnboardingStep(null), isNull);
      expect(AppRoutes.fromOnboardingStep('nonsense'), isNull);
    });
  });
}
