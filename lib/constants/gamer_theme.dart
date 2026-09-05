import 'package:flutter/material.dart';

class GamerTheme {
  // Core Colors
  static const Color bgDark = Color(0xFF0A0E17);
  static const Color cardDark = Color(0xFF121824);
  static const Color cardElevated = Color(0xFF182234);
  static const Color cardHover = Color(0xFF1E2B42);
  static const Color borderDark = Color(0xFF1F2E45);
  static const Color borderLight = Color(0xFF2A3C5A);

  // Accents: Blue & Orange
  static const Color accentBlue = Color(0xFF00D2FF);
  static const Color electricBlue = Color(0xFF2563EB);
  static const Color deepBlue = Color(0xFF0F172A);
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color flameOrange = Color(0xFFFF8A00);
  static const Color redAccent = Color(0xFFFF3366);
  static const Color neonGreen = Color(0xFF00E676);

  // Typography
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textGray = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient blueOrangeGradient = LinearGradient(
    colors: [Color(0xFF00D2FF), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient electricBlueGradient = LinearGradient(
    colors: [Color(0xFF00D2FF), Color(0xFF0066FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient flameOrangeGradient = LinearGradient(
    colors: [Color(0xFFFF8A00), Color(0xFFFF4500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF141C2B), Color(0xFF0F1522)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const List<String> favoriteGames = [
    'BGMI',
    'PUBG',
    'Free Fire',
    'COD Mobile',
    'Valorant',
  ];

  static const Map<String, String> gameEmojis = {
    'BGMI': '🎖️',
    'PUBG': '🪂',
    'Free Fire': '🔥',
    'COD Mobile': '🎯',
    'Valorant': '⚡',
  };

  static const Map<String, Color> gameColors = {
    'BGMI': Color(0xFFFF9900),
    'PUBG': Color(0xFFF59E0B),
    'Free Fire': Color(0xFFFF3B30),
    'COD Mobile': Color(0xFF00D2FF),
    'Valorant': Color(0xFFFF4655),
  };

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: accentBlue,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentOrange,
        surface: cardDark,
        background: bgDark,
        error: redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: accentBlue,
        unselectedItemColor: textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: redAccent),
        ),
      ),
    );
  }
}
