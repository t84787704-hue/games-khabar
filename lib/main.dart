import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/add_news_screen.dart';
import 'services/notification_service.dart';
import 'services/bookmark_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run the app UI immediately so splash screen dismisses instantly
  runApp(const GamesKhabarApp());

  // Initialize services in background asynchronously without blocking app startup
  _initServicesInBackground();
}

void _initServicesInBackground() async {
  // 1. Initialize Firebase (with 3-second safety timeout)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 3));
    } catch (err) {
      debugPrint("Firebase init error: $err");
    }
  }

  // 2. Initialize local bookmarks cache
  try {
    await BookmarkService().init().timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint("BookmarkService init error: $e");
  }

  // 3. Register background handler for FCM
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("FCM background handler error: $e");
  }

  // 4. Setup Firebase Messaging topic subscriptions in background
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission().timeout(const Duration(seconds: 3));
    await messaging.subscribeToTopic('all_news').timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("FCM messaging setup non-fatal error: $e");
  }
}

class GamesKhabarApp extends StatelessWidget {
  const GamesKhabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Games Khabar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFF00FF88),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Color(0xFFFF4655),
          surface: Color(0xFF1E1E24),
          background: Color(0xFF0A0A0F),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/add-news': (context) => const AddNewsScreen(),
      },
    );
  }
}
