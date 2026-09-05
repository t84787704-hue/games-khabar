import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/gamer_theme.dart';
import 'services/language_service.dart';
import 'screens/gamer_app_root.dart';
import 'screens/create_gamer_id_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/gamer_search_screen.dart';
import 'screens/gamer_auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: GamerTheme.cardDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Fallback initialize if options fail
    await Firebase.initializeApp();
  }

  await LanguageService.init();

  runApp(const GamersIdApp());
}

class GamersIdApp extends StatelessWidget {
  const GamersIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gamers ID',
      debugShowCheckedModeBanner: false,
      theme: GamerTheme.themeData,
      home: const GamerAppRoot(),
      routes: {
        '/auth': (context) => const GamerAuthScreen(),
        '/create-id': (context) => const CreateGamerIdScreen(),
        '/create-post': (context) => const CreatePostScreen(),
        '/search': (context) => const GamerSearchScreen(),
      },
    );
  }
}

