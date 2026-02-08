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
import 'focus_screen.dart'; // Odak Modu Importu

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _showSuccessRate = true; 
  
  // --- VERİ DEĞİŞKENLERİ ---
  String _targetBranch = "Hedef Seçiliyor...";
  int _dailyGoal = 60;
  int _dailyQuestionGoal = 100;

  int _dailyMinutes = 0;
  int _dailySolved = 0;
  int _totalSolved = 0;
  int _totalCorrect = 0; 

  late ConfettiController _confettiController;
  bool _dailyGoalCelebrated = false;
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
          .listen((snapshot) async {
        
        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

          String today = DateTime.now().toIso8601String().split('T')[0];
          String lastDate = data['lastActivityDate'] ?? "";
          
          // 🔥 GÜNLÜK SIFIRLAMA MANTIĞI
          if (lastDate != today){
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'dailySolved': 0,
              'dailyMinutes': 0,
              'lastActivityDate': today,
              'isDailyGoalCelebrated': false, 
            });
          }

          if (mounted) {
            setState(() {
              _dailyGoalCelebrated = data['isDailyGoalCelebrated'] ?? false;
              
              
              if (data.containsKey('targetBranch')) _targetBranch = data['targetBranch'];
              if (data.containsKey('dailyGoalMinutes')) _dailyGoal = (data['dailyGoalMinutes'] as num).toInt();
              if (data.containsKey('dailyQuestionGoal')) {
                _dailyQuestionGoal = (data['dailyQuestionGoal'] as num).toInt();
              }
              if (data.containsKey('showSuccessRate')) _showSuccessRate = data['showSuccessRate'];

              _totalSolved = (data['totalSolved'] ?? 0).toInt();
              _totalCorrect = (data['totalCorrect'] ?? 0).toInt();
              
              _dailySolved = (data['dailySolved'] ?? 0).toInt();
              _dailyMinutes = (data['dailyMinutes'] ?? 0).toInt();
            });
          }
        }
      }, onError: (e) {
        debugPrint("Veri dinleme hatası: $e");
      });
    }
  }

  // 🔥 YENİ: Sadece çağrıldığında kontrol edip patlatan fonksiyon
  void _checkAndCelebrate() {
    // Hedefler tuttu mu?
    bool isQuestionGoalMet = _dailySolved >= _dailyQuestionGoal;
    bool isTimeGoalMet = _dailyMinutes >= _dailyGoal;

    // İkisi de tamam ve henüz kutlamadık mı?
    if (isQuestionGoalMet && isTimeGoalMet && !_dailyGoalCelebrated) {
      
      _confettiController.play(); // 🎉 PATLAT!

      setState(() {
        _dailyGoalCelebrated = true; // Kilidi vur
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null){
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isDailyGoalCelebrated': true
      });
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(child: Text("GÜNÜN ŞAMPİYONU! 🏆", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("Harikasın! Hem soru hedefini hem de süre hedefini tamamladın.", textAlign: TextAlign.center),
              SizedBox(height: 10),
              Text("Zinciri kırmadın! ⛓️🔥", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Devam Et", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
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
        level: m['subject'] ?? "Genel", 
      );
    }).toList();
  }

  // --- 1. MODÜL: PRATİK (KONU SEÇİMİ) ---
  void _showTopicSelection(BuildContext context) {
    // Tema kontrolü ve dinamik renkler
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color titleColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor, // Arka plan rengini dinamik yaptık
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300, 
                    borderRadius: BorderRadius.circular(2)
                  )
                ),
              ),
              
              Text(
                "Çalışma Alanı", 
                style: GoogleFonts.inter(
                  fontSize: 22, 
                  fontWeight: FontWeight.w800, 
                  color: titleColor 
                )
              ),
              const SizedBox(height: 4),
              Text(
                "Hangi alanda pratik yapmak istersin?", 
                style: GoogleFonts.inter(
                  fontSize: 14, 
                  color: subtitleColor
                )
              ),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      context, 
                      title: "Temel\nBilimler", 
                      icon: Icons.biotech_outlined, 
                      color: Colors.orange, 
                      topics: ["Anatomi","Histoloji ve Embriyoloji" ,"Fizyoloji", "Biyokimya", "Mikrobiyoloji", "Patoloji", "Farmakoloji","Biyoloji ve Genetik"],
                      onTapOverride: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => TopicSelectionScreen(title: "Temel Bilimler", topics: ["Anatomi","Histoloji ve Embriyoloji" ,"Fizyoloji", "Biyokimya", "Mikrobiyoloji", "Patoloji", "Farmakoloji","Biyoloji ve Genetik"], themeColor: Colors.orange))
                        ).then((_) => _checkAndCelebrate()); // <--- DÖNÜNCE KONTROL ET
                      }
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      context, 
                      title: "Klinik\nBilimler", 
                      icon: Icons.health_and_safety_outlined, 
                      color: Colors.blue, 
                      topics: ["Protetik Diş Tedavisi", "Restoratif Diş Tedavisi", "Endodonti", "Periodontoloji", "Ortodonti", "Pedodonti", "Ağız, Diş ve Çene Cerrahisi", "Ağız, Diş ve Çene Radyolojisi"],
                      onTapOverride: () {
                         Navigator.pop(context);
                         Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => TopicSelectionScreen(title: "Klinik Bilimler", topics: ["Protetik Diş Tedavisi", "Restoratif Diş Tedavisi", "Endodonti", "Periodontoloji", "Ortodonti", "Pedodonti", "Ağız, Diş ve Çene Cerrahisi", "Ağız, Diş ve Çene Radyolojisi"], themeColor: Colors.blue))
                        ).then((_) => _checkAndCelebrate()); // <--- DÖNÜNCE KONTROL ET
                      }
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
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(isTrial: true, fixedDuration: 150)))
                   .then((_) => _checkAndCelebrate());
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. MODÜL: YANLIŞLAR MENÜSÜ ---
  void _showMistakesMenu(BuildContext context) async {
    List<Map<String, dynamic>> mistakes = await MistakesService.getMistakes();
    int count = mistakes.length;

    if (!mounted) return;

    // Tema Ayarları
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    Color titleColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    Color subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              Text("Yanlış Yönetimi", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor)),
              const SizedBox(height: 4),
              Text("Toplam $count yanlışın var. Nasıl ilerleyelim?", style: GoogleFonts.inter(fontSize: 14, color: subtitleColor)),
              const SizedBox(height: 32),
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
                        Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(isTrial: true, questions: questions, topic: "Karışık Yanlış Tekrarı")))
                        .then((_) => _checkAndCelebrate()); // 🔥 EKLENDİ
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
                color: const Color.fromARGB(255, 205, 16, 35), 
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

  void _showSubjectSelectionList(BuildContext context, List<Map<String, dynamic>> mistakes) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var m in mistakes) {
      String sub = m['subject'] ?? "Diğer";
      if (!grouped.containsKey(sub)) grouped[sub] = [];
      grouped[sub]!.add(m);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // Burası liste içi, beyaz kalabilir veya koyu yapılabilir
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
                          )))
                          .then((_) => _checkAndCelebrate()); // 🔥 EKLENDİ
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
    // Koyu mod kontrolü
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    Color subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey;

    return Container(
      height: isWide ? 100 : 160,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey.withOpacity(0.1)),
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
                      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      if (subtitle != null)
                        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: subtitleColor)),
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
                      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, height: 1.2)),
                      if (subtitle != null)
                        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500)),
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
    // 1. Tema Durumunu Kontrol Et
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 2. Renk Tanımlamaları
    Color scaffoldColor = isDarkMode ? Colors.black : const Color.fromARGB(255, 224, 247, 250);
    Color navBarColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    Color navShadowColor = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    List<Widget> currentPages = [
      DashboardScreen(
        targetBranch: _targetBranch,
        dailyGoal: _dailyGoal,
        dailyQuestionGoal: _dailyQuestionGoal, 
        dailyMinutes: _dailyMinutes,
        dailySolved: _dailySolved,
        totalSolved: _totalSolved,
        totalCorrect: _totalCorrect,
        showSuccessRate: _showSuccessRate,
        onRefresh: () {}, 
        onMistakesTap: () => _showMistakesMenu(context),
        onPratikTap: () => _showTopicSelection(context), 
      ),
      const BlogScreen(),
      Scaffold(
        backgroundColor: Colors.transparent, 
        body: Center(
          child: Text(
            "Analiz Ekranı Hazırlanıyor...",
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black54),
          )
        )
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: currentPages,
          ),
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
          color: navBarColor, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: navShadowColor, 
              blurRadius: 15, 
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: NavigationBar(
            height: 80,
            backgroundColor: navBarColor, 
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    return NavigationDestination(
      icon: Icon(icon, color: inactiveColor, size: 28),
      selectedIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_filled, color: Color(0xFF0D9488), size: 28),
          const SizedBox(height: 4),
          Container(
            width: 4, 
            height: 4, 
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488), 
              shape: BoxShape.circle
            )
          ),
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
  final int dailyQuestionGoal; 
  
  final int dailyMinutes;
  final int dailySolved;
  final int totalSolved;
  
  final int totalCorrect;
  final bool showSuccessRate;

  final VoidCallback onRefresh;
  final VoidCallback? onMistakesTap; 
  final VoidCallback? onPratikTap;

  const DashboardScreen({
    super.key,
    required this.targetBranch,
    required this.dailyGoal,
    required this.dailyQuestionGoal, 
    required this.dailyMinutes,   
    required this.dailySolved,    
    required this.totalSolved,    
    required this.totalCorrect,
    required this.showSuccessRate,
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
    if (!showSuccessRate) return '---'; 

    if (totalSolved == 0) return '%0';
    double rate = (totalCorrect.toDouble() / totalSolved.toDouble()) * 100;
    return '%${rate.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    // Tema kontrolü
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // --- HEADER ---
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1), 
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 80), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_getGreeting()}, Doktor', 
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                'Hedef: $targetBranch Uzmanlığı', 
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis, 
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold) 
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
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
                        _buildMiniStat(Icons.check_circle_outline, '$totalSolved', 'Toplam Soru', Colors.orange.shade400),
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
                  color: cardColor, // Dinamik Kart Rengi
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Text("Bugünkü Hedefler", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                    ),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildGoalCircle(
                            '$dailySolved',     
                            '$dailyQuestionGoal Soru', 
                            Colors.teal,
                            dailyQuestionGoal > 0 
                                ? (dailySolved / dailyQuestionGoal).clamp(0.0, 1.0) 
                                : 0.0 
                          )
                        ),
                        Container(width: 1, height: 60, color: Colors.grey.withOpacity(0.2)),
                        Expanded(
                          child: _buildGoalCircle(
                            '$dailyMinutes',    
                            '$dailyGoal Dakika', 
                            Colors.orange,
                            dailyGoal > 0 ? (dailyMinutes / dailyGoal).clamp(0.0, 1.0) : 0.0 
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- BUTON YAPISI ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtnVertical(
                        'Pratik', 
                        'Soru Çöz', 
                        Icons.play_arrow, 
                        const Color(0xFF0D47A1),
                        onTap: () {
                          if (onPratikTap != null) onPratikTap!();
                        }
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                    child: _buildActionBtnVertical(
                        'Bilgi\nKartları',
                        'Tekrar Et', 
                        Icons.style,
                       Colors.green.shade400,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("🚀 Bilgi Kartları modülü yakında hazırlanıyor!"),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            )
                          );  
                        }
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionBtnVertical(
                        'Yanlışlar', 
                        'Hatalarını Gör', 
                        Icons.refresh, 
                        const Color.fromARGB(255, 205, 16, 35),
                        onTap: () {
                          if (onMistakesTap != null) onMistakesTap!();
                        }
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildActionBtnHorizontal(
                  'Odak Modu (Timer)', 
                  'Pomodoro ile verimli çalış', 
                  Icons.track_changes, 
                  Colors.deepPurple,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FocusScreen()));
                  }
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
  
  Widget _buildActionBtnVertical(String title, String sub, IconData icon, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 28)),
            const Spacer(),
            Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(sub, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtnHorizontal(String title, String sub, IconData icon, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 32)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(sub, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

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
}