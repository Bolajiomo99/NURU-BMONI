import 'package:flutter/material.dart';

import '../screens/auth/auth_choice_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/bottom_nav_shell.dart';
import '../screens/onboarding/business_screen.dart';
import '../screens/onboarding/connect_screen.dart';
import '../screens/onboarding/goals_screen.dart';
import '../screens/splash_screen.dart';

/// Named routes for the app.
///
/// Route names live here as constants so a typo is a compile error rather than
/// a runtime "route not found" crash. `routes_test.dart` asserts every constant
/// in [all] resolves to a builder in [buildRoutes].
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';

  static const String authChoice = '/auth';
  static const String signup = '/auth/signup';
  static const String otp = '/auth/otp';
  static const String login = '/auth/login';
  static const String forgotPassword = '/auth/forgot';
  static const String resetPassword = '/auth/reset';

  static const String onboardingBusiness = '/onboarding/business';
  static const String onboardingGoals = '/onboarding/goals';
  static const String onboardingConnect = '/onboarding/connect';

  static const String home = '/home';

  /// Every route the app can navigate to. Kept in sync with [buildRoutes] by
  /// a test, so adding one without a builder fails CI.
  static const List<String> all = [
    splash,
    authChoice,
    signup,
    otp,
    login,
    forgotPassword,
    resetPassword,
    onboardingBusiness,
    onboardingGoals,
    onboardingConnect,
    home,
  ];

  /// Maps the onboarding `next_route` value the backend returns
  /// (`business` | `goals` | `connect` | null) onto a route name.
  static String? fromOnboardingStep(String? step) {
    switch (step) {
      case 'business':
        return onboardingBusiness;
      case 'goals':
        return onboardingGoals;
      case 'connect':
        return onboardingConnect;
      default:
        return null;
    }
  }
}

/// Screens still to be built land here as they arrive (CP5b / CP6).
class _Placeholder extends StatelessWidget {
  final String routeName;
  const _Placeholder(this.routeName);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routeName)),
      body: Center(child: Text('$routeName — not built yet')),
    );
  }
}

Map<String, WidgetBuilder> buildRoutes() {
  return <String, WidgetBuilder>{
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.home: (_) => const BottomNavShell(),

    AppRoutes.authChoice: (_) => const AuthChoiceScreen(),
    AppRoutes.signup: (_) => const SignupScreen(),
    AppRoutes.otp: (_) => const OtpScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),

    AppRoutes.onboardingBusiness: (_) => const BusinessScreen(),
    AppRoutes.onboardingGoals: (_) => const GoalsScreen(),
    AppRoutes.onboardingConnect: (_) => const ConnectScreen(),
  };
}

/// Fallback for an unknown route name, so a bad push shows a real screen
/// instead of a black void.
Route<dynamic> onGenerateRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => _Placeholder(settings.name ?? 'unknown route'),
  );
}
