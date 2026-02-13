import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/theme_provider.dart';
import 'services/focus_service.dart';

// Not: Firebase importlarını buradan kaldırabilirsin, Splash'e taşıyacağız.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // DİKKAT: Artık burada await Firebase... yok!
  // Uygulama anında açılacak.
  
  runApp(const DusApp());
}

class DusApp extends StatelessWidget {
  const DusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'DUS Asistanı',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeProvider.instance.themeMode,
          
          // --- TEMALAR (Senin mevcut temaların) ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF0D47A1),
            scaffoldBackgroundColor: const Color(0xFFF5F9FF),
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D47A1),
              primary: const Color(0xFF0D47A1),
              surface: Colors.white,
              onSurface: const Color(0xFF1E293B),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0E14),
            primaryColor: const Color(0xFF1565C0),
            cardColor: const Color(0xFF161B22),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF448AFF),
              surface: Color(0xFF161B22),
              onSurface: Color(0xFFE6EDF3),
            ),
          ),

          // Başlangıç her zaman Splash Screen
          home: const SplashScreen(),
        );
      }
    );
  }
}