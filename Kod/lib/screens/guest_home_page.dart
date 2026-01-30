// lib/screens/guest_home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Çıkış işlemleri için
import 'login_page.dart'; // Giriş sayfasına dönmek için

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {

  // Misafir "Giriş Yap" butonuna basarsa:
  void _goToLogin() async {
    // Emin olmak için önce çıkış yapıyoruz
    await FirebaseAuth.instance.signOut();
    
    if (mounted) {
      // Login sayfasına yönlendir
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // Kilitli derse tıklanınca çıkan uyarı
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kilitli İçerik 🔒"),
        content: const Text("Bu dersin testlerini görmek ve ilerlemeni kaydetmek için ücretsiz üye olmalısın."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // İptal
            child: const Text("Daha Sonra"),
          ),
          ElevatedButton(
             onPressed: () {
               Navigator.pop(context); // Dialogu kapat
               _goToLogin(); // Giriş sayfasına yolla
             },
             child: const Text("Giriş Yap / Kayıt Ol"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 248, 255), // Misafire özel arka plan
      appBar: AppBar(
        title: Text(
          "Hoş Geldiniz", 
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Giriş Yap Butonu
          TextButton.icon(
            icon: const Icon(Icons.login),
            label: const Text("Giriş Yap"),
            onPressed: _goToLogin,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              // ============================================================
              // 🔥 5 SORULUK HIZLI DEMO ALANI (HERO) ⚡️
              // ============================================================
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF002984)], 
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.flash_on, size: 30, color: Colors.amber),
                        SizedBox(width: 8),
                        Text("Hızlı Demo", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Kaliteyi Keşfet!",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Sadece 5 özel soru ile DUS Asistanı'nın farkını gör. Kayıt gerekmez, hemen başla.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Buraya Quiz Ekranı Gelecek
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("5 Soruluk Demo Başlatılıyor... 🚀")));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber, 
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("5 Soruyu Çöz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              const Text("Dersler (Üyelere Özel)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 16),

              // ============================================================
              // 👇 KİLİTLİ DERS LİSTESİ 👇
              // ============================================================
              Expanded(
                child: ListView(
                  children: [
                    _buildLockedCard(context, "Anatomi", Icons.accessibility_new),
                    _buildLockedCard(context, "Fizyoloji", Icons.favorite_border),
                    _buildLockedCard(context, "Biyokimya", Icons.science),
                    _buildLockedCard(context, "Farmakoloji", Icons.medical_services),
                    _buildLockedCard(context, "Patoloji", Icons.coronavirus),
                    _buildLockedCard(context, "Mikrobiyoloji", Icons.bug_report),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sadece kilitli kart üreten fonksiyon
  Widget _buildLockedCard(BuildContext context, String title, IconData icon) {
    return Card(
      elevation: 0, 
      color: Colors.grey[200], 
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[400],
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        trailing: const Icon(Icons.lock, color: Colors.grey),
        onTap: _showLoginRequiredDialog, // Her tıklamada uyarı aç
      ),
    );
  }
}