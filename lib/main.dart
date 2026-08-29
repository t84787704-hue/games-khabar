import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
  runApp(const GamesKhabarApp());
}

class GamesKhabarApp extends StatelessWidget {
  const GamesKhabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Games Khabar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E13),
        primaryColor: const Color(0xFF00FF88),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Color(0xFFFF4655),
          surface: Color(0xFF151A23),
          background: Color(0xFF0A0E13),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
