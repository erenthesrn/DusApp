// lib/screens/signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding_page.dart'; // 🔥 Hedef sayfamız burası
import 'email_verification_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🔥 GÜNCELLENMİŞ KAYIT FONKSİYONU
  Future<void> _signUp() async {
    // 1. Kontroller
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreler uyuşmuyor!')));
      return;
    }
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Kullanıcıyı Oluştur
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // 3. İsim Bilgisini Kaydet (Firestore)
        // Burada 'isOnboardingComplete': false diyoruz ki sistem henüz tamamlamadığını bilsin.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'free',
          'isPremium': false,
          'isOnboardingComplete': false, // 🔥 Yeni ekledik
        });

        // 4. İsim Bilgisini Auth Profiline de İşle (Daha hızlı erişim için)
        await user.updateDisplayName(_nameController.text.trim());

        // 5. Doğrulama Mailini Sessizce Gönder (Zorlama yok)
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }

        // 6. 🔥 KRİTİK DEĞİŞİKLİK: Çıkış yapmıyoruz! Direkt Onboarding'e gönderiyoruz.
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const EmailVerificationPage()),
            (route) => false,
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Bir hata oluştu.";
      if (e.code == 'email-already-in-use') errorMessage = "Bu e-posta zaten kullanılıyor.";
      else if (e.code == 'weak-password') errorMessage = "Şifre çok zayıf.";
      else if (e.code == 'invalid-email') errorMessage = "Geçersiz e-posta formatı.";

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Yeni Hesap Oluştur', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 8),
                const Text('DUS hazırlık sürecinde aramıza katılın.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline)),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta Adresi', prefixIcon: Icon(Icons.email_outlined)),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () { setState(() { _isPasswordVisible = !_isPasswordVisible; }); },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Şifre Tekrar',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () { setState(() { _isConfirmPasswordVisible = !_isConfirmPasswordVisible; }); },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Kayıt Ol', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}