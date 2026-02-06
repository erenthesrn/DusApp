// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';

// --- IMPORTLAR ---
import '../services/mistakes_service.dart';
import '../models/question_model.dart';
import 'topic_selection_screen.dart'; 
import 'profile_screen.dart';
import 'quiz_screen.dart'; 
import 'mistakes_screen.dart';
import 'blog_screen.dart';
// 🔥 YENİ: Odak Modu Sayfasını Import Et
import 'focus_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  // --- VERİ DEĞİŞKENLERİ ---
  String _targetBranch = "Hedef Seçiliyor...";
  int _dailyGoal = 60;
  int _currentMinutes = 0;
  int _totalSolved = 0;
  int _totalCorrect = 0; 
  // bool _isLoading = true; 

  late ConfettiController _confettiController;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _listenToUserData(); 
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); 
    _confettiController.dispose();
    super.dispose();
  }

  // --- FIREBASE VERİ CANLI TAKİP (STREAM) ---
  void _listenToUserData() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        
        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          
          if (mounted) {
            setState(() {
              if (data.containsKey('targetBranch')) _targetBranch = data['targetBranch'];
              if (data.containsKey('dailyGoalMinutes')) _dailyGoal = (data['dailyGoalMinutes'] as num).toInt();
              if (data.containsKey('totalMinutes')) _currentMinutes = (data['totalMinutes'] as num).toInt();
              if (data.containsKey('totalSolved')) _totalSolved = (data['totalSolved'] as num).toInt();
              if (data.containsKey('totalCorrect')) {
                _totalCorrect = (data['totalCorrect'] as num).toInt();
              } else {
                _totalCorrect = 0; 
              }
            });
          }
        }
      }, onError: (e) {
        debugPrint("Veri dinleme hatası: $e");
      });
    }
  }

  // --- YARDIMCI: MISTAKE MAP -> QUESTION OBJECT DÖNÜŞÜMÜ ---
  List<Question> _convertMistakesToQuestions(List<Map<String, dynamic>> mistakes) {
    return mistakes.map((m) {
      return Question(
        id: m['id'],
        question: m['question'],
        options: List<String>.from(m['options']),
        answerIndex: m['correctIndex'],
        explanation: m['explanation'] ?? "",
        testNo: 0, 
        // 🔥 ÖNEMLİ DEĞİŞİKLİK: 'level' alanına dersin orijinal adını koyuyoruz.
        // Böylece Quiz ekranında hangi dersi sileceğimizi bileceğiz.
        level: m['subject'] ?? "Genel", 
      );
    }).toList();
  }

  // --- 1. MODÜL: PRATİK (KONU SEÇİMİ) ---
  void _showTopicSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, 
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))
                ),
              ),
              
              Text("Çalışma Alanı", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text("Hangi alanda pratik yapmak istersin?", style: GoogleFonts.inter(fontSize: 14, color: Colors.blueGrey.shade400)),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      context, 
                      title: "Temel\nBilimler", 
                      icon: Icons.biotech_outlined, 
                      color: Colors.orange, 
                      topics: ["Anatomi","Histoloji ve Embriyoloji" ,"Fizyoloji", "Biyokimya", "Mikrobiyoloji", "Patoloji", "Farmakoloji","Biyoloji ve Genetik"]
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      context, 
                      title: "Klinik\nBilimler", 
                      icon: Icons.health_and_safety_outlined, 
                      color: Colors.blue, 
                      topics: ["Protetik Diş Tedavisi", "Restoratif Diş Tedavisi", "Endodonti", "Periodontoloji", "Ortodonti", "Pedodonti", "Ağız, Diş ve Çene Cerrahisi", "Ağız, Diş ve Çene Radyolojisi"]
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              _buildModernCard(
                context,
                title: "Sınav Provası",
                subtitle: "Tüm derslerden karışık deneme",
                icon: Icons.timer_outlined,
                color: const Color(0xFF673AB7),
                isWide: true,
                onTapOverride: () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(isTrial: true, fixedDuration: 150)));
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. MODÜL: YANLIŞLAR MENÜSÜ (MODERN TASARIM) ---
  void _showMistakesMenu(BuildContext context) async {
    List<Map<String, dynamic>> mistakes = await MistakesService.getMistakes();
    int count = mistakes.length;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gri Çizgi (Handle)
              Center(
                child: Container(
                  width: 40, height: 4, 
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))
                ),
              ),
              
              // Başlıklar
              Text("Yanlış Yönetimi", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text("Toplam $count yanlışın var. Nasıl ilerleyelim?", style: GoogleFonts.inter(fontSize: 14, color: Colors.blueGrey.shade400)),
              const SizedBox(height: 32),
              
              // --- KARTLAR ---
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      context, 
                      title: "Karışık\nTekrar", 
                      icon: Icons.shuffle_rounded, 
                      color: Colors.purple, 
                      subtitle: "Rastgele Sınav",
                      onTapOverride: () {
                        Navigator.pop(context);
                        if (mistakes.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Henüz yanlışın yok! Harikasın 🎉")));
                          return;
                        }
                        List<Map<String, dynamic>> shuffled = List.from(mistakes)..shuffle();
                        List<Question> questions = _convertMistakesToQuestions(shuffled);
                        
                        Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(
                          isTrial: true, 
                          questions: questions,
                          topic: "Karışık Yanlış Tekrarı",
                        )));
                      }
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: _buildModernCard(
                      context, 
                      title: "Konu\nBazlı", 
                      icon: Icons.filter_list_rounded, 
                      color: Colors.teal, 
                      subtitle: "Ders Seç",
                      onTapOverride: () {
                        Navigator.pop(context);
                        if (mistakes.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Henüz yanlışın yok!")));
                          return;
                        }
                        _showSubjectSelectionList(context, mistakes);
                      }
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              _buildModernCard(
                context,
                title: "Listeyi İncele",
                subtitle: "Hatalarını tek tek gör ve analiz et",
                icon: Icons.dashboard_customize_outlined,
                color: const Color.fromARGB(255, 205, 16, 35), // Kırmızı Ton
                isWide: true,
                onTapOverride: () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const MistakesDashboard()));
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DERS SEÇİM LİSTESİ ---
  void _showSubjectSelectionList(BuildContext context, List<Map<String, dynamic>> mistakes) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var m in mistakes) {
      String sub = m['subject'] ?? "Diğer";
      if (!grouped.containsKey(sub)) grouped[sub] = [];
      grouped[sub]!.add(m);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7, 
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hangi Dersi Tekrar Edeceksin?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: grouped.keys.length,
                    separatorBuilder: (c, i) => const Divider(),
                    itemBuilder: (context, index) {
                      String subject = grouped.keys.elementAt(index);
                      int count = grouped[subject]!.length;
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.book, color: Colors.teal)),
                        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                          child: Text("$count Yanlış", style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold))
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          List<Question> questions = _convertMistakesToQuestions(grouped[subject]!);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(
                            isTrial: true,
                            questions: questions,
                            topic: "$subject Tekrarı",
                          )));
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  // --- ORTAK WIDGET: MODERN KART ---
  Widget _buildModernCard(BuildContext context, {
    required String title, 
    required IconData icon, 
    required Color color, 
    List<String>? topics,
    String? subtitle,
    bool isWide = false,
    VoidCallback? onTapOverride
  }) {
    return Container(
      height: isWide ? 100 : 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        // 🔥 PERFORMANS: Blur 20 -> 8
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
        ]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          onTap: onTapOverride ?? () {
            Navigator.pop(context);
            if (topics != null) {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => TopicSelectionScreen(title: title.replaceAll('\n', ' '), topics: topics, themeColor: color))
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isWide 
            ? Row( 
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                      if (subtitle != null)
                        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey)),
                    ],
                  )
                ],
              )
            : Column( 
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), height: 1.2)),
                      if (subtitle != null)
                        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> currentPages = [
      DashboardScreen(
        targetBranch: _targetBranch,
        dailyGoal: _dailyGoal,
        currentMinutes: _currentMinutes,
        totalSolved: _totalSolved,
        totalCorrect: _totalCorrect,
        onRefresh: () {}, 
        onMistakesTap: () => _showMistakesMenu(context),
        onPratikTap: () => _showTopicSelection(context), 
      ),
      const BlogScreen(),
      const Scaffold(body: Center(child: Text("Analiz Ekranı Hazırlanıyor..."))),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: currentPages,
          ),
          // 🔥 PERFORMANS: Confetti ayrı çizim katmanına alındı.
          IgnorePointer(
            child: RepaintBoundary(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          // 🔥 PERFORMANS: Blur 40 -> 15
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15, 
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: NavigationBar(
            height: 80,
            backgroundColor: Colors.white,
            elevation: 0,
            indicatorColor: Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            destinations: [
              _buildNavDest(Icons.home_outlined, Icons.home, 0),
              _buildNavDest(Icons.book_outlined, Icons.book, 1),
              _buildNavDest(Icons.bar_chart_outlined, Icons.bar_chart, 2),
              _buildNavDest(Icons.person_outline, Icons.person, 3),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavDest(IconData icon, IconData activeIcon, int idx) {
    return NavigationDestination(
      icon: Icon(icon, color: Colors.blueGrey.shade400, size: 28),
      selectedIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(activeIcon, color: const Color(0xFF0D9488), size: 28),
          const SizedBox(height: 4),
          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle)),
        ],
      ),
      label: '',
    );
  }
}

// =============================================================================
// ||                          DASHBOARD EKRANI                               ||
// =============================================================================

class DashboardScreen extends StatelessWidget {
  final String targetBranch;
  final int dailyGoal;
  final int currentMinutes;
  final int totalSolved;
  final int totalCorrect;
  final VoidCallback onRefresh;
  final VoidCallback? onMistakesTap; 
  final VoidCallback? onPratikTap;

  const DashboardScreen({
    super.key,
    required this.targetBranch,
    required this.dailyGoal,
    required this.currentMinutes,
    required this.totalSolved,
    required this.totalCorrect,
    required this.onRefresh,
    this.onMistakesTap,
    this.onPratikTap,
  });

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Günaydın';
    if (hour >= 12 && hour < 17) return 'İyi Günler';
    if (hour >= 17 && hour < 23) return 'İyi Akşamlar';
    return 'İyi Geceler';
  }

  String _calculateSuccessRate() {
    if (totalSolved == 0) return '%0';
    double rate = (totalCorrect.toDouble() / totalSolved.toDouble()) * 100;
    return '%${rate.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // --- HEADER KISMI (DÜZELTİLDİ: SafeArea + Expanded) ---
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1), 
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            // 🔥 SAFE AREA: Çentik ve durum çubuğunu korur
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 80), // Üst boşluk optimize edildi
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 EXPANDED: Yazı taşmasını önler
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_getGreeting()}, Doktor', 
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                              
                              const SizedBox(height: 4),
                              
                              Text(
                                'Hedef: $targetBranch Uzmanlığı', 
                                maxLines: 2, // Gerekirse 2 satıra iner
                                overflow: TextOverflow.ellipsis, // Sığmazsa ... koyar
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold) 
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16), // Boşluk
                        // Bildirim Butonu
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.notifications_none, color: Colors.white),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        _buildMiniStat(Icons.check_circle_outline, '$totalSolved', 'Çözülen Soru', Colors.orange.shade400),
                        const SizedBox(width: 16),
                        _buildMiniStat(Icons.track_changes, _calculateSuccessRate(), 'Başarı Oranı', Colors.green.shade400),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- HEDEF KARTLARI ---
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  // 🔥 PERFORMANS: Blur 30 -> 10
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Bugünkü Hedefler", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                        TextButton(
                          onPressed: onRefresh, 
                          child: const Text("Yenile", style: TextStyle(color: Colors.orange)),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGoalCircle(
                            '$totalSolved', 
                            '100 Soru', 
                            Colors.teal,
                            (totalSolved / 100).clamp(0.0, 1.0) 
                          )
                        ),
                        Container(width: 1, height: 60, color: Colors.blueGrey.shade100),
                        Expanded(
                          child: _buildGoalCircle(
                            '$currentMinutes', 
                            '$dailyGoal Dakika', 
                            Colors.orange,
                            dailyGoal > 0 ? (currentMinutes / dailyGoal).clamp(0.0, 1.0) : 0.0 
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- GRID BUTONLAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ekran genişliğine göre 4. butonu da sığdırmak için
                // Mevcut yapıda 3 buton sığıyordu, 4 buton için genişliği bölelim
                // Ancak tasarımın bozulmaması için 2 satır (2+2) veya kaydırmalı yapabiliriz.
                // Senin tasarımına sadık kalarak, aşağıya "Odak Modu"nu büyük ekliyorum veya araya sıkıştırıyorum.
                // En temizi: Pratik ve Bilgi Kartları üstte, Yanlışlar ve Odak Modu altta olsun.
                
                double itemWidth = (constraints.maxWidth - 32) / 2 - 8; // 2'li grid
                
                return Column(
                  children: [
                    // 1. SATIR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionBtn('Pratik', 'Soru Çöz', Icons.play_arrow, const Color(0xFF0D47A1), itemWidth,
                          onTap: () {
                             if (onPratikTap != null) onPratikTap!();
                          }),
                        
                        _buildActionBtn('Bilgi Kartları', 'Hızlı Tekrar', Icons.emoji_events, const Color.fromARGB(255, 0, 150, 136), itemWidth,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Bilgi Kartları modülü hazırlanıyor..."))
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 2. SATIR (YENİ EKLENEN KISIM)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionBtn('Yanlışlar', 'Hatalarını Gör', Icons.refresh, const Color.fromARGB(255, 205, 16, 35), itemWidth,
                          onTap: () {
                            if (onMistakesTap != null) {
                              onMistakesTap!();
                            } else {
                               Navigator.push(context, MaterialPageRoute(builder: (context) => const MistakesDashboard()));
                            }
                          }),
                          
                        // 🔥 ODAK MODU BUTONU (BURAYA EKLENDİ)
                        _buildActionBtn('Odak Modu', 'Derin Çalışma', Icons.track_changes, Colors.deepPurple, itemWidth,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const FocusScreen()));
                          }),
                      ],
                    ),
                  ],
                );
              }
            ),
          ),
          
          const SizedBox(height: 32),
          // --- ALT İSTATİSTİK BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Genel İlerleme', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$totalSolved / 4764', style: GoogleFonts.inter(color: Colors.blueGrey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalSolved / 4764, 
                  backgroundColor: Colors.blueGrey.shade100, 
                  color: const Color(0xFF0D9488), 
                  borderRadius: BorderRadius.circular(10), 
                  minHeight: 10
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---
  Widget _buildMiniStat(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(val, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(label, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCircle(String val, String sub, Color color, double progress) {
    return Column(
      children: [
        SizedBox(
          width: 70, height: 70,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(value: 1.0, color: color.withOpacity(0.1), strokeWidth: 6),
              CircularProgressIndicator(value: progress, color: color, strokeWidth: 6, strokeCap: StrokeCap.round),
              Center(child: Text(val, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(sub, style: GoogleFonts.inter(color: Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionBtn(String title, String sub, IconData icon, Color color, double width, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 140, // Yüksekliği biraz azalttım ki 2 satır çok yer kaplamasın
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(24), 
          // 🔥 PERFORMANS: Blur 10 -> 4
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 4))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(sub, maxLines: 2, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}