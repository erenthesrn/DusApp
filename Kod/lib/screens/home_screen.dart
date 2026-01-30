// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Veri çekmek için lazım
import 'package:cloud_firestore/cloud_firestore.dart'; // Veri çekmek için lazım
import 'login_page.dart'; 
import 'topic_selection_screen.dart'; 
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _targetBranch = "Doktor"; // Varsayılan hitap
  int _selectedIndex = 0;
  int _dailyGoal = 60; // Varsayılan hedef (dk)
  int _currentMinutes = 0; // Şu anlık 0 (İleride kronometreden gelecek)

  @override
  void initState() {
    super.initState();
    _fetchTargetBranch(); // Sayfa açılınca hedefi çek
  }

  // 🔥 Kullanıcının hedef branşını çeken fonksiyon
  Future<void> _fetchTargetBranch() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('targetBranch')) {
            setState(() {
              // 1. Hedef Branş
              if (data.containsKey('targetBranch')) {
                _targetBranch = "Geleceğin ${data['targetBranch']} Uzmanı";
              }
              // 2. Günlük Hedef (Dakika) - EKLENEN KISIM
              if (data.containsKey('dailyGoalMinutes')) {
                _dailyGoal = data['dailyGoalMinutes'];
              }            });
          }
        }
      } catch (e) {
        debugPrint("Veri çekme hatası: $e");
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sayfalar Listesi
    // Sayfalar Listesi
    final List<Widget> pages = [
      DashboardView(
        titleName: _targetBranch, 
        dailyGoal: _dailyGoal, 
        currentMinutes: _currentMinutes
      ),
      const Center(child: Text("İstatistikler (Yakında)")),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250), 
      body: pages[_selectedIndex],
      
      // ALT MENÜ
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Kokpit'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analiz'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF0D47A1), // Ana tema rengimiz
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: false,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}

// =============================================================================
// ||                         ANA KOKPİT TASARIMI                             ||
// =============================================================================

class DashboardView extends StatelessWidget {
  final String titleName;
  final int dailyGoal;      // EKLENDİ
  final int currentMinutes; // EKLENDİ

  const DashboardView({
    super.key, 
    required this.titleName,
    required this.dailyGoal,
    required this.currentMinutes,
  });

  // --- 1. KONU SEÇİM EKRANINI AÇAN FONKSİYON ---
  void _showSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return Container(
          height: 250,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Hangi alandan soru çözeceksin?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  // TEMEL BİLİMLER BUTONU
                  Expanded(
                    child: _buildOptionButton(
                      context, 
                      "Temel Bilimler", 
                      Colors.orange, 
                      ["💀Anatomi","🧬Histoloji ve Embriyoloji" ,"🫀Fizyoloji", "🧪Biyokimya", "🦠Mikrobiyoloji", "🔬Patoloji", "💊Farmakoloji","🧬Biyoloji ve Genetik"]
                    ),
                  ),
                  const SizedBox(width: 16),
                  // KLİNİK BİLİMLER BUTONU
                  Expanded(
                    child: _buildOptionButton(
                      context, 
                      "Klinik Bilimler", 
                      Colors.blue, 
                      ["🦷Protetik Diş Tedavisi", "✨Restoratif Diş Tedavisi", "⚡️Endodonti", "🩸Periodontoloji", "📏Ortodonti", "👶Pedodonti", "😷Ağız,Diş ve Çene Cerrahisi", "💀Ağız,Diş ve Çene Radyolojisi"]
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // BottomSheet içindeki buton tasarımı
  Widget _buildOptionButton(BuildContext context, String title, Color color, List<String> topics) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); 
        Navigator.push(context, MaterialPageRoute(builder: (context) => TopicSelectionScreen(
          title: title,
          topics: topics,
          themeColor: color,
        )));
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- 2. DENEME SEÇİM EKRANINI AÇAN FONKSİYON ---
  void _showDenemeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text("Deneme Türünü Seç", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              _buildWideButton(
                context, 
                title: "Temel Bilimler Denemesi", 
                subtitle: "Sadece temel derslerden 60 soru",
                icon: Icons.science, 
                color: Colors.orange,
                onTap: () { Navigator.pop(context); }
              ),
              const SizedBox(height: 16),
              _buildWideButton(
                context, 
                title: "Klinik Bilimler Denemesi", 
                subtitle: "Sadece klinik derslerden 60 soru",
                icon: Icons.healing, 
                color: Colors.blue,
                onTap: () { Navigator.pop(context); }
              ),
              const SizedBox(height: 16),
              _buildWideButton(
                context, 
                title: "Genel Deneme (Tam Sınav)", 
                subtitle: "Gerçek sınav formatı (120 Soru)",
                icon: Icons.timer, 
                color: Colors.redAccent,
                onTap: () { Navigator.pop(context); }
              ),
              
              const SizedBox(height: 20), 
            ],
          ),
        );
      },
    );
  }

  // Deneme seçim ekranındaki geniş butonlar
  Widget _buildWideButton(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 DİNAMİK BAŞLIK: Geleceğin X Uzmanı
                    Text("Merhaba, $titleName 👋", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text("Bugün Hazır mısın?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                // DUS Sayacı Chip'i
                Container(
                  width: 120, 
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD), 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF1565C0)),
                        const SizedBox(width: 4),
                        const Text(
                          "DUS'a 86 Gün",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),

            const SizedBox(height: 24),

            // --- GÜNÜN SORUSU KARTI ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: const Text("🔥 Günün Sorusu", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  const Text("Mandibular anestezi komplikasyonları nelerdir?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Hemen Çöz"),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- İSTATİSTİK KARTLARI (Şeffaflık Korundu) ---
            Row(
              children: [
                Expanded(child: _buildStatCard(context, "Çözülen", "124", Icons.check_circle_outline, Colors.green)),
                const SizedBox(width: 16),
// 🔥 ÖZEL HEDEF KARTI (PROGRESS BARLI)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        // Yuvarlak İlerleme Çubuğu
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 44, height: 44,
                              child: CircularProgressIndicator(
                                value: dailyGoal > 0 ? (currentMinutes / dailyGoal) : 0.0, // Doluluk oranı
                                backgroundColor: Colors.orange.withOpacity(0.2),
                                color: Colors.orange,
                                strokeWidth: 4,
                              ),
                            ),
                            const Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dinamik Hedef Dakikası
                            Text("$dailyGoal dk", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("Günlük Hedef", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        )
                      ],
                    ),
                  ),
                ),              ],
            ),

            const SizedBox(height: 24),
            const Text("Çalışma Modülleri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- MODÜLLER IZGARASI (Şeffaflık Korundu) ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildMenuCard(context, "Konu Sınavları", "Temel & Klinik", Icons.library_books, Colors.purple, onTap: () {
                   _showSelectionSheet(context); 
                }),
                _buildMenuCard(context, "Denemeler", "Tam Format", Icons.timer, Colors.redAccent, onTap: () {_showDenemeSheet(context); }),
                _buildMenuCard(context, "Spot Bilgiler", "Hızlı Tekrar", Icons.flash_on, Colors.amber[700]!, onTap: () {}),
                _buildMenuCard(context, "Yanlışlarım", "Eksikleri Kapat", Icons.refresh, Colors.teal, onTap: () {}),
              ],
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---
  
  // 🔥 İstatistik Kartı: Buzlu Cam Etkisi
  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          )
        ],
      ),
    );
  }

  // 🔥 Menü Kartı: Buzlu Cam Etkisi
  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent, 
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}