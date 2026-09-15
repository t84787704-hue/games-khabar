import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _prefKey = 'is_dark_theme';
  
  // ValueNotifier to update UI instantly across the app.
  // Default is ThemeMode.light (Day Mode) as requested.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;
  static bool get isDayMode => !isDarkMode;

  // Dynamic Theme Colors based on Day / Night Mode
  static Color get bg => isDarkMode ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC);
  static Color get appBarBg => isDarkMode ? const Color(0xFF121824) : const Color(0xFFFFFFFF);
  static Color get card => isDarkMode ? const Color(0xFF121824) : const Color(0xFFFFFFFF);
  static Color get cardSecondary => isDarkMode ? const Color(0xFF182234) : const Color(0xFFF1F5F9);
  static Color get border => isDarkMode ? const Color(0xFF1F2E45) : const Color(0xFFE2E8F0);
  static Color get textPrimary => isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get primaryGreen => isDarkMode ? const Color(0xFF00E676) : const Color(0xFF00A855);
  static Color get bottomNavBg => isDarkMode ? const Color(0xFF10141D) : const Color(0xFFFFFFFF);
  static Color get bottomNavBorder => isDarkMode ? const Color(0xFF1F2B3E) : const Color(0xFFE2E8F0);

  /// Initialize theme from SharedPreferences on app startup.
  /// Defaults to Day Mode (false).
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_prefKey) ?? false; // Day Mode is default
      themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
    }
    _updateSystemUI(isDarkMode);
  }

  /// Toggle or set theme mode and persist to SharedPreferences
  static Future<void> setTheme(bool isDark) async {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _updateSystemUI(isDark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, isDark);
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    await setTheme(!isDarkMode);
  }

  static void _updateSystemUI(bool isDark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF10141D) : const Color(0xFFFFFFFF),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  // --- Theme Definitions ---

  // Dark Theme (Night Mode: Premium Gaming Aesthetic)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0A0E17),
    primaryColor: const Color(0xFF00E5FF),
    canvasColor: const Color(0xFF0A0E17),
    cardColor: const Color(0xFF121824),
    dividerColor: const Color(0xFF1F2E45),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121824),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E5FF),
      secondary: Color(0xFFFF7A00),
      surface: Color(0xFF121824),
      background: Color(0xFF0A0E17),
      onPrimary: Colors.black,
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

  // Light Theme (Day Mode: Default Clean Bright Theme)
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    primaryColor: const Color(0xFF00A8FF),
    canvasColor: const Color(0xFFF8FAFC),
    cardColor: const Color(0xFFFFFFFF),
    dividerColor: const Color(0xFFE2E8F0),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0.5,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00A8FF),
      secondary: Color(0xFFFF7A00),
      surface: Color(0xFFFFFFFF),
      background: Color(0xFFF8FAFC),
      onPrimary: Colors.white,
      onSurface: Color(0xFF0F172A),
      onBackground: Color(0xFF0F172A),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF00B05C);
        }
        return const Color(0xFF94A3B8);
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF00B05C).withOpacity(0.35);
        }
        return const Color(0xFFE2E8F0);
      }),
    ),
  );
}
