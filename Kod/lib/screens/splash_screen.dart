import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, TargetPlatform için
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

// Senin firebase_options dosyanın yolu (kendi projene göre kontrol et)
import '../firebase_options.dart'; 
import 'home_screen.dart';
import 'login_page.dart';
import '../services/focus_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _isInitComplete = false;

  @override
  void initState() {
    super.initState();
    // Animasyon kontrolcüsü
    _controller = AnimationController(vsync: this);
    
    // Uygulama başlatma işlemlerini tetikle
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // 1. ANİMASYONUN BAŞLAMASINA İZİN VER
    // Ufak bir gecikme işlemcinin nefes almasını ve ilk karenin çizilmesini sağlar.
    await Future.delayed(const Duration(milliseconds: 100));

    // 2. PARALEL İŞLEMLER (Hepsi aynı anda başlasın)
    // - Min bekleme süresi (Animasyon en az 3 sn dönsün)
    // - Firebase başlatma
    // - Diğer servisler (Tarih formatı, Focus servisi vb.)
    
    final minWaitFuture = Future.delayed(const Duration(seconds: 3));
    
    final initFuture = _initBackEndServices();

    // İkisinin de bitmesini bekle
    await Future.wait([minWaitFuture, initFuture]);

    // 3. YÖNLENDİRME
    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _initBackEndServices() async {
    try {
      // Tarih formatını ayarla
      await initializeDateFormatting('tr_TR', null);

      // Firebase'i başlat (main.dart'tan aldığımız kod buraya geldi)
      if (Firebase.apps.isEmpty) { 
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
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          await Firebase.initializeApp();
        } else {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: "AIzaSyCSEnLiJqIOIE0FxXNJNNmiNIWM85OFVKM",
              appId: "1:272729938344:android:f8312320eb7df19cf8259d",
              messagingSenderId: "272729938344",
              projectId: "dusapp-17b00",
            ),
          );
        }
      }

      // Focus servisini başlat
      FocusService.instance;
      
    } catch (e) {
      debugPrint("Başlatma hatası: $e");
      // Hata olsa bile devam et, login ekranında hata verir gerekirse
    }
  }

  void _navigateToNextScreen() {
    // Artık Firebase hazır olduğu için currentUser'a bakabiliriz
    User? user = FirebaseAuth.instance.currentUser;
    
    Widget nextScreen;
    if (user != null) {
      nextScreen = const HomeScreen(); 
    } else {
      nextScreen = const LoginPage();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E14) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animasyonu
            Lottie.asset(
              'Assets/animations/loading_dent.json',
              controller: _controller,
              height: 200,
              // Animasyon yüklendiğinde oynat
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..repeat(); // Sürekli dönsün
              },
              // Eğer Lottie yüklenirken hata verirse boş kutu göster (Crash olmasın)
              errorBuilder: (context, error, stackTrace) {
                 return const SizedBox(height: 200, child: Icon(Icons.error));
              },
              // Performans ayarı: FrameBuilder ile kare atlamayı azaltabiliriz
              frameBuilder: (context, child, composition) {
                return child;
              },
            ),
            const SizedBox(height: 20),
            Text(
              "DUS Asistanı",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3b82f6),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Veriler hazırlanıyor...",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}