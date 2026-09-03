import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NuruTheme {
  // ─── Brand Colors ───────────────────────────────────────────────
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF141929);
  static const Color surfaceLight = Color(0xFF1E2538);
  static const Color surfaceElevated = Color(0xFF252D42);
  static const Color cardBg = Color(0xFF161B2E);

  static const Color primary = Color(0xFF00D09E);
  static const Color primaryDark = Color(0xFF00B386);
  static const Color primaryLight = Color(0xFF33DBAE);
  static const Color primarySubtle = Color(0xFF0D3D32);

  static const Color accent = Color(0xFF7C5CFC);
  static const Color accentLight = Color(0xFF9B82FC);
  static const Color accentSubtle = Color(0xFF1E1640);

  static const Color textPrimary = Color(0xFFF2F4F7);
  static const Color textSecondary = Color(0xFF9BA3B5);
  static const Color textMuted = Color(0xFF5E6780);

  static const Color healthyGreen = Color(0xFF12B76A);
  static const Color warningAmber = Color(0xFFF79009);
  static const Color dangerRed = Color(0xFFF04438);

  static const Color divider = Color(0xFF1E2538);

  // ─── Gradients ──────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D09E), Color(0xFF00B386)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D3D32), Color(0xFF0A0E1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161B2E), Color(0xFF0F1320)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Helper: Category Icon + Color ──────────────────────────────
  static IconData categoryIcon(String category) {
    switch (category) {
      case 'freelance':
        return Icons.laptop_mac_rounded;
      case 'salary':
        return Icons.account_balance_rounded;
      case 'transfer':
        return Icons.send_rounded;
      case 'remittance':
        return Icons.send_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'utilities':
        return Icons.bolt_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'rent':
        return Icons.home_rounded;
      case 'family_support':
        return Icons.people_rounded;
      case 'data_airtime':
        return Icons.phone_android_rounded;
      case 'swap':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static Color categoryColor(String category) {
    switch (category) {
      case 'freelance':
      case 'salary':
        return healthyGreen;
      case 'transfer':
      case 'remittance':
      case 'family_support':
        return const Color(0xFF3B82F6);
      case 'food':
        return const Color(0xFFF97316);
      case 'transport':
        return const Color(0xFF8B5CF6);
      case 'utilities':
      case 'data_airtime':
        return warningAmber;
      case 'entertainment':
        return const Color(0xFFEC4899);
      case 'shopping':
        return const Color(0xFF06B6D4);
      case 'health':
        return dangerRed;
      case 'education':
        return accent;
      case 'savings':
        return primary;
      case 'rent':
        return const Color(0xFF78716C);
      case 'swap':
        return accentLight;
      default:
        return textMuted;
    }
  }

  // ─── Date Formatting Helper ─────────────────────────────────────
  static String relativeDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final diff = today.difference(dateOnly).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return '${diff}d ago';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return '';
    }
  }

  // ─── ThemeData ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: dangerRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.copyWith(
          headlineLarge: GoogleFonts.outfit(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: GoogleFonts.outfit(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: GoogleFonts.outfit(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 16,
          ),
          bodyMedium: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 14,
          ),
          labelLarge: GoogleFonts.outfit(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Color(0xFF0A0E1A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      dividerColor: divider,
    );
  }
}
