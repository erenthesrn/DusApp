// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'home_screen.dart';
import 'guest_home_page.dart';
import 'onboarding_page.dart';
import 'email_verification_page.dart';
import '../utils/snackbar_helper.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  void _handleLogin() async {
    // Klavye açıksa kapat
    FocusScope.of(context).unfocus();

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
     SnackBarHelper.showSnackBar(
      context,
      "Lütfen tüm alanları doldurun.",
      backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Firebase Auth ile giriş yap
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        // 2. Firestore'dan kullanıcı verisini çek
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

          // 3. Bizim Custom 'isEmailVerified' alanımızı kontrol et
          // Eğer alan yoksa varsayılan false kabul et
          bool isCustomVerified = data['isEmailVerified'] ?? false;
          bool isOnboardingComplete = data['isOnboardingComplete'] ?? false;

          if (!isCustomVerified) {
            // --- E-POSTA ONAYLI DEĞİLSE ---
            // Oturumu kapatıp doğrulama sayfasına gönder
            // (Oturumu kapatmazsak Auth state karışabilir, ama verification sayfasında
            // currentUser lazım olduğu için burada kapatmıyoruz, sayfada çıkış butonu var zaten)
            
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const EmailVerificationPage()),
              );
              
              SnackBarHelper.showSnackBar(
                context,
                  "Lütfen önce e-posta adresinizi doğrulayın.",
                  backgroundColor: Colors.orange,
              );
            }
          } else {
            // --- E-POSTA ONAYLIYSA ---
            if (mounted) {
              SnackBarHelper.showSnackBar(
                context,
                  "Giriş Başarılı!",
                  backgroundColor: Colors.green,                
              );

              // Onboarding yapmışsa Home, yapmamışsa Onboarding
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => isOnboardingComplete 
                      ? const HomeScreen() 
                      : const OnboardingPage(),
                ),
              );
            }
          }
        } else {
          // Kullanıcı Auth'ta var ama Firestore'da yoksa (Nadirdir)
          if (mounted) {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (context) => const OnboardingPage()),
             );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Giriş başarısız.";
      if (e.code == 'user-not-found') {
        errorMessage = "Kullanıcı bulunamadı.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Şifre hatalı.";
      } else if (e.code == 'invalid-credential') {
        errorMessage = "E-posta veya şifre hatalı.";
      } else if (e.code == 'too-many-requests') {
        errorMessage = "Çok fazla deneme yaptınız. Lütfen biraz bekleyin.";
      }

      if (mounted) {
        SnackBarHelper.showSnackBar(
          context,
            errorMessage,
            backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showSnackBar(
          context,
            "Bir hata oluştu: $e",
            backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 BU EKRAN İÇİN ZORUNLU LIGHT MODE AYARI (Mevcut kodun korundu)
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
      data: lightTheme,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 224, 247, 250),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30.0), 
                    child: Image.asset('assets/images/logo.png', height: 150),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20), 
                    child: Builder( 
                      builder: (context) => Text('DUS Asistanı', textAlign: TextAlign.center, 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        const Text(
                          "“Zafer, 'zafer benimdir' diyebilenindir. Başarı ise, 'başaracağım' diye başlayıp, sonunda 'başardım' diyebilenindir.”",
                          textAlign: TextAlign.center, 
                          style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.blueGrey, fontFamily: 'Georgia', height: 1.5)
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Builder(
                            builder: (context) => Text("- Mustafa Kemal ATATÜRK",
                              style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-posta Adresi', prefixIcon: Icon(Icons.email_outlined)),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordPage())),
                      child: const Text('Şifremi Unuttum?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56, 
                    child: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('Giriş Yap', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("veya", style: TextStyle(color: Colors.grey[500]))),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: Builder(
                      builder: (context) => OutlinedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const GuestHomePage())),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Theme.of(context).primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Misafir olarak devam et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Üye değil misiniz?', style: TextStyle(color: Colors.grey)),
                      Builder(
                        builder: (context) => TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage())),
                          child: Text('Kayıt Ol', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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