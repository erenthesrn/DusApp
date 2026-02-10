// lib/main.dart
import 'package:dus_app_1/screens/email_verification_page.dart';
import 'package:dus_app_1/screens/onboarding_page.dart';
import 'package:dus_app_1/screens/profile_screen.dart';
import 'package:intl/date_symbol_data_local.dart'; // Bunu ekle
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// --- SERVİS İMPORTLARI ---
import 'services/focus_service.dart';
import 'services/theme_provider.dart';

// Sayfalar
import 'screens/home_screen.dart';
import 'screens/login_page.dart';
import 'package:dus_app_1/screens/blog_screen.dart';
import 'package:dus_app_1/screens/quiz_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null); // Bunu ekle

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDNxUY3kYnZJNl-TtxCkCjSn94ubg97dgc",
        appId: "1:272729938344:web:6e766b4cb0c63e94f8259d",
        authDomain: "dusapp-17b00.firebaseapp.com",
        messagingSenderId: "272729938344",
        projectId: "dusapp-17b00",
        storageBucket: "dusapp-17b00.firebasestorage.app",
        measurementId: "G-9Z19HY8QBF"
      ),
    );
  } 
  else if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp();
  } 
  else {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCSEnLiJqIOIE0FxXNJNNmiNIWM85OFVKM",
        appId: "1:272729938344:android:f8312320eb7df19cf8259d",
        messagingSenderId: "272729938344",
        projectId: "dusapp-17b00",
      ),
    );
  }

  FocusService.instance; 

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

          // --- 1. PREMIUM AYDINLIK TEMA ---
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
            inputDecorationTheme: _buildInputDecorationTheme(Brightness.light),
            elevatedButtonTheme: _buildElevatedButtonTheme(),
          ),

          // --- 2. PREMIUM KARANLIK TEMA (DEEP DARK) ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            // Saf siyah yerine derin bir gece mavisi-antrasit tonu
            scaffoldBackgroundColor: const Color(0xFF0A0E14),
            primaryColor: const Color(0xFF1565C0),
            cardColor: const Color(0xFF161B22), // GitHub Dark stili kartlar
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF448AFF), // Karanlıkta parlayan açık mavi
              surface: Color(0xFF161B22),
              onSurface: Color(0xFFE6EDF3), // Kırık beyaz (göz yormaz)
              secondary: Color(0xFF00BFA5),
              error: Color(0xFFF85149),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0A0E14),
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(color: Color(0xFFE6EDF3), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            inputDecorationTheme: _buildInputDecorationTheme(Brightness.dark),
            elevatedButtonTheme: _buildElevatedButtonTheme(),
          ),

          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) {
                return const LoginPage();
              }
              return const LoginPage();
            },
          ),
        );
      }
    );
  }

  InputDecorationTheme _buildInputDecorationTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!)
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2)
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
    );
  }

  ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 2,
      ),
    );
  }
}