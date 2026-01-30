// lib/screens/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Controllerlar
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Göz işaretlerinin durumu
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? "";
      _nameController.text = user.displayName ?? "";
      
      if (user.displayName == null || user.displayName!.isEmpty) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
          if (doc.exists && mounted) {
            setState(() {
               _nameController.text = doc['name'];
            });
          }
        });
      }
    }
  }

  // --- YARDIMCI FONKSİYON: ŞİFRE GÜÇLÜ MÜ? ---
  bool _isPasswordStrong(String password) {
    // 1. En az 1 Büyük Harf var mı?
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    // 2. En az 1 Rakam var mı?
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    // 3. Uzunluğu en az 8 mı?
    bool hasMinLength = password.length >= 8;

    return hasUppercase && hasDigits && hasMinLength;
  }

  Future<void> _updateName() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': _nameController.text,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İsim güncellendi! ✅")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    // 1. Boş Alan Kontrolü
    if (_currentPasswordController.text.isEmpty || 
        _newPasswordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm şifre alanlarını doldurun.")));
      return;
    }

    // 2. Şifre Eşleşme Kontrolü
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yeni şifreler birbiriyle uyuşmuyor! ❌"), backgroundColor: Colors.red)
      );
      return;
    }

    // 3. 🔥 GÜÇLÜ ŞİFRE KONTROLÜ (SENİN İSTEDİĞİN ÖZELLİK)
    if (!_isPasswordStrong(_newPasswordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Şifre Yetersiz: En az 1 BÜYÜK HARF ve 1 RAKAM içermelidir! ⚠️"), 
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        )
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String email = user?.email ?? "";

      AuthCredential credential = EmailAuthProvider.credential(
        email: email, 
        password: _currentPasswordController.text
      );

      await user?.reauthenticateWithCredential(credential);
      await user?.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifreniz başarıyla değiştirildi! 🔒")));
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Bir hata oluştu.";
      if (e.code == 'wrong-password') errorMessage = "Mevcut şifrenizi yanlış girdiniz.";
      if (e.code == 'weak-password') errorMessage = "Şifre çok zayıf.";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 GÜÇLENDİRİLMİŞ HESAP SİLME (Şifre İsteyerek)
  Future<void> _deleteAccount() async {
    // Önce kullanıcıdan şifresini isteyelim (Re-Auth için)
    TextEditingController passwordController = TextEditingController();
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hesabı Sil ⚠️"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Bu işlem geri alınamaz. Güvenliğiniz için lütfen şifrenizi girin:"),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Şifre",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Onayla ve Sil"),
          ),
        ],
      ),
    );

    if (confirm == true && passwordController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        User? user = FirebaseAuth.instance.currentUser;
        String email = user?.email ?? "";

        // 1. Önce kimlik doğrula (Bu sayede 'Çıkış yap tekrar dene' hatası almazsın)
        AuthCredential credential = EmailAuthProvider.credential(
          email: email, 
          password: passwordController.text
        );
        await user?.reauthenticateWithCredential(credential);

        // 2. Veritabanını temizle
        await FirebaseFirestore.instance.collection('users').doc(user?.uid).delete();
        
        // 3. Hesabı kökten sil
        await user?.delete();

        if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const LoginPage()),
             (route) => false,
           );
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hesabınız kalıcı olarak silindi. Hoşçakalın! 👋")));
        }
      } on FirebaseAuthException catch (e) {
        String err = "Bir hata oluştu.";
        if (e.code == 'wrong-password') err = "Şifreyi yanlış girdiniz.";
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      
      appBar: AppBar(
        title: const Text("Bilgilerimi Düzenle", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Arka planla bütünleşsin
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              const Text("Profil Bilgileri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color.fromARGB(255, 224, 247, 250), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "E-posta Adresi",
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFEEEEEE),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Ad Soyad",
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateName,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text("İsmi Güncelle"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              const Text("Güvenlik", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color.fromARGB(255, 224, 247, 250), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    // MEVCUT ŞİFRE
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        labelText: "Mevcut Şifre",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() => _obscureCurrent = !_obscureCurrent);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // YENİ ŞİFRE
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: "Yeni Şifre",
                        hintText: "En az 1 büyük harf ve rakam", // İpucu
                        prefixIcon: const Icon(Icons.vpn_key),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() => _obscureNew = !_obscureNew);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // YENİ ŞİFRE TEKRAR
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: "Yeni Şifre (Tekrar)",
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text("Şifreyi Değiştir"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: TextButton.icon(
                  onPressed: _deleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text("Hesabımı Kalıcı Olarak Sil", style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
    );
  }
}