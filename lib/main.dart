import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/supabase_service.dart';
import 'constants/gamer_theme.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'screens/gamer_app_root.dart';
import 'screens/create_gamer_id_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/gamer_search_screen.dart';
import 'screens/gamer_auth_screen.dart';
import 'screens/banned_screen.dart';
import 'screens/gamer_privacy_policy_screen.dart';
import 'screens/gamer_terms_of_service_screen.dart';
import 'services/notification_service.dart';

// ✅ Global Notification Plugin Instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Notification Permission, Sound aur Vibration Setup
Future<void> initNotificationService() async {
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service init error: $e');
  }
}

// ✅ Jab bhi mobile bajana ho, yeh function call karein
Future<void> showLocalNotification({
  required String title,
  required String body,
}) async {
  try {
    await NotificationService().showBannerNotification(
      title: title,
      body: body,
    );
  } catch (e) {
    debugPrint('Show notification error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase initialize error: $e');
  }

  // ✅ Initialize Notifications & Request Permission on startup
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  // ✅ Language init
  try {
    await LanguageService.init();
  } catch (e) {
    debugPrint('LanguageService init error: $e');
  }

  // ✅ Theme init
  try {
    await ThemeService.init();
  } catch (e) {
    debugPrint('ThemeService init error: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const GamersIdApp(),
    ),
  );
}

class GamersIdApp extends StatelessWidget {
  const GamersIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, themeMode, _) {
        return SafeArea(
          top: true,
          bottom: true,
          child: MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            key: ValueKey(themeMode),
            title: 'Gamers ID',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            themeMode: themeMode,
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            builder: (context, child) {
              return SafeArea(
                top: true,
                bottom: true,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const GamerAppRoot(),
            routes: {
              '/auth': (context) => const GamerAuthScreen(),
              '/create-id': (context) => const CreateGamerIdScreen(),
              '/create-post': (context) => const CreatePostScreen(),
              '/search': (context) => const GamerSearchScreen(),
              '/banned': (context) => const BannedScreen(),
              '/privacy-policy': (context) => const GamerPrivacyPolicyScreen(),
              '/terms': (context) => const GamerTermsOfServiceScreen(),
            },
          ),
        );
      },
    );
  }
}
