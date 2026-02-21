// lib/screens/home_screen.dart - OFFLINE MOD ENTEGRE EDİLMİŞ VERSİYON (DÜZELTME)

import 'dart:async';
import 'dart:ui'; 
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
import 'focus_screen.dart'; 
import 'analysis_screen.dart'; 
import 'flashcards_screen.dart'; 
import 'bookmarks_screen.dart';

// 🔥 OFFLINE MOD IMPORTLARI 🔥
import 'offline_manager_screen.dart';

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

  // 🔥 OPTİMİZASYON DEĞİŞKENLERİ 🔥
  bool _isMistakesMenuOpen = false;
  List<Map<String, dynamic>>? _cachedMistakes;
  DateTime? _lastMistakesFetch;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _listenToUserData(); 
    MistakesService.syncLocalToFirebase();
    _runMigration();
  }

  Future<void> _runMigration() async {
    await MistakesService.syncLocalToFirebase();
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); 
    _confettiController.dispose();
    super.dispose();
  }

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

  void _checkAndCelebrate() {
    bool isQuestionGoalMet = _dailySolved >= _dailyQuestionGoal;
    bool isTimeGoalMet = _dailyMinutes >= _dailyGoal;

    if (isQuestionGoalMet && isTimeGoalMet && !_dailyGoalCelebrated) {
      _confettiController.play(); 

      setState(() {
        _dailyGoalCelebrated = true; 
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

  List<Question> _convertMistakesToQuestions(List<Map<String, dynamic>> mistakes) {
    return mistakes.map((m) {
      return Question(
        id: m['questionIndex'] ?? 0, 
        question: m['question'],
        options: List<String>.from(m['options']),
        answerIndex: m['correctIndex'],
        explanation: m['explanation'] ?? "",
        testNo: m['testNo'] ?? 0, 
        level: m['topic'] ?? m['subject'] ?? "Genel", 
        imageUrl: m['imageUrl'], 

      );
    }).toList();
  }

  void _showTopicSelection(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDarkMode ? const Color(0xFF161B22) : Colors.white; 
    final Color titleColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B); 
    final Color subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor, 
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
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300, 
                    borderRadius: BorderRadius.circular(2)
                  )
                ),
              ),
              
              Text("Çalışma Alanı", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor)),
              const SizedBox(height: 4),
              Text("Hangi alanda pratik yapmak istersin?", style: GoogleFonts.inter(fontSize: 14, color: subtitleColor)),
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
                        ).then((_) => _checkAndCelebrate()); 
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
                        ).then((_) => _checkAndCelebrate()); 
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

  Future<List<Map<String, dynamic>>> _getMistakesCached() async {
    final now = DateTime.now();
    
    if (_cachedMistakes != null && 
        _lastMistakesFetch != null && 
        now.difference(_lastMistakesFetch!).inSeconds < 30) {
      return _cachedMistakes!;
    }
    
    final mistakes = await MistakesService.getMistakes();
    _cachedMistakes = mistakes;
    _lastMistakesFetch = now;
    return mistakes;
  }

  void _invalidateMistakesCache() {
    _cachedMistakes = null;
    _lastMistakesFetch = null;
  }

  void _showMistakesMenu(BuildContext context) {
    if (_isMistakesMenuOpen) return;
    _isMistakesMenuOpen = true;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final Color titleColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final Color subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    if (!mounted) {
      _isMistakesMenuOpen = false;
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _MistakesMenuContent(
        bgColor: bgColor,
        isDarkMode: isDarkMode,
        titleColor: titleColor,
        subtitleColor: subtitleColor,
        getMistakes: _getMistakesCached,
        convertToQuestions: _convertMistakesToQuestions,
        onCheckCelebrate: _checkAndCelebrate,
        onShowSubjectList: _showSubjectSelectionList,
      ),
    ).whenComplete(() {
      _isMistakesMenuOpen = false;
    });
  }

  void _showSubjectSelectionList(BuildContext context, List<Map<String, dynamic>> mistakes) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var m in mistakes) {
      String sub = m['subject'] ?? m['topic'] ?? "Diğer";
      grouped.putIfAbsent(sub, () => []).add(m);
    }

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor, 
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
                Text("Hangi Dersi Tekrar Edeceksin?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: grouped.keys.length,
                    separatorBuilder: (c, i) => Divider(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      String subject = grouped.keys.elementAt(index);
                      int count = grouped[subject]!.length;
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.book, color: Colors.teal)),
                        title: Text(subject, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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
                          .then((_) => _checkAndCelebrate()); 
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

  Widget _buildModernCard(BuildContext context, {
    required String title, 
    required IconData icon, 
    required Color color, 
    List<String>? topics,
    String? subtitle,
    bool isWide = false,
    VoidCallback? onTapOverride
  }) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    Color cardColor = isDarkMode ? const Color(0xFF161B22) : Colors.white; 
    Color subtitleColor = isDarkMode ? Colors.white60 : Colors.blueGrey;
    Color borderColor = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1); 

    return Container(
      height: isWide ? 100 : 160,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : color.withOpacity(0.08), 
            blurRadius: 8, 
            offset: const Offset(0, 5)
          ),
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
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget background = isDarkMode 
      ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0E14), 
                Color(0xFF161B22), 
              ]
            )
          ),
        )
      // ESKİ HALİ: : Container(color: const Color(0xFFF5F9FF));
      // YENİ HALİ AŞAĞIDAKİ GİBİ OLACAK:
      : Container(color: const Color.fromARGB(255, 224, 247, 250));

    Color navBarColor = isDarkMode ? const Color(0xFF161B22).withOpacity(0.8) : Colors.white;

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
      const AnalysisScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          background,
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
      bottomNavigationBar: ClipRRect( 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
          child: Container(
            decoration: BoxDecoration(
              color: navBarColor, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.05), 
                  blurRadius: 15, 
                  offset: const Offset(0, -5),
                ),
              ],
              border: isDarkMode ? Border(top: BorderSide(color: Colors.white.withOpacity(0.1))) : null,
            ),
            child: NavigationBar(
              height: 80,
              backgroundColor: Colors.transparent, 
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
      ),
    );
  }

  NavigationDestination _buildNavDest(IconData icon, IconData activeIcon, int idx) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final inactiveColor = isDarkMode ? Colors.grey.shade600 : Colors.blueGrey.shade400;
    final activeColor = isDarkMode ? const Color(0xFF448AFF) : const Color(0xFF0D9488);

    return NavigationDestination(
      icon: Icon(icon, color: inactiveColor, size: 28),
      selectedIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(activeIcon, color: activeColor, size: 28),
          const SizedBox(height: 4),
          Container(
            width: 4, 
            height: 4, 
            decoration: BoxDecoration(
              color: activeColor, 
              shape: BoxShape.circle
            )
          ),
        ],
      ),
      label: '',
    );
  }
}

// YANLI ŞLAR MENÜSÜ WİDGET'I
class _MistakesMenuContent extends StatefulWidget {
  final Color bgColor;
  final bool isDarkMode;
  final Color titleColor;
  final Color subtitleColor;
  final Future<List<Map<String, dynamic>>> Function() getMistakes;
  final List<Question> Function(List<Map<String, dynamic>>) convertToQuestions;
  final VoidCallback onCheckCelebrate;
  final void Function(BuildContext, List<Map<String, dynamic>>) onShowSubjectList;

  const _MistakesMenuContent({
    required this.bgColor,
    required this.isDarkMode,
    required this.titleColor,
    required this.subtitleColor,
    required this.getMistakes,
    required this.convertToQuestions,
    required this.onCheckCelebrate,
    required this.onShowSubjectList,
  });

  @override
  State<_MistakesMenuContent> createState() => _MistakesMenuContentState();
}

class _MistakesMenuContentState extends State<_MistakesMenuContent> {
  List<Map<String, dynamic>>? _mistakes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    try {
      final mistakes = await widget.getMistakes();
      if (mounted) {
        setState(() {
          _mistakes = mistakes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mistakes = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.bgColor,
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
                  color: widget.isDarkMode ? Colors.white24 : Colors.grey.shade300, 
                  borderRadius: BorderRadius.circular(2)
                )
              ),
            ),
            
            Text("Yanlış Yönetimi", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: widget.titleColor)),
            const SizedBox(height: 4),
            
            _isLoading 
              ? const SizedBox(
                  height: 20,
                  child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                )
              : Text(
                  "Toplam ${_mistakes?.length ?? 0} yanlışın var. Nasıl ilerleyelim?", 
                  style: GoogleFonts.inter(fontSize: 14, color: widget.subtitleColor)
                ),
            
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
                    onTap: () {
                      Navigator.pop(context);
                      if (_mistakes == null || _mistakes!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Henüz yanlışın yok! Harikasın 🎉"))
                        );
                        return;
                      }
                      List<Map<String, dynamic>> shuffled = List.from(_mistakes!)..shuffle();
                      List<Question> questions = widget.convertToQuestions(shuffled);
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => QuizScreen(isTrial: true, questions: questions, topic: "Karışık Yanlış Tekrarı"))
                      ).then((_) => widget.onCheckCelebrate()); 
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
                    onTap: () {
                      Navigator.pop(context);
                      if (_mistakes == null || _mistakes!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Henüz yanlışın yok!"))
                        );
                        return;
                      }
                      widget.onShowSubjectList(context, _mistakes!);
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MistakesDashboard()));
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard(BuildContext context, {
    required String title, 
    required IconData icon, 
    required Color color, 
    String? subtitle,
    bool isWide = false,
    required VoidCallback onTap
  }) {
    Color textColor = widget.isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    Color cardColor = widget.isDarkMode ? const Color(0xFF161B22) : Colors.white; 
    Color subtitleColor = widget.isDarkMode ? Colors.white60 : Colors.blueGrey;
    Color borderColor = widget.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1); 

    return Container(
      height: isWide ? 100 : 160,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : color.withOpacity(0.08), 
            blurRadius: 8, 
            offset: const Offset(0, 5)
          ),
        ]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _isLoading ? null : onTap,
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
}

// DASHBOARD EKRANI
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
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    Color headerColor = isDarkMode ? const Color(0xFF2563EB).withOpacity(0.6) : const Color(0xFF0D47A1);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 1. ÜST KISIM (HEADER)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
            child: BackdropFilter(
              filter: isDarkMode ? ImageFilter.blur(sigmaX: 10, sigmaY: 10) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: headerColor, 
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                  border: isDarkMode ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))) : null 
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
                                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 14)),
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
                            
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarksScreen()));
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.bookmark_rounded, color: Colors.orangeAccent),
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.notifications_none, color: Colors.white),
                            )
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            _buildMiniStat(Icons.check_circle_outline, '$totalSolved', 'Toplam Soru', Colors.orange.shade400, isDarkMode),
                            const SizedBox(width: 16),
                            _buildMiniStat(Icons.track_changes, _calculateSuccessRate(), 'Başarı Oranı', Colors.green.shade400, isDarkMode),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. BUGÜNKÜ HEDEFLER KARTI
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildGlassCard(
                isDark: isDarkMode,
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
                            dailyQuestionGoal > 0 ? (dailySolved / dailyQuestionGoal).clamp(0.0, 1.0) : 0.0,
                            isDarkMode
                          )
                        ),
                        Container(
                          width: 1, 
                          height: 60, 
                          color: isDarkMode ? Colors.white10 : Colors.grey.withOpacity(0.2)
                        ),
                        Expanded(
                          child: _buildGoalCircle(
                            '$dailyMinutes',    
                            '$dailyGoal Dakika', 
                            Colors.orange,
                            dailyGoal > 0 ? (dailyMinutes / dailyGoal).clamp(0.0, 1.0) : 0.0,
                            isDarkMode
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. BUTONLAR
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
                        isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF0D47A1), 
                        isDarkMode,
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
                       isDarkMode ? const Color(0xFF10B981) : Colors.green.shade400, 
                       isDarkMode,
                        onTap: () {
                           Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const FlashcardsScreen())
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionBtnVertical(
                        'Yanlışlar', 
                        'Hataları Gör', 
                        Icons.refresh, 
                        isDarkMode ? const Color(0xFFEF4444) : const Color.fromARGB(255, 205, 16, 35), 
                        isDarkMode,
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
                  isDarkMode ? const Color(0xFF8B5CF6) : Colors.deepPurple, 
                  isDarkMode,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FocusScreen()));
                  }
                ),

                // 🔥 OFFLINE MOD BUTONU (GÜNCELLENDİ)
                const SizedBox(height: 16),
                _buildActionBtnHorizontal(
                  'Offline Mod', 
                  'Konuları indir, internetsiz çöz', 
                  Icons.cloud_download_outlined, 
                  isDarkMode ? const Color(0xFF0EA5E9) : Colors.lightBlue, 
                  isDarkMode,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OfflineManagerScreen()));
                  }
                ),
              ],
            ),
          ),
          
          // 🔥 DÜZELTME BURADA: Dashboard'un yüksekliğini hesaba katıp 150px boşluk ekliyoruz.
          const SizedBox(height: 150),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    if (!isDark) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withOpacity(0.6), 
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: child,
        ),
      ),
    );
  }
  
  Widget _buildActionBtnVertical(String title, String sub, IconData icon, Color color, bool isDark, {required VoidCallback onTap}) {
    Color baseColor = isDark ? color.withOpacity(0.2) : color;

    Widget content = Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor, 
        gradient: isDark ? LinearGradient(colors: [baseColor, baseColor.withOpacity(0.4)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        borderRadius: BorderRadius.circular(24), 
        border: isDark ? Border.all(color: color.withOpacity(0.5)) : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.3), 
            blurRadius: isDark ? 15 : 8, 
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 28)),
          const Spacer(),
          Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(sub, style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );

    if (isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), 
          child: GestureDetector(onTap: onTap, child: content),
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _buildActionBtnHorizontal(String title, String sub, IconData icon, Color color, bool isDark, {required VoidCallback onTap}) {
    Color baseColor = isDark ? color.withOpacity(0.2) : color;

    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor, 
        gradient: isDark ? LinearGradient(colors: [baseColor, baseColor.withOpacity(0.4)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        borderRadius: BorderRadius.circular(24), 
        border: isDark ? Border.all(color: color.withOpacity(0.5)) : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.3), 
            blurRadius: isDark ? 15 : 8, 
            offset: const Offset(0, 4)
          )
        ]
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
    );

    if (isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: GestureDetector(onTap: onTap, child: content),
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _buildMiniStat(IconData icon, String val, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isDark ? 0.08 : 0.1), 
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.white.withOpacity(0.1))
        ),
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

  Widget _buildGoalCircle(String val, String sub, Color color, double progress, bool isDark) {
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
        Text(sub, style: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}