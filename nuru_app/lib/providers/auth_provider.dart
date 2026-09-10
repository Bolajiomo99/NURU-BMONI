import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../services/auth_api.dart';
import '../services/onboarding_api.dart';

/// Override these in tests with services built on a MockClient.
final authApiProvider = Provider<AuthApi>((ref) => AuthApi());
final onboardingApiProvider = Provider<OnboardingApi>((ref) => OnboardingApi());

/// Where the splash should send the user, decided once on cold start.
enum StartDestination { auth, onboarding, home }

class StartupState {
  final StartDestination destination;

  /// Which onboarding step to resume at, when [destination] is onboarding.
  final String? onboardingStep;

  const StartupState(this.destination, {this.onboardingStep});
}

/// Resolves the stored token into a landing destination.
///
/// Deliberately not consumed by `MaterialApp.home` — the splash renders
/// synchronously and awaits this while it animates, so the first frame is
/// always the brand mark rather than a spinner.
final startupProvider = FutureProvider<StartupState>((ref) async {
  final session = await ref.read(authApiProvider).me();
  if (session == null) return const StartupState(StartDestination.auth);

  final status = await ref.read(onboardingApiProvider).status();
  // Unknown status: send them to the app rather than restarting onboarding.
  if (status == null) return const StartupState(StartDestination.home);

  final next = status['next_route'] as String?;
  if (next == null) return const StartupState(StartDestination.home);
  return StartupState(StartDestination.onboarding, onboardingStep: next);
});

/// The signed-in account, or null when signed out.
class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  final AuthApi _api;

  AuthController(this._api) : super(const AsyncValue.data(null));

  Future<AuthSession> verifyOtp({required String email, required String code}) async {
    state = const AsyncValue.loading();
    try {
      final session = await _api.verifyOtp(email: email, code: code);
      state = AsyncValue.data(session);
      return session;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthSession> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final session = await _api.login(email: email, password: password);
      state = AsyncValue.data(session);
      return session;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> restore() async {
    state = AsyncValue.data(await _api.me());
  }

  Future<void> logout() async {
    await ApiService.logout();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>(
  (ref) => AuthController(ref.read(authApiProvider)),
);

/// Where to land right after a signup verification or login succeeds — the
/// same next_route -> destination mapping [startupProvider] uses for a
/// restored session, minus the token check since the caller just got one.
Future<String> resolvePostAuthRoute(OnboardingApi api) async {
  final status = await api.status();
  if (status == null) return AppRoutes.home;
  final next = status['next_route'] as String?;
  if (next == null) return AppRoutes.home;
  return AppRoutes.fromOnboardingStep(next) ?? AppRoutes.home;
}
