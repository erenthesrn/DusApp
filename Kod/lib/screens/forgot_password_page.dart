// lib/screens/forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth eklendi
import 'package:dus_app_1/Fish.dart'; // Senin özel ikon dosyan

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Metin kutusunu kontrol etmek için
  final TextEditingController _emailController = TextEditingController();
  
  // Yükleniyor durumu (Buton dönsün diye)
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose(); // Sayfa kapanınca hafızadan sil
    super.dispose();
  }

  // 🔥 ŞİFRE SIFIRLAMA FONKSİYONU
  Future<void> _resetPassword() async {
    // 1. Klavyeyi kapat
    FocusScope.of(context).unfocus();

    String email = _emailController.text.trim();

    // 2. Boş alan kontrolü
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen e-posta adresinizi girin."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Yükleniyor başlat
    });

    try {
      // 3. Firebase'e İstek Gönder
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        // 4. Başarılı Mesajı Göster
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Bağlantı Gönderildi 📨"),
            content: const Text("E-posta adresinize şifre sıfırlama bağlantısı gönderildi. Lütfen spam kutunuzu da kontrol etmeyi unutmayın."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Dialogu kapat
                  Navigator.pop(context); // Bu sayfayı kapat ve Giriş'e dön
                },
                child: const Text("Tamam"),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 5. Hata Yönetimi
      String errorMessage = "Bir hata oluştu.";
      
      if (e.code == 'user-not-found') {
        errorMessage = "Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Geçersiz e-posta formatı.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Her durumda yükleniyor simgesini durdur
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 224, 247, 250),
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Senin özel ikonun
              Icon(Fish.fish_svgrepo_com, size: 100, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 24),
              
              Text('Şifrenizi mi unuttunuz?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 12),
              
              const Text(
                'Hesabınıza bağlı e-posta adresinizi girin, size şifre sıfırlama bağlantısı gönderelim.',
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Email Input
              TextField(
                controller: _emailController, // Controller bağlandı
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta Adresi', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 32),

              // Gönder Butonu
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword, // Yükleniyorsa tıklanamaz
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Bağlantı Gönder', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}