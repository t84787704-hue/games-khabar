import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _prefKey = 'is_dark_theme';
  
  // ValueNotifier to update UI instantly across the app
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  /// Initialize theme from SharedPreferences on app startup
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_prefKey) ?? true; // Default to dark mode for Games Khabar
      themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  /// Toggle or set theme mode and persist to SharedPreferences
  static Future<void> setTheme(bool isDark) async {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, isDark);
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    await setTheme(!isDarkMode);
  }

  // --- Theme Definitions ---

  // Dark Theme (Default Gaming Aesthetic)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    primaryColor: const Color(0xFF00FF88),
    canvasColor: const Color(0xFF0A0A0A),
    cardColor: const Color(0xFF1E1E24),
    dividerColor: const Color(0xFF2E2E38),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF141414),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF00FF88)),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00FF88),
      secondary: Color(0xFF00FF88),
      surface: Color(0xFF1E1E24),
      background: Color(0xFF0A0A0A),
      onPrimary: Color(0xFF05080D),
      onSurface: Colors.white,
      onBackground: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF00FF88);
        }
        return const Color(0xFF9E9EA7);
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF00FF88).withOpacity(0.4);
        }
        return const Color(0xFF2E2E38);
      }),
    ),
  );

  // Light Theme (Day Mode: White BG, Black Text, Clean Accents)
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFF00C868),
    canvasColor: const Color(0xFFFFFFFF),
    cardColor: const Color(0xFFF5F5F7),
    dividerColor: const Color(0xFFE5E5EA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F9FA),
      foregroundColor: Color(0xFF111111),
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF00A855)),
      titleTextStyle: TextStyle(
        color: Color(0xFF111111),
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00C868),
      secondary: Color(0xFF00A855),
      surface: Color(0xFFF5F5F7),
      background: Color(0xFFFFFFFF),
      onPrimary: Colors.white,
      onSurface: Color(0xFF111111),
      onBackground: Color(0xFF111111),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF00A855);
        }
        return const Color(0xFFB0B0B8);
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF00C868).withOpacity(0.35);
        }
        return const Color(0xFFE5E5EA);
      }),
    ),
  );
}
