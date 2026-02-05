// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Web ve Platform kontrolü için şart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Beni Hatırla için ekledik
import 'firebase_options.dart';

// Sayfalar
import 'screens/home_screen.dart';
import 'screens/login_page.dart';
// Diğer importlarını da korudum
import 'package:dus_app_1/screens/blog_screen.dart';
import 'package:dus_app_1/screens/quiz_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- PLATFORM AYARLARI (SENİN KODUN) ---
  if (kIsWeb) {
    // Web için özel ayarlar (Web kullanıyorsan burayı doldurman gerekebilir)
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
    // --- iOS (IPHONE) İÇİN ---
    // GoogleService-Info.plist dosyasından otomatik okur.
    await Firebase.initializeApp();
  } 
  else {
    // --- ANDROID İÇİN ---
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCSEnLiJqIOIE0FxXNJNNmiNIWM85OFVKM",
        appId: "1:272729938344:android:f8312320eb7df19cf8259d",
        messagingSenderId: "272729938344",
        projectId: "dusapp-17b00",
      ),
    );
  }

  runApp(const DusApp());
}

class DusApp extends StatelessWidget {
  const DusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DUS Asistanı',
      debugShowCheckedModeBanner: false,
      
      // --- TEMA AYARLARI ---
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1), // Koyu Mavi
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFF00BFA5), // Turkuaz
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),

      // 🔥 GİRİŞ KONTROLÜ (STREAMBUILDER)
      // Artık sabit LoginPage yerine burası var.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Durum: Firebase henüz yanıt vermedi, bekliyoruz (Loading)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // 2. Durum: Kullanıcı verisi VAR -> Ana Sayfaya git
          if (snapshot.hasData) {
            return const HomeScreen();
          }

          // 3. Durum: Kullanıcı verisi YOK -> Giriş Sayfasına git
          return const LoginPage();
        },
      ),
    );
  }
}