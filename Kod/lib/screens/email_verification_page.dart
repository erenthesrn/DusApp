// lib/screens/email_verification_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_page.dart'; // Doğrulama bitince buraya gidecek

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    
    // Sayfa açılır açılmaz kontrol et: Zaten onaylı mı?
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Onaylı değilse mail gönder
      _sendVerificationEmail();
      
      // Her 3 saniyede bir "Acaba onayladı mı?" diye kontrol et
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    // Firebase'den güncel durumu çek (Burası çok önemli, yoksa eski cache'i okur)
    await FirebaseAuth.instance.currentUser?.reload();
    
    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    // Eğer onaylandıysa Timer'ı durdur ve Tanışma Ekranına git
    if (isEmailVerified) {
      timer?.cancel();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
        );
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 10)); // 10 sn buton kilidi
      setState(() => canResendEmail = true);
    } catch (e) {
      // Hata olursa (örn: çok sık tıkladı)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eğer zaten onaylıysa direkt sayfayı geç (Güvenlik önlemi)
    if (isEmailVerified) {
      return const OnboardingPage();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("E-posta Doğrulama"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 100, color: Colors.blue),
            const SizedBox(height: 32),
            const Text(
              "Doğrulama Maili Gönderildi! 📧",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "${FirebaseAuth.instance.currentUser?.email}\n adresine bir doğrulama bağlantısı gönderdik.",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              "Lütfen mail kutunuzu kontrol edin ve gelen linke tıklayın. Sayfa otomatik olarak güncellenecektir.",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Mail Gelmedi Butonu
            ElevatedButton.icon(
              onPressed: canResendEmail ? _sendVerificationEmail : null,
              icon: const Icon(Icons.email),
              label: const Text("Tekrar Mail Gönder"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Vazgeç butonu (Girişe döner)
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text("Vazgeç ve Girişe Dön", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}