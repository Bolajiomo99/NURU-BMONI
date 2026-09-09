import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_routes.dart' as routes;
import 'screens/splash_screen.dart';
import 'theme/nuru_theme.dart';

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
    return MaterialApp(
      title: 'NURU — AI Financial Copilot',
      debugShowCheckedModeBanner: false,
      theme: NuruTheme.darkTheme,
      // home, not initialRoute: the splash must paint synchronously on the
      // first frame. Named routes handle everything after it.
      home: const SplashScreen(),
      routes: routes.buildRoutes()..remove(routes.AppRoutes.splash),
      onGenerateRoute: routes.onGenerateRoute,
    );
  }
}
