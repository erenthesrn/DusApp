import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'; // Veritabanı okumak için eklendi
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../services/custom_auth_service.dart'; 
import 'onboarding_page.dart'; 
import 'home_screen.dart'; // Ana sayfa eklendi
import 'login_page.dart';
import '../utils/snackbar_helper.dart';


class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationPage> {
  final TextEditingController _codeController = TextEditingController();
  final CustomAuthService _authService = CustomAuthService();
  
  bool isResendButtonActive = false;
  bool isLoading = false;
  Timer? countdownTimer;
  int countdown = 90; 

  @override
  void initState() {
    super.initState();
    _sendInitialCode();
  }

  Future<void> _sendInitialCode() async {
    await _sendCodeToUser();
  }

  Future<void> _sendCodeToUser() async {
    setState(() {
      isResendButtonActive = false;
      countdown = 90;
    });

    startCountdownTimer();

    try {
      await _authService.sendVerificationCode();
      if (mounted) {
        SnackBarHelper.showSnackBar(
          context,
          'Doğrulama kodu mail adresine gönderildi!',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showSnackBar(
          context,
          'Kod gönderilemedi: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  // --- BURASI GÜNCELLENDİ: AKILLI YÖNLENDİRME ---
  Future<void> _verifyInputCode() async {
    String inputCode = _codeController.text.trim();

    if (inputCode.length != 6) {
      SnackBarHelper.showSnackBar(
        context,
        'Lütfen 6 haneli kodu eksiksiz girin.'
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Kodu Doğrula
      bool isSuccess = await _authService.verifyCode(inputCode);

      if (isSuccess) {
        // 2. Kullanıcı Verisini Çek (Onboarding yapmış mı?)
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          // Veritabanında 'isOnboardingComplete' true mu diye bak
          bool isSetupDone = false;
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            isSetupDone = data?['isOnboardingComplete'] ?? false;
          }

          if (mounted) {
            SnackBarHelper.showSnackBar(
              context,
              'Tebrikler! Hesabın doğrulandı.',
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
            );
            
            // 3. Duruma Göre Yönlendir
            Widget targetPage = isSetupDone ? const HomeScreen() : const OnboardingPage();

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => targetPage), 
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showSnackBar(
          context,
            e.toString().replaceAll("Exception: ", ""),
            backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void startCountdownTimer() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          if (countdown > 0) {
            countdown--;
          } else {
            isResendButtonActive = true;
            countdownTimer?.cancel();
          }
        });
      }
    });
  }

  Future<void> cancelAndReturnToLogin() async {
    countdownTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()), 
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "E-posta adresi alınamadı";

    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: const Color(0xFF0D47A1),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Color(0xFF0D47A1)),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 100, 
                  color: Colors.blue
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Kodu Girin',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                Text(
                  '$email adresine gönderilen\n6 haneli doğrulama kodunu girin.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                
                const SizedBox(height: 30),

                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 12,
                    color: Colors.blue
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "------",
                    hintStyle: TextStyle(color: Colors.grey[300], letterSpacing: 12),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _verifyInputCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: isLoading 
                      ? const SizedBox(
                          height: 24, 
                          width: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          'ONAYLA',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isResendButtonActive ? _sendCodeToUser : null,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      isResendButtonActive 
                        ? 'Kodu Tekrar Gönder' 
                        : 'Tekrar Gönder (${countdown}s)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                TextButton(
                  onPressed: cancelAndReturnToLogin,
                  child: const Text(
                    'Vazgeç ve Girişe Dön',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}