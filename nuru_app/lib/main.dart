import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_routes.dart' as routes;
import 'screens/onboarding/mono_callback_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/nuru_theme.dart';

/// Web only: the Mono redirect opens a *new browser tab* (see ConnectScreen),
/// which cold-boots this same app at .../mono/callback?code=... — a real
/// path+query, not a hash route, so it's readable from Uri.base before any
/// routing happens. Matched by path suffix rather than an exact host so this
/// works the same on localhost, Railway, or any other deploy target.
String? _monoCallbackCode() {
  if (!kIsWeb) return null;
  if (!Uri.base.path.contains('/mono/callback')) return null;
  final code = Uri.base.queryParameters['code'];
  return (code != null && code.isNotEmpty) ? code : null;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: NuruTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    const ProviderScope(
      child: NuruApp(),
    ),
  );
}

class NuruApp extends StatelessWidget {
  const NuruApp({super.key});

  @override
  Widget build(BuildContext context) {
    final monoCode = _monoCallbackCode();

    return MaterialApp(
      title: 'NURU — AI Financial Copilot',
      debugShowCheckedModeBanner: false,
      theme: NuruTheme.darkTheme,
      // home, not initialRoute: the splash must paint synchronously on the
      // first frame. Named routes handle everything after it. The Mono
      // callback tab is the one deliberate exception — it has its own job to
      // do and was never going to show the splash anyway.
      home: monoCode != null
          ? MonoCallbackScreen(code: monoCode)
          : const SplashScreen(),
      routes: routes.buildRoutes()..remove(routes.AppRoutes.splash),
      onGenerateRoute: routes.onGenerateRoute,
    );
  }
}
