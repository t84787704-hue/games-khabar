import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/add_news_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await ThemeService.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Agar options se fail ho to google-services.json se try karo
    await Firebase.initializeApp();
  }

  runApp(const GamesKhabarApp());
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
          title: 'Games Khabar',
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