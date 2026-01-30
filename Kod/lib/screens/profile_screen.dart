import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart'; // Çıkış yapınca login sayfasına dönmek için
import 'edit_profile_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 1. Verileri tutacak değişkenler
  String _name = "Yükleniyor...";
  String _email = "";
  String _role = "free"; // Varsayılan ücretsiz
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserData(); // Sayfa açılınca verileri çek
  }

  // 2. Firebase'den Veri Çekme Fonksiyonu
  Future<void> _getUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          // Veri varsa çek
          setState(() {
            Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
            _name = data['name'] ?? "İsimsiz";
            _email = data['email'] ?? currentUser.email!;
            _role = data['role'] ?? "free";
            _isLoading = false;
          });
        } else {
          // ⚠️ KRİTİK DÜZELTME: Veri yoksa (silinmişse) varsayılanı göster, dönüp durma!
          setState(() {
            _name = currentUser.displayName ?? "Kullanıcı"; // Auth'daki ismi kullan
            _email = currentUser.email ?? "";
            _role = "free";
            _isLoading = false; // Yüklemeyi bitir
          });
          
          // İsteğe bağlı: Veritabanını tekrar oluştur (Tamir et)
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
            'name': _name,
            'email': _email,
            'role': 'free',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        setState(() {
          _name = "Hata";
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _name = "Misafir Kullanıcı";
        _email = "Giriş yapılmadı";
        _isLoading = false;
      });
    }
  }
  // 3. Çıkış Yapma Fonksiyonu
  void _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Çıkış Yap"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      appBar: AppBar(
        title: const Text("Profilim", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 224, 247, 250),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Yüklenirken dönen çark
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- 1. KİMLİK KARTI (Artık Dinamik) ---
                  _buildProfileHeader(),

                  const SizedBox(height: 24),

                  // --- 2. İSTATİSTİK (SERİ) ---
                  _buildStreakCard(),

                  const SizedBox(height: 24),

                  // --- 3. AYARLAR MENÜSÜ ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Hesap Ayarları", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        // YERİNE BUNU YAPIŞTIR:
                        _buildMenuItem(
                          Icons.person_outline, 
                          "Kişisel Bilgilerim", 
                          "İsim ve Şifre işlemleri", 
                          () {
                            // Tıklanınca EditProfilePage sayfasına git
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                          }
                        ),
                        _buildDivider(),
                        _buildMenuItem(Icons.notifications_outlined, "Bildirimler", "Sınav hatırlatmaları", () {}),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- 4. DESTEK VE DİĞER ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Diğer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildMenuItem(Icons.bug_report_outlined, "Hata Bildir", "Sorun mu var?", () {}),
                        _buildDivider(),
                        _buildMenuItem(Icons.share, "Arkadaşını Davet Et", "Kazan & Kazandır", () {}),
                        _buildDivider(),
                        _buildMenuItem(Icons.star_outline, "Bizi Değerlendir", "Mağaza puanı ver", () {}),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // --- 5. ÇIKIŞ YAP BUTONU (Fonksiyon Bağlandı) ---
                  TextButton.icon(
                    onPressed: _signOut, // <-- Burayı bağladık
                    icon: Icon(Icons.logout, color: Colors.red[300], size: 20),
                    label: Text(
                      "Hesaptan Çıkış Yap", 
                      style: TextStyle(color: Colors.red[300], fontSize: 16, fontWeight: FontWeight.w600)
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.red[50],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text("Versiyon 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // --- WIDGET PARÇALARI ---

  Widget _buildProfileHeader() {
    // İsmin baş harflerini almak için basit bir mantık
    String initials = _name.isNotEmpty ? _name[0].toUpperCase() : "?";
    if (_name.contains(" ")) {
      var parts = _name.split(" ");
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials += parts[1][0].toUpperCase();
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          // Profil Resmi (İsim Baş Harfleri)
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 İsim Firebase'den geliyor
                Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                // 🔥 Email Firebase'den geliyor
                Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 13)), 
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Statik rozet (Örnek)
                    _buildBadge(Icons.school, "DUS", Colors.orange), 
                    const SizedBox(width: 8),
                    // 🔥 Dinamik Rozet: Eğer kullanıcı Premium ise göster, değilse "Free" göster
                    _role == 'premium' 
                        ? _buildBadge(Icons.workspace_premium, "Premium", Colors.purple)
                        : _buildBadge(Icons.person_outline, "Ücretsiz", Colors.blueGrey),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // ... Diğer Widgetlar (_buildStreakCard, _buildMenuItem, _buildDivider) AYNI KALDI ...
  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8008), Color(0xFFFFC837)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("🔥 Günlük Seri", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text("Çalışmaya devam et!", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.blueGrey),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[100], indent: 70);
  }
}