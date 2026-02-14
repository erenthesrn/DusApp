// lib/screens/signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_verification_page.dart';
import '../utils/snackbar_helper.dart';


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

  Future<void> _signUp() async {
    // Validasyonlar
    if (_passwordController.text != _confirmPasswordController.text) {
      SnackBarHelper.showSnackBar(context, 'Şifreler uyuşmuyor!');
      return;
    }
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      SnackBarHelper.showSnackBar(context, 'Lütfen tüm alanları doldurun.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Kullanıcıyı Firebase Auth'da oluştur
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. Kullanıcı verilerini Firestore'a kaydet
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'free',
          'isPremium': false,
          'isOnboardingComplete': false,
          'isEmailVerified': false, // Bizim custom doğrulama kontrolümüz
        });

        // 3. Kullanıcı adını güncelle
        await user.updateDisplayName(_nameController.text.trim());

        // --- KRİTİK DEĞİŞİKLİK BURADA ---
        // Eski "user.sendEmailVerification()" satırını SİLDİK.
        // Artık eski tip linkli mail GİTMEYECEK.
        
        // 4. Direkt Doğrulama Sayfasına Yönlendir
        if (mounted) {
          // pushAndRemoveUntil kullanarak geri gelmesini engelliyoruz
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
        SnackBarHelper.showSnackBar(
        context,
        errorMessage,
        backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DARK MODE ENGELLEYİCİ TEMA (Korundu)
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF0D47A1),
      scaffoldBackgroundColor: const Color.fromARGB(255, 224, 247, 250),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0D47A1),
        secondary: Color(0xFF00BFA5),
        surface: Colors.white,
        onSurface: Colors.black87,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
        labelStyle: TextStyle(color: Colors.grey[700]),
        prefixIconColor: Colors.grey[600],
      ),
    );

    return Theme(
      data: lightTheme, // Sayfayı zorla Light Mode yap
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 224, 247, 250),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) => Text('Yeni Hesap Oluştur', 
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                    ),
                  ),
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

                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Text('Kayıt Ol', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}