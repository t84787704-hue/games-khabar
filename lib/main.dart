import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase initialize error: $e');
  }

  await LanguageService.init();
  await ThemeService.init();

  runApp(const GamersIdApp());
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
            title: 'Gamers ID',
            debugShowCheckedModeBanner: false,
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
            },
          ),
        );
      },
    );
  }
}

