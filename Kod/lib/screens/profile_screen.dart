// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_provider.dart'; // --- TEMA İÇİN ŞART ---
import 'login_page.dart'; // Çıkış yapınca login sayfasına dönmek için
import 'edit_profile_page.dart';
import 'achievements_screen.dart'; // --- YENİ EKLENEN IMPORT ---

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
  int _streak = 0;
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
            _streak = data['streak'] ?? 0;
            _isLoading = false;
          });
        } else {
          // Veri yoksa varsayılanı göster
          setState(() {
            _name = currentUser.displayName ?? "Kullanıcı";
            _email = currentUser.email ?? "";
            _role = "free";
            _isLoading = false;
          });
          
          // Veritabanını onar
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
            'name': _name,
            'email': _email,
            'role': 'free',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _name = "Hata";
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _name = "Misafir Kullanıcı";
          _email = "Giriş yapılmadı";
          _isLoading = false;
        });
      }
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

  // 4. HATA BİLDİR FONKSİYONU
  void _showReportDialog() {
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red),
            SizedBox(width: 10),
            Text("Hata / Öneri Bildir"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Uygulamada karşılaştığınız bir hatayı veya önerinizi bizimle paylaşın."),
            const SizedBox(height: 15),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: "Örn: Profil resmim güncellenmiyor...",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            onPressed: () async {
              if (noteController.text.trim().isEmpty) return;

              Navigator.pop(context); // Dialogu kapat
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Geri bildiriminiz alındı! Teşekkürler.")),
              );

              // FIREBASE KAYIT İŞLEMİ
              try {
                User? user = FirebaseAuth.instance.currentUser;
                
                await FirebaseFirestore.instance.collection('app_reports').add({
                  'reportType': 'General / Profile',
                  'userNote': noteController.text.trim(),
                  'userId': user?.uid ?? "Anonim",
                  'userEmail': _email,
                  'userName': _name,
                  'reportedAt': FieldValue.serverTimestamp(),
                  'status': 'open',
                  'deviceInfo': 'Android/iOS'
                });
              } catch (e) {
                debugPrint("Rapor gönderilemedi: $e");
              }
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }

  // --- 5. HEDEF MENÜSÜ GÖSTERİMİ ---
  void _showTargetOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Hedef Ayarları 🎯", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // 1. Seçenek: Günlük Süre
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.timer, color: Colors.orange),
                ),
                title: const Text("Günlük Çalışma Süresi"),
                subtitle: const Text("Dakika hedefini belirle"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context); // Menüyü kapat
                  _changeDailyGoal(); // Süre dialogunu aç
                },
              ),
              
              const Divider(),

              // 2. Seçenek: Günlük Soru Hedefi (YENİ EKLENDİ)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.quiz, color: Colors.purple),
                ),
                title: const Text("Günlük Soru Hedefi"),
                subtitle: const Text("Çözülecek soru sayısını belirle"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context); // Menüyü kapat
                  _changeDailyQuestionGoal(); // Soru dialogunu aç
                },
              ),

              const Divider(),

              // 3. Seçenek: Uzmanlık Alanı
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.school, color: Colors.blue),
                ),
                title: const Text("Uzmanlık Hedefi"),
                subtitle: const Text("Bölüm tercihini değiştir"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context); // Menüyü kapat
                  _changeTargetBranch(); // Mevcut branş seçimini aç
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  } 

  // --- 6. GÜNLÜK SÜRE GİRME FONKSİYONU ---
  void _changeDailyGoal() {
    TextEditingController goalController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Günlük Hedef ⏱️"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Günde kaç dakika çalışmayı hedefliyorsun?"),
            const SizedBox(height: 15),
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Dakika",
                hintText: "Örn: 120",
                suffixText: "dk",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("İptal")
          ),
          ElevatedButton(
            onPressed: () async {
              if (goalController.text.isNotEmpty) {
                int? minutes = int.tryParse(goalController.text);
                
                if (minutes != null && minutes > 0) {
                  // Firebase'e kaydet
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                      'dailyGoalMinutes': minutes
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Günlük hedef $minutes dk olarak güncellendi! 🔥"))
                      );
                    }
                  }
                }
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }
  // --- 6.5. GÜNLÜK SORU HEDEFİ GİRME FONKSİYONU (YENİ) ---
  void _changeDailyQuestionGoal() {
    TextEditingController questionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Soru Hedefi 📝"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Günde kaç soru çözmeyi hedefliyorsun?"),
            const SizedBox(height: 15),
            TextField(
              controller: questionController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Soru Sayısı",
                hintText: "Örn: 50",
                suffixText: "adet",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("İptal")
          ),
          ElevatedButton(
            onPressed: () async {
              if (questionController.text.isNotEmpty) {
                int? questions = int.tryParse(questionController.text);
                
                if (questions != null && questions > 0) {
                  // Firebase'e kaydet
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                      'dailyQuestionGoal': questions
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Günlük hedef $questions soru olarak güncellendi! 🚀"))
                      );
                    }
                  }
                }
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // --- 7. UZMANLIK ALANI DEĞİŞTİRME FONKSİYONU ---
  void _changeTargetBranch() {
    final List<String> branches = [
      "Cerrahi", "Radyoloji", "Pedodonti", 
      "Periodontoloji", "Protez", 
      "Endodonti", "Restoratif",
      "Ortodonti"
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) { 
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Hedeflediğin Uzmanlık Alanını Seç", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: branches.length,
                  itemBuilder: (itemContext, index) {
                    return ListTile(
                      title: Text(branches[index]),
                      leading: const Icon(Icons.star_border, color: Colors.blue),
                      onTap: () async {
                        Navigator.pop(sheetContext); 

                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({'targetBranch': branches[index]});
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Hedef başarıyla güncellendi!"))
                            );
                            _getUserData(); // Ekrandaki veriyi tazele
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
 // --- 8. İSTATİSTİK AYARLARI MENÜSÜ ---
  void _showStatisticsOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // Anlık durumu görmek için StreamBuilder kullanıyoruz
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            bool isVisible = data?['showSuccessRate'] ?? true; 

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("İstatistik Ayarları 📊", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 1. Switch: Görünürlük
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: const Text("Başarı Oranını Göster", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(isVisible ? "Ana ekranda açık" : "Ana ekranda gizli", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: isVisible,
                      activeColor: Colors.green,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.visibility, color: Colors.green),
                      ),
                      onChanged: (val) => _toggleSuccessRateVisibility(isVisible),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Buton: Sıfırlama
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.cleaning_services_rounded, color: Colors.red),
                    ),
                    title: const Text("İstatistikleri Sıfırla", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                    subtitle: const Text("Tüm soru geçmişini temizler"),
                    onTap: () {
                      Navigator.pop(context); // Menüyü kapat
                      _resetStatistics(context); // Sıfırlama dialogunu aç
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }
        );
      },
    );
  }

// Yardımcı Fonksiyon: Görünürlük Değiştir
  void _toggleSuccessRateVisibility(bool currentValue) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'showSuccessRate': !currentValue,
      });
    }
  }

  // Yardımcı Fonksiyon: İstatistik Sıfırla
  void _resetStatistics(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emin misin?"),
        content: const Text("Tüm çözülen soru sayıları ve başarı oranların sıfırlanacak. Bu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Sıfırla", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'totalSolved': 0,
          'totalCorrect': 0,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İstatistikler sıfırlandı! Tertemiz bir sayfa. 🚀"))
        );
      }
    }
  }  


  @override
  Widget build(BuildContext context) {
    // Tema verilerini anlık dinlemek için
    final themeProvider = ThemeProvider.instance;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Profilim", style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- 1. KİMLİK KARTI ---
                  _buildProfileHeader(),

                  const SizedBox(height: 24),

                  // --- 2. İSTATİSTİK ---
                  _buildStreakCard(),

                  const SizedBox(height: 24),

                  // --- 3. AYARLAR MENÜSÜ ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Hesap Ayarları", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, 
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Column(
                      children: [
                        // --- 🔥 KARANLIK MOD ŞALTERİ BURAYA EKLENDİ ---
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(
                              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode, 
                              color: Colors.blue
                            ),
                          ),
                          title: const Text("Karanlık Mod", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(themeProvider.isDarkMode ? "Açık" : "Kapalı"),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              setState(() {
                                themeProvider.toggleTheme(value);
                              });
                            },
                            activeColor: const Color(0xFF0D47A1),
                          ),
                        ),
                        _buildDivider(),
                        // ---------------------------------------------

                        _buildMenuItem(
                          Icons.person_outline, 
                          "Kişisel Bilgilerim", 
                          "İsim ve Şifre işlemleri", 
                          () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                          }
                        ),
                        _buildDivider(),
                        
                        _buildMenuItem(
                          Icons.emoji_events_rounded, 
                          "Rozetlerim & Başarılar", 
                          "Kupa dolabına göz at", 
                          () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AchievementsScreen()));
                          }
                        ),
                        _buildDivider(),

                        // 🔥 YENİ EKLENEN BUTON BURADA 🔥
                        _buildMenuItem(
                          Icons.analytics_outlined, // Grafik ikonu
                          "İstatistik Ayarları",
                          "Başarı oranı ve sıfırlama",
                          _showStatisticsOptions // Tıklayınca yukarıdaki fonksiyonu açacak
                        ),
                        _buildDivider(),
                        // ---------------------------------

                        _buildMenuItem(
                          Icons.ads_click,
                          "Hedeflerim",
                          "Süre Hedefi ve Uzmanlık hedefini değiştir.",
                          _showTargetOptions 
                        ),
                        _buildDivider(),
                        _buildMenuItem(Icons.notifications_outlined, "Bildirimler", "Sınav hatırlatmaları", () {}),

                        _buildDivider(),

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
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, 
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(Icons.bug_report_outlined, "Hata Bildir", "Sorun mu var?", _showReportDialog),
                        _buildDivider(),
                        _buildMenuItem(Icons.share, "Arkadaşını Davet Et", "Kazan & Kazandır", () {}),
                        _buildDivider(),
                        _buildMenuItem(Icons.star_outline, "Bizi Değerlendir", "Mağaza puanı ver", () {}),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // --- 5. ÇIKIŞ YAP ---
                  TextButton.icon(
                    onPressed: _signOut,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
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
                Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 13)), 
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildBadge(Icons.school, "DUS", Colors.orange), 
                    const SizedBox(width: 8),
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

  Widget _buildStreakCard() {
    bool isActive = _streak > 0;

    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive 
                  ? [const Color(0xFFFF8008), const Color(0xFFFFC837)] 
                  : [Colors.grey.shade400, Colors.grey.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive 
                ? [BoxShadow(color: const Color(0xFFFF8008).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? "🔥 Günlük Seri" : "💤 Seri Başlamadı",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive 
                      ? "Harikasın, böyle devam et!" 
                      : "Bugün bir test çöz ve ateşi yak!",
                    style: const TextStyle(color: Colors.white, fontSize: 12)
                  ),
                ],
              ),
              
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), 
              shape: BoxShape.circle
            ),
            child: Text(
              "$_streak", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withOpacity(0.1), indent: 70);
  }
}

