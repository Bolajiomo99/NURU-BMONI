import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/nuru_theme.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const OnboardingScreen(),
    );
  }
}
