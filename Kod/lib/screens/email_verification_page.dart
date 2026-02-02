import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationPage> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;
  int countdown = 90; // 90 saniye bekleme süresi

  @override
  void initState() {
    super.initState();

    // Ekran açıldığında kullanıcının mail durumunu kontrol edebiliriz
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Eğer doğrulanmamışsa, kullanıcıya tekrar mail atma hakkı vermeden önce sayacı başlat
      startTimer();
      
      // Opsiyonel: Sayfa açıkken mail onaylanırsa otomatik algılamak için
      // Timer.periodic kullanarak checkEmailVerified() çağırabilirsin.
    }
  }

  void startTimer() {
    setState(() {
      canResendEmail = false;
      countdown = 90;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (countdown > 0) {
          countdown--;
        } else {
          canResendEmail = true;
          timer?.cancel();
        }
      });
    });
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      // Mail gönderildikten sonra sayacı tekrar başlat
      startTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doğrulama maili tekrar gönderildi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> cancelAndReturnToLogin() async {
    // Önce timer'ı durdur, bellek sızıntısını önle
    timer?.cancel();
    await FirebaseAuth.instance.signOut(); // Çıkış yap
    
    if (mounted) {
      // BURAYI DEĞİŞTİRİYORSUN:
      // Bu kod, "LoginScreen" sayfasına git ve gerideki tüm sayfaları hafızadan sil demektir.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()), 
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı çıkış yaparken anlık null olabilir, bu yüzden '??' ile koruma ekledik.
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "E-posta adresi alınamadı";

    return Scaffold(
      backgroundColor: Colors.white, // Tasarıma uygun arka plan
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'E-posta Doğrulama',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // İkon
              const Icon(
                Icons.mark_email_read_outlined, 
                size: 100, 
                color: Colors.blue
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                'Doğrulama Maili Gönderildi! 📧',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              // E-posta adresi metni
              Text(
                '$email adresine bir doğrulama bağlantısı gönderdik.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              
              const SizedBox(height: 20),
              
              // 1. İSTEK: Spam uyarısı eklendi
              const Text(
                'Lütfen mail kutunuzu (gelen kutusu veya spam/gereksiz klasörünü) kontrol edin ve gelen linke tıklayın.\nMail sunucularındaki yoğunluk nedeniyle e-postanızın ulaşması birkaç dakika sürebilir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              
              const SizedBox(height: 40),
              
              // 2. İSTEK: 90 Saniye Buton Mantığı
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: canResendEmail ? sendVerificationEmail : null,
                  icon: const Icon(Icons.email),
                  label: Text(
                    canResendEmail 
                      ? 'Tekrar Mail Gönder' 
                      : 'Tekrar Gönder (${countdown}s)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200], // Pasifken gri görünüm
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 3. İSTEK: Vazgeç Butonu
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
    );
  }
}