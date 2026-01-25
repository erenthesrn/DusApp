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
  // Metin kutularını okumak için gerekli araçlar(kullanıcıadı veya şifreyi kontrol etmek için):
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Butona basılınca dönmeye başlaması için bu değişkeni tutuyoruz
  bool _isLoading = false;

  // ===========================================================================
  // ||                                                                       ||
  // ||  BAŞLANGIÇ: LOADING (YÜKLENİYOR) VE GİRİŞ MANTIĞI                     ||
  // ||  Burada butona basılınca neler olacağı tanımlanıyor.                  ||
  // ||                                                                       ||
  // ===========================================================================
  void _handleLogin() async {
    // ADIM 1: Klavyeyi kapat (Görsel temizlik için)
    FocusScope.of(context).unfocus();

    //Yazıları al
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun."), backgroundColor: Colors.red,),
       
      );
      return; //Hata varsa dur, aşağı inme!
    }
    //KONTROL 2: Mail geçerli mi?
    // Bu 'RegExp' kodu mailin içinde @ var mı, sonunda .com/.net var mı diye bakar.
    final bool emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

    if (!emailValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen geçerli bir e-posta giriniz (örn: ali@gmail.com)"), 
          backgroundColor: Colors.orange
        ),
      );
      return; // Hata varsa dur!
    }

    // ADIM 2: Yükleniyor animasyonunu BAŞLAT
    setState(() {
      _isLoading = true;
    });

    // ADIM 3: Backend'e istek atıyor gibi bekle (Simülasyon - 2 Saniye)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // ADIM 4: Yükleniyor animasyonunu BİTİR
      setState(() {
        _isLoading = false;
      });
      
      // ADIM 5: Kullanıcıya mesaj göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Giriş Başarılı! Yönlendiriliyorsunuz..."),
          backgroundColor: Colors.green, // Başarılı ise yeşil
          duration: Duration(seconds: 2),
        )
      );
      
      // NOT: Buraya daha sonra Quiz ekranına yönlendirme kodu gelecek.
      // Navigator.pushReplacement...
    }
  }
  // ===========================================================================
  // ||  BİTİŞ: LOADING MANTIĞI SONU                                          ||
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/logo.png',height: 200,),
                const SizedBox(height: 16),
                Text('DUS Asistanı', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 8),
                const Text('Giriş yapın ve çalışmaya başlayın.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 48),
                
                // Email Input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'E-posta Adresi', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 20),
                
                // Şifre Input
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
              // --- GİRİŞ BUTONU ---
                SizedBox(
                  height: 56, 
                  child: ElevatedButton(
                    // Eğer yükleniyorsa tıkla(ma)yacak (null), değilse fonksiyon çalışacak
                    onPressed: _isLoading ? null : _handleLogin, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 24, 
                          width: 24, 
                          // Standart dönen beyaz daire
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                        )
                      : const Text(
                          'Giriş Yap', 
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                  ),
                ),

                const SizedBox(height: 32),

                // --- VEYA ÇİZGİSİ ---
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("veya", style: TextStyle(color: Colors.grey[500])),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),

                const SizedBox(height: 24),

                // --- MİSAFİR BUTONU ---
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Misafir girişi yapıldı."), 
                        backgroundColor: Colors.blueGrey,
                        duration: Duration(milliseconds: 2000), // 2000 ms = 2 saniye
                        )
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Misafir olarak devam et',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).primaryColor
                      ),
                    ),
                  ),
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