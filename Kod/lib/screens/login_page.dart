// lib/screens/login_page.dart
import 'package:flutter/material.dart';
// Diğer sayfalara geçiş yapacağı için onları import ediyoruz:
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/logo.png',height: 120,),
                const SizedBox(height: 16),
                Text('DUS Asistanı', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 8),
                const Text('Giriş yapın ve çalışmaya başlayın.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 48),
                
                // Email Input
                const TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'E-posta Adresi', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 20),
                
                // Şifre Input
                TextField(
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

                // --- ŞİFREMİ UNUTTUM BUTONU ---
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Şifremi Unuttum sayfasına git
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordPage()));
                    },
                    child: const Text('Şifremi Unuttum?'),
                  ),
                ),
                const SizedBox(height: 24),

                // Giriş Yap Butonu
                ElevatedButton(
                  onPressed: () {
                     // Giriş işlemi (backend) buraya gelecek
                  },
                  child: const Text('Giriş Yap'),
                ),

                const SizedBox(height: 32),

                // --- KAYIT OL ALANI ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Üye değil misiniz?', style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () {
                        // Kayıt Ol sayfasına git
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage()));
                      },
                      child: Text('Kayıt Ol', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}