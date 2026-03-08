// lib/screens/home_screen.dart - OFFLINE MOD ENTEGRE EDİLMİŞ VERSİYON (KUSURSUZ SENKRONİZASYON)
// DEĞİŞİKLİKLER:
//   1. Karışık Tekrar: soru sayısı seçim sheet'i eklendi
//   2. Konu Bazlı: dersi seçtikten sonra soru sayısı seçim sheet'i eklendi
//   3. Her iki modda da quiz bittikten sonra "doğruları yanlışlardan sil?" dialog'u eklendi

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
import 'exam_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Soru Sayısı Seçim BottomSheet
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCountSheet extends StatefulWidget {
  final int maxCount;
  final bool isDark;
  final String title;
  final String subtitle;

  const _QuestionCountSheet({
    required this.maxCount,
    required this.isDark,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_QuestionCountSheet> createState() => _QuestionCountSheetState();
}

class _QuestionCountSheetState extends State<_QuestionCountSheet> {
  int? _selected;

  List<int> get _counts {
    const base = [10, 20, 30];
    // Eğer max sayı base'den küçükse sadece uygun olanları + tümünü göster
    List<int> result = base.where((c) => c <= widget.maxCount).toList();
    if (!result.contains(widget.maxCount) && widget.maxCount > 0) {
      result.add(widget.maxCount); // "Tümü"
    }
    if (result.isEmpty) result.add(widget.maxCount);
    return result;
  }

  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.isDark
        ? const Color(0xFF0D1117).withOpacity(0.92)
        : Colors.white.withOpacity(0.95);
    final Color titleColor =
        widget.isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final Color subtitleColor =
        widget.isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400;
    final Color cardBg = widget.isDark
        ? const Color(0xFF161B22).withOpacity(0.6)
        : Colors.white.withOpacity(0.85);
    final Color borderColor =
        widget.isDark ? Colors.white.withOpacity(0.08) : Colors.white;

    final counts = _counts;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: widget.isDark
                ? Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 28),

                // Chip'ler
                Row(
                  children: counts.map((count) {
                    final isLast = count == counts.last;
                    final isSelected = _selected == count;
                    final label = count == widget.maxCount &&
                            !const [10, 20, 30].contains(count)
                        ? 'Tümü\n($count)'
                        : '$count';
                    return Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.only(right: isLast ? 0 : 12),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selected = count),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: 8, sigmaY: 8),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                height: 90,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _accent.withOpacity(
                                          widget.isDark ? 0.2 : 0.1)
                                      : cardBg,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? _accent
                                        : borderColor,
                                    width: isSelected ? 2 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _accent
                                                .withOpacity(0.25),
                                            blurRadius: 10,
                                            offset:
                                                const Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: count ==
                                                    widget.maxCount &&
                                                !const [10, 20, 30]
                                                    .contains(count)
                                            ? 16
                                            : 28,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? _accent
                                            : (widget.isDark
                                                ? const Color(
                                                    0xFFE6EDF3)
                                                : Colors.black87),
                                      ),
                                    ),
                                    if (const [10, 20, 30]
                                        .contains(count))
                                      Text(
                                        'Soru',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? _accent.withOpacity(
                                                  0.8)
                                              : (widget.isDark
                                                  ? Colors.white38
                                                  : Colors.blueGrey
                                                      .shade400),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 36),

                // Başlat butonu
                GestureDetector(
                  onTap: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _selected != null
                          ? (_accent)
                          : (widget.isDark
                              ? Colors.white12
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _selected != null
                          ? [
                              BoxShadow(
                                color: _accent.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sınavı Başlat',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _selected != null
                                  ? Colors.white
                                  : Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: _selected != null
                                ? Colors.white
                                : Colors.white38,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

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
              Text(
                "Harikasın! Hem soru hedefini hem de süre hedefini tamamladın.", 
                textAlign: TextAlign.center,
              ),
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
      // level alanına Firestore doküman ID'sini ('topic_testNo_qIndex') yazıyoruz.
      // quiz_screen.dart bu değeri correctQuestionsToRemove için direkt kullanır —
      // her topic formatında ('Sınav Provası_0_5' dahil) silme doğru çalışır.
      final firestoreDocId = m['id']?.toString() ?? '';
      return Question(
        id: m['questionIndex'] ?? 0,
        question: m['question'],
        options: List<String>.from(m['options']),
        answerIndex: m['correctIndex'],
        explanation: m['explanation'] ?? "",
        testNo: m['testNo'] ?? 0,
        level: firestoreDocId.isNotEmpty
            ? firestoreDocId
            : (m['topic'] ?? m['subject'] ?? "Genel"),
        imageUrl: m['imageUrl'],
      );
    }).toList();
  }

  // ─── Soru sayısı seçim sheet'ini göster ─────────────────────────────────
  /// Seçilen sayıyı döndürür. Kullanıcı kapatırsa null döner.
  Future<int?> _showQuestionCountPicker({
    required int maxCount,
    required bool isDark,
    required String title,
    required String subtitle,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QuestionCountSheet(
        maxCount: maxCount,
        isDark: isDark,
        title: title,
        subtitle: subtitle,
      ),
    );
  }


  // ─── Yanlış tekrarı quiz'ini başlat ────────────────────────────────────
  // quiz_screen.dart zaten:
  //   - isMistakeReview modunda yanlış/boşları tekrar kaydetmiyor
  //   - doğru yapılanları removeMistakeList ile siliyor (doğru ID formatıyla)
  // onComplete sadece normal bitişte çağrılır (erken çıkışta çağrılmaz).
  Future<void> _runMistakesQuiz({
    required List<Question> questions,
    required String topic,
    required bool isDark,
  }) async {
    if (!mounted) return;

    int? resultCorrect;
    int? resultWrong;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          isTrial: true,
          questions: questions,
          topic: topic,
          onComplete: (correct, wrong, empty) {
            resultCorrect = correct;
            resultWrong = wrong;
          },
        ),
      ),
    );

    // Cache'i temizle
    _invalidateMistakesCache();

    // Erken çıkış: result null veya false → hiçbir şey yapma
    if (result != true || !mounted) return;

    // Normal bitiş
    _checkAndCelebrate();

    if (resultCorrect != null && mounted) {
      final correct = resultCorrect!;
      final total = questions.length;
      final color = correct > 0 ? const Color(0xFF10B981) : Colors.orange;
      final emoji = correct == total ? '🎉' : correct > 0 ? '✅' : '📚';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emoji $correct/$total doğru. Doğrular yanlışlardan otomatik silindi.'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Çalışma Alanı Sheet ────────────────────────────────────────────────────
  void _showTopicSelection(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B); 
    final Color subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF0D1117).withOpacity(0.75) : Colors.white.withOpacity(0.85), 
              border: isDarkMode ? Border(top: BorderSide(color: Colors.white.withOpacity(0.1))) : null,
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
                        color: isDarkMode ? Colors.white24 : Colors.grey.shade400, 
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
                          topics: ["Anatomi", "Biyokimya", "Biyoloji ve Genetik", "Farmakoloji", "Fizyoloji", "Histoloji ve Embriyoloji", "Mikrobiyoloji", "Patoloji"],
                          onTapOverride: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => TopicSelectionScreen(
                                title: "Temel Bilimler", 
                                topics: ["Anatomi", "Biyokimya", "Biyoloji ve Genetik", "Farmakoloji", "Fizyoloji", "Histoloji ve Embriyoloji", "Mikrobiyoloji", "Patoloji"], 
                                themeColor: Colors.orange
                              ))
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
                          topics: [
                            "Ağız, Diş ve Çene Cerrahisi",
                            "Ağız, Diş ve Çene Radyolojisi",
                            "Endodonti",
                            "Ortodonti",
                            "Pedodonti",
                            "Periodontoloji",
                            "Protetik Diş Tedavisi",
                            "Restoratif Diş Tedavisi"
                          ],
                          onTapOverride: () {
                             Navigator.pop(context);
                             Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => TopicSelectionScreen(
                                title: "Klinik Bilimler", 
                                topics: [
                                  "Ağız, Diş ve Çene Cerrahisi",
                                  "Ağız, Diş ve Çene Radyolojisi",
                                  "Endodonti",
                                  "Ortodonti",
                                  "Pedodonti",
                                  "Periodontoloji",
                                  "Protetik Diş Tedavisi",
                                  "Restoratif Diş Tedavisi"
                                ], 
                                themeColor: Colors.blue
                              ))
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
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const ExamSetupScreen()))
                       .then((_) => _checkAndCelebrate());
                    }
                  ),
                ],
              ),
            ),
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
        isDarkMode: isDarkMode,
        titleColor: titleColor,
        subtitleColor: subtitleColor,
        getMistakes: _getMistakesCached,
        convertToQuestions: _convertMistakesToQuestions,
        onCheckCelebrate: _checkAndCelebrate,
        onShowSubjectList: _showSubjectSelectionList,
        showQuestionCountPicker: _showQuestionCountPicker,
        runMistakesQuiz: _runMistakesQuiz,
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

    List<String> sortedSubjects = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true, 
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7, 
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0D1117).withOpacity(0.75) : Colors.white.withOpacity(0.85),
                border: isDarkMode ? Border(top: BorderSide(color: Colors.white.withOpacity(0.1))) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4, 
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white24 : Colors.grey.shade400, 
                          borderRadius: BorderRadius.circular(2)
                        )
                      ),
                    ),
                    Text("Hangi Dersi Tekrar Edeceksin?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: sortedSubjects.length,
                        separatorBuilder: (c, i) => Divider(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                        itemBuilder: (context, index) {
                          String subject = sortedSubjects[index];
                          int count = grouped[subject]!.length;

                          IconData subjectIcon = Icons.menu_book_rounded;
                          Color subjectColor = Colors.teal;
                          
                          final s = subject.toLowerCase();
                          if (s.contains('anatomi')) { subjectIcon = Icons.accessibility_new_rounded; subjectColor = Colors.orange; }
                          else if (s.contains('histoloji')) { subjectIcon = Icons.biotech_rounded; subjectColor = Colors.pink; }
                          else if (s.contains('fizyoloji')) { subjectIcon = Icons.monitor_heart_rounded; subjectColor = Colors.red; }
                          else if (s.contains('biyokimya')) { subjectIcon = Icons.science_rounded; subjectColor = Colors.purple; }
                          else if (s.contains('mikrobiyoloji')) { subjectIcon = Icons.coronavirus_rounded; subjectColor = Colors.green; }
                          else if (s.contains('patoloji')) { subjectIcon = Icons.sick_rounded; subjectColor = Colors.brown; }
                          else if (s.contains('farmakoloji') || s.contains('farma')) { subjectIcon = Icons.medication_rounded; subjectColor = Colors.teal; }
                          else if (s.contains('biyoloji')) { subjectIcon = Icons.eco_rounded; subjectColor = Colors.lime; }
                          else if (s.contains('protetik')) { subjectIcon = Icons.health_and_safety_rounded; subjectColor = Colors.lightBlue; }
                          else if (s.contains('restoratif')) { subjectIcon = Icons.healing_rounded; subjectColor = Colors.blue; }
                          else if (s.contains('endodonti')) { subjectIcon = Icons.medical_services_rounded; subjectColor = Colors.orangeAccent; }
                          else if (s.contains('perio')) { subjectIcon = Icons.water_drop_rounded; subjectColor = Colors.deepOrange; }
                          else if (s.contains('ortodonti')) { subjectIcon = Icons.sentiment_satisfied_alt_rounded; subjectColor = Colors.indigo; }
                          else if (s.contains('pedodonti')) { subjectIcon = Icons.child_care_rounded; subjectColor = Colors.amber; }
                          else if (s.contains('cerrahi')) { subjectIcon = Icons.content_cut_rounded; subjectColor = Colors.redAccent; }
                          else if (s.contains('radyoloji')) { subjectIcon = Icons.sensors_rounded; subjectColor = Colors.blueGrey; }

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: subjectColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(subjectIcon, color: subjectColor, size: 24),
                            ),
                            title: Text(subject, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(isDarkMode ? 0.2 : 0.1), 
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Text("$count Yanlış", style: TextStyle(color: isDarkMode ? Colors.redAccent : Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold))
                            ),
                            onTap: () async {
                              // Sheet'i kapat
                              Navigator.pop(context);

                              final subjectMistakes = grouped[subject]!;

                              // ── YENİ: Soru sayısı seç ──
                              final picked = await _showQuestionCountPicker(
                                maxCount: subjectMistakes.length,
                                isDark: isDarkMode,
                                title: '$subject Tekrarı',
                                subtitle: 'Kaç soru çözmek istiyorsun?',
                              );
                              if (picked == null || !mounted) return;

                              final subjectMistakesShuffled =
                                  List<Map<String, dynamic>>.from(subjectMistakes)
                                    ..shuffle();
                              final selectedMistakes =
                                  subjectMistakesShuffled.take(picked).toList();

                              final questions =
                                  _convertMistakesToQuestions(selectedMistakes);

                              await _runMistakesQuiz(
                                questions: questions,
                                topic: '$subject Tekrarı',
                                isDark: isDarkMode,
                              );
                            },
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
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
    Color cardColor = isDarkMode ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white.withOpacity(0.7); 
    Color subtitleColor = isDarkMode ? Colors.white60 : Colors.blueGrey;
    Color borderColor = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.white; 

    return Container(
      height: isWide ? 100 : 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : color.withOpacity(0.1), 
            blurRadius: 10, 
            offset: const Offset(0, 5)
          ),
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
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
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
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
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget background = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E14),
                  Color(0xFF161B22),
                ])
            : null,
        color: isDarkMode ? null : const Color.fromARGB(255, 224, 247, 250),
      ),
    );

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
      bottomNavigationBar: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
        tween: Tween<double>(end: isDarkMode ? 1.0 : 0.0),
        builder: (context, t, child) {
          final Color navBarBgColor = Color.lerp(Colors.white.withOpacity(0.9), const Color(0xFF161B22).withOpacity(0.8), t)!;
          final Color shadowColor = Color.lerp(Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.4), t)!;
          final Color borderColor = Color.lerp(Colors.transparent, Colors.white.withOpacity(0.1), t)!;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: navBarBgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: shadowColor, blurRadius: 15, offset: const Offset(0, -5)),
                  ],
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: NavigationBar(
                  height: 80,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  destinations: [
                    _buildNavDest(Icons.home_outlined, Icons.home, 0, t),
                    _buildNavDest(Icons.book_outlined, Icons.book, 1, t),
                    _buildNavDest(Icons.bar_chart_outlined, Icons.bar_chart, 2, t),
                    _buildNavDest(Icons.person_outline, Icons.person, 3, t),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  NavigationDestination _buildNavDest(IconData icon, IconData activeIcon, int idx, double t) {
    final inactiveColor = Color.lerp(Colors.blueGrey.shade400, Colors.grey.shade600, t)!;
    final activeColor = Color.lerp(const Color(0xFF0D9488), const Color(0xFF448AFF), t)!;

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
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      label: '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YANLIŞLAR MENÜSÜ WİDGET'I
// ─────────────────────────────────────────────────────────────────────────────

class _MistakesMenuContent extends StatefulWidget {
  final bool isDarkMode;
  final Color titleColor;
  final Color subtitleColor;
  final Future<List<Map<String, dynamic>>> Function() getMistakes;
  final List<Question> Function(List<Map<String, dynamic>>) convertToQuestions;
  final VoidCallback onCheckCelebrate;
  final void Function(BuildContext, List<Map<String, dynamic>>) onShowSubjectList;

  // ── YENİ callback'ler ──
  final Future<int?> Function({
    required int maxCount,
    required bool isDark,
    required String title,
    required String subtitle,
  }) showQuestionCountPicker;


  final Future<void> Function({
    required List<Question> questions,
    required String topic,
    required bool isDark,
  }) runMistakesQuiz;

  const _MistakesMenuContent({
    required this.isDarkMode,
    required this.titleColor,
    required this.subtitleColor,
    required this.getMistakes,
    required this.convertToQuestions,
    required this.onCheckCelebrate,
    required this.onShowSubjectList,
    required this.showQuestionCountPicker,
    required this.runMistakesQuiz,
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF0D1117).withOpacity(0.75) : Colors.white.withOpacity(0.85),
            border: widget.isDarkMode ? Border(top: BorderSide(color: Colors.white.withOpacity(0.1))) : null,
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
                      color: widget.isDarkMode ? Colors.white24 : Colors.grey.shade400, 
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
                    // ── KARIŞIK TEKRAR ──
                    Expanded(
                      child: _buildModernCard(
                        context, 
                        title: "Karışık\nTekrar", 
                        icon: Icons.shuffle_rounded, 
                        color: Colors.purple, 
                        subtitle: "Rastgele Sınav",
                        onTap: () async {
                          // Sheet'i kapat
                          Navigator.pop(context);

                          if (_mistakes == null || _mistakes!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Henüz yanlışın yok! Harikasın 🎉"))
                            );
                            return;
                          }

                          // ── YENİ: Soru sayısı seç ──
                          final picked = await widget.showQuestionCountPicker(
                            maxCount: _mistakes!.length,
                            isDark: widget.isDarkMode,
                            title: 'Karışık Tekrar',
                            subtitle: 'Kaç soru çözmek istiyorsun?',
                          );
                          if (picked == null) return;

                          final shuffled =
                              List<Map<String, dynamic>>.from(_mistakes!)
                                ..shuffle();
                          final selectedMistakes =
                              shuffled.take(picked).toList();
                          final questions =
                              widget.convertToQuestions(selectedMistakes);

                          await widget.runMistakesQuiz(
                            questions: questions,
                            topic: 'Karışık Yanlış Tekrarı',
                            isDark: widget.isDarkMode,
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ── KONU BAZLI ──
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
    Color cardColor = widget.isDarkMode ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white.withOpacity(0.7); 
    Color subtitleColor = widget.isDarkMode ? Colors.white60 : Colors.blueGrey;
    Color borderColor = widget.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.white; 

    return Container(
      height: isWide ? 100 : 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.2) : color.withOpacity(0.1), 
            blurRadius: 10, 
            offset: const Offset(0, 5)
          ),
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
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
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
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
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
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
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD EKRANI
// ─────────────────────────────────────────────────────────────────────────────

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

                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const OfflineManagerScreen()));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.download_rounded, color: Colors.white),
                              ),
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
              ],
            ),
          ),
          
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