import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/add_news_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Notification service agar aap use kar rahe ho
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Notification init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Games Khabar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/adminLogin': (context) => const AdminLoginScreen(),
        '/adminDashboard': (context) => const AdminDashboardScreen(),
        '/addNews': (context) => const AddNewsScreen(),
      },
    );
  }
}