import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/add_news_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'services/ad_free_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  await ThemeService.init();
  await AdFreeService().init();

  // Auto-detect initial language code
  final initialLangCode = await LanguageService.getAutoDetectedLanguageCode();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Fallback initialize if options fail
    await Firebase.initializeApp();
  }

  // Auto news scraper will be migrated to Cloud Functions backend
  // AutoNewsScraper().init();

  runApp(
    EasyLocalization(
      supportedLocales: LanguageService.supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: Locale(initialLangCode),
      useOnlyLangCode: true,
      child: const GamesKhabarApp(),
    ),
  );
}

class GamesKhabarApp extends StatelessWidget {
  const GamesKhabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: 'app_name'.tr(),
          debugShowCheckedModeBanner: false,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: currentMode,
          home: const HomeScreen(),
          routes: {
            '/admin-login': (context) => const AdminLoginScreen(),
            '/admin-dashboard': (context) => const AdminDashboardScreen(),
            '/add-news': (context) => const AddNewsScreen(),
          },
        );
      },
    );
  }
}
