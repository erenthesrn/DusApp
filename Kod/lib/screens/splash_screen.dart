import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, TargetPlatform için
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

// Senin firebase_options dosyanın yolu
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final stopwatch = Stopwatch()..start();
    
    await _initBackEndServices();
    
    stopwatch.stop();
    final elapsedMillis = stopwatch.elapsedMilliseconds;
    
    const minDisplayTime = 5000; // 5 saniye
    
    if (elapsedMillis < minDisplayTime) {
      await Future.delayed(Duration(milliseconds: minDisplayTime - elapsedMillis));
    }

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _initBackEndServices() async {
    try {
      await initializeDateFormatting('tr_TR', null);

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

      FocusService.instance;
      
    } catch (e) {
      debugPrint("Başlatma hatası: $e");
    }
  }

  void _navigateToNextScreen() {
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
    // isDark kontrolü kaldırıldı, arka plan beyaza sabitlendi.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/loading_dent.json',
              controller: _controller,
              height: 200,
              repeat: true,
              frameRate: FrameRate.max,
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..repeat();
              },
              errorBuilder: (context, error, stackTrace) {
                 return const SizedBox(height: 200, child: Icon(Icons.error));
              },
            ),
            const SizedBox(height: 20),
            Text(
              "DUS Asistanı",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3b82f6), // Sabit mavi renk
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Veriler hazırlanıyor...",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600], // Gri tonu netleştirildi
              ),
            ),
          ],
        ),
      ),
    );
  }
}