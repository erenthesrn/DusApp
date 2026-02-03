// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; 
import 'login_page.dart';
import 'topic_selection_screen.dart'; // Ders seçimi için
import 'profile_screen.dart';
import 'quiz_screen.dart'; // Sınav ekranı
import 'mistakes_screen.dart';
import 'package:confetti/confetti.dart';

// =============================================================================
// ||                            ANA EKRAN (SKELETON)                         ||
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _targetBranch = "Doktor";
  int _selectedIndex = 0;
  int _dailyGoal = 60;
  int _currentMinutes = 0;
  int _totalSolved = 0;

  late ConfettiController _confettiController;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchTargetBranch();
  }

  @override
  void dispose(){
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchTargetBranch() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          int newMinutes = 0;
          int newDailyGoal = 60;

          if (data.containsKey('dailyGoalMinutes')){
            newDailyGoal = (data['dailyGoalMinutes'] as num).toInt();
          }
          // totalMinutes verisini çek
          if (data.containsKey('totalMinutes')) {
            newMinutes = (data['totalMinutes'] as num).toInt();
          }

          setState(() {
            if (data.containsKey('targetBranch')) {
              _targetBranch = "${data['targetBranch']} Uzmanlığı";
            }
            if (data.containsKey('totalSolved')) {
              _totalSolved = (data['totalSolved'] as num).toInt();
            }

            // 🔥 MANTIK: Eğer ilk yükleme değilse VE önceden hedef tamamlanmamışsa VE şimdi tamamlandıysa
            if (!_isFirstLoad && _currentMinutes < _dailyGoal && newMinutes >= newDailyGoal) {
              _confettiController.play(); // 🎉 PATLAT!
              _showCongratulationDialog(); // 💬 Mesaj göster
            }
            _currentMinutes = newMinutes;
            _dailyGoal = newDailyGoal;
            _isFirstLoad = false;
          });
        }
      } catch (e) {
        debugPrint("Veri çekme hatası: $e");
      }
    }
  }
    void _showCongratulationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text("Tebrikler! 👏"),
          ],
        ),
        content: const Text(
          "Günlük çalışma hedefine ulaştın!\nBu istikrarla devam et, DUS senin!",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Teşekkürler"),
          )
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0){
      _fetchTargetBranch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardView(
        titleName: _targetBranch,
        dailyGoal: _dailyGoal,
        currentMinutes: _currentMinutes,
        totalSolved: _totalSolved,
        onRefresh: _fetchTargetBranch,
      ),
      const Center(child: Text("İstatistikler (Yakında)")), // İleride buraya analiz ekranı gelecek
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      body: Stack(
        alignment: Alignment.topCenter, // Konfetiler yukarıdan aşağı aksın
        children: [
          // 1. En Alta Mevcut Sayfayı Koyuyoruz
          pages[_selectedIndex],

          // 2. En Üste Konfeti Aracını Koyuyoruz (Gizli durur, play() deyince çalışır)
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive, // Her yöne patlasın
            shouldLoop: false, // Tek seferlik patlasın
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ], 
            gravity: 0.2, // Süzülme hızı
            numberOfParticles: 20, // Parçacık sayısı
          ),
        ],
      ),

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
          selectedItemColor: const Color(0xFF0D47A1),
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
// ||                         ANA KOKPİT TASARIMI (DASHBOARD)                 ||
// =============================================================================

class DashboardView extends StatelessWidget {
  final String titleName;
  final int dailyGoal;
  final int currentMinutes;
  final int totalSolved;
  final VoidCallback onRefresh;

  DashboardView({
    super.key,
    required this.titleName,
    required this.dailyGoal,
    required this.currentMinutes,
    required this.totalSolved,
    required this.onRefresh,    
  });

  // 🔥 SORU HAVUZU
  final List<Map<String, String>> tumSorularHavuzu = [
    {"ders": "Anatomi", "soru": "Foramen rotundum'dan hangi sinir geçer?", "cevap": "N. Maxillaris"},
    {"ders": "Fizyoloji", "soru": "Kalp kasında 'gap junction' nerede bulunur?", "cevap": "İnterkalar disklerde"},
    {"ders": "Patoloji", "soru": "En sık görülen odontojenik kist hangisidir?", "cevap": "Radiküler Kist"},
    {"ders": "Farmakoloji", "soru": "Lokal anesteziklerin etki mekanizması nedir?", "cevap": "Na+ kanallarını blokajı"},
    {"ders": "Cerrahisi", "soru": "Mandibular anestezi komplikasyonları?", "cevap": "Trismus, Hematom"},
    {"ders": "Mikrobiyoloji", "soru": "Diş çürüğünün primer etkeni nedir?", "cevap": "Streptococcus Mutans"},
    {"ders": "Ortodonti", "soru": "Sefalometrik analizde SNA açısı neyi gösterir?", "cevap": "Maksillanın kafa kaidesine konumu"},
    {"ders": "Pedodonti", "soru": "Süt dişlerinde en sık görülen travma?", "cevap": "Lüksasyon yaralanmaları"},
    {"ders": "Periodontoloji", "soru": "Ataşman kaybı neyle ölçülür?", "cevap": "Sondalama derinliği + Diş eti çekilmesi"},
    {"ders": "Radyoloji", "soru": "Panoramik röntgende 'Hayalet Görüntü' nerede oluşur?", "cevap": "Gerçek görüntünün karşı tarafında ve yukarıda"},
  ];

  // 🔥 HER GÜN FARKLI SORU SEÇEN SİHİRLİ FONKSİYON
  Map<String, String> get gununSorusu {
    final now = DateTime.now();
    int seed = int.parse("${now.year}${now.month}${now.day}");
    final random = Random(seed);
    int randomIndex = random.nextInt(tumSorularHavuzu.length);
    return tumSorularHavuzu[randomIndex];
  }

  // --- 1. KONU SINAVI SEÇİMİ (NORMAL MOD) ---
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
                  Expanded(
                    child: _buildOptionButton(
                      context,
                      "Temel Bilimler",
                      Colors.orange,
                      ["Anatomi","Histoloji ve Embriyoloji" ,"Fizyoloji", "Biyokimya", "Mikrobiyoloji", "Patoloji", "Farmakoloji","Biyoloji ve Genetik"]
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOptionButton(
                      context,
                      "Klinik Bilimler",
                      Colors.blue,
                      ["Protetik Diş Tedavisi", "Restoratif Diş Tedavisi", "Endodonti", "Periodontoloji", "Ortodonti", "Pedodonti", "Ağız,Diş ve Çene Cerrahisi", "Ağız,Diş ve Çene Radyolojisi"]
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

  // 🔥 GÜNCELLENDİ: Artık Ders Seçme Ekranına Gidiyor
  Widget _buildOptionButton(BuildContext context, String title, Color color, List<String> topics) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Bottom sheet'i kapat
        
        // TopicSelectionScreen'e yönlendir
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => TopicSelectionScreen(
            title: title, 
            topics: topics, 
            themeColor: color
          ))
          ).then((_) => onRefresh() // 🔥 EKLENDİ
        );                
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

  // --- 2. DENEME SINAVI SEÇİMİ (SÜRELİ MOD) ---
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
                // Normal Deneme: Kullanıcıya süre sorulur
                onTap: () { 
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(isTrial: true)))
                    .then((_) => onRefresh());
                }
              ),
              const SizedBox(height: 16),
              
              _buildWideButton(
                context,
                title: "Klinik Bilimler Denemesi",
                subtitle: "Sadece klinik derslerden 60 soru",
                icon: Icons.healing,
                color: Colors.blue,
                // Normal Deneme: Kullanıcıya süre sorulur
                onTap: () { 
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(isTrial: true)));
                }
              ),
              const SizedBox(height: 16),
              
              // 🔥 GÜNCELLENDİ: Genel Deneme (Sabit 150 dk)
              _buildWideButton(
                context,
                title: "Genel Deneme (Tam Sınav)",
                subtitle: "Gerçek sınav formatı (150 dk)", // Bilgi güncellendi
                icon: Icons.timer,
                color: Colors.redAccent,
                onTap: () { 
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(
                    isTrial: true, 
                    fixedDuration: 150 // 🔥 SABİT SÜRE
                  )));
                }
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

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
    final soruVerisi = gununSorusu;
    final dusTarihi = DateTime(2026, 4, 26);
    final kalanGun = dusTarihi.difference(DateTime.now()).inDays;
    final primaryColor = Theme.of(context).primaryColor;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
// children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Merhaba, Doktor",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Hedef: $titleName",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1, // <-- Bunlar parantezin içinde olmalı
                    overflow: TextOverflow.ellipsis, // <-- Küçük harfle 'overflow'
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  Text(
                    "DUS'a $kalanGun Gün",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      // ],

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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text("Günün Sorusu: ${soruVerisi['ders']}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    soruVerisi['soru']!, 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Günün sorusu için şimdilik Normal Mod (isTrial: false) açıyoruz.
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => const QuizScreen(isTrial: false))
                        ).then((_) => onRefresh()
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text("Hemen Çöz", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- İSTATİSTİK KARTLARI ---
            Row(
              children: [
                Expanded(child: _buildStatCard(context, "Çözülen Soru", "$totalSolved", Icons.check_circle_outline, Colors.green)),
                const SizedBox(width: 16),
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
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 44, height: 44,
                              child: CircularProgressIndicator(
                                value: dailyGoal > 0 ? (currentMinutes / dailyGoal).clamp(0.0 , 1.0) : 0.0,
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
                            Text("$currentMinutes / $dailyGoal dk", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("Süre Hedefi", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text("Çalışma Modülleri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- MODÜLLER IZGARASI ---
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
                _buildMenuCard(context, "Yanlışlarım", "Eksikleri Kapat", Icons.refresh, Colors.teal, onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => MistakesDashboard()));
                }),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

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