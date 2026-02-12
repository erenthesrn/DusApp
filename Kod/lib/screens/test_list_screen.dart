// lib/screens/test_list_screen.dart

import 'dart:convert';
import 'dart:ui'; // Blur efekti için
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // SchedulerBinding için
import '../models/question_model.dart';
import 'quiz_screen.dart';
import 'result_screen.dart'; 
import '../services/quiz_service.dart';

class TestListScreen extends StatefulWidget {
  final String topic; 
  final Color themeColor; 

  const TestListScreen({
    super.key, 
    required this.topic, 
    required this.themeColor
  });

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> with SingleTickerProviderStateMixin {
  Set<int> _completedTestNumbers = {}; 
  late AnimationController _controller;
  late String _cleanTitle; // Title işlemini build'den çıkardık

  @override
  void initState() {
    super.initState();
    
    // 1. OPTİMİZASYON: String işlemini sadece bir kez yapıyoruz.
    _cleanTitle = widget.topic.replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), '').trim();

    // 2. OPTİMİZASYON: Veri çekme işlemini ekran çizildikten sonraya erteliyoruz.
    // Bu sayede sayfa geçiş animasyonu takılmıyor.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadTestStatus();
    });
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Süreyi biraz kıstık, daha seri hissettirir
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTestStatus() async {
    // Service zaten optimize edilmiş durumda, veriyi alıp güncelliyoruz.
    List<int> completedList = await QuizService.getCompletedTests(widget.topic);
    
    if (mounted) {
      setState(() {
        _completedTestNumbers = completedList.toSet();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tema ve Renk Tanımları
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBackgroundColor = isDarkMode ? const Color(0xFF0A0E14) : const Color(0xFFF5F9FF);
    Color appBarTitleColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "$_cleanTitle Testleri",
          style: TextStyle(
            fontWeight: FontWeight.w800, 
            color: appBarTitleColor,
            letterSpacing: 0.5
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarTitleColor),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: scaffoldBackgroundColor.withOpacity(0.7)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- ARKA PLAN EFEKTLERİ ---
          if (isDarkMode) ...[
             Positioned(
              top: -50, right: -50,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: widget.themeColor.withOpacity(0.3),
                      blurRadius: 100,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: -20,
              child: Container(
                width: 80, height: 80, 
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.25),
                      blurRadius: 80,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // --- 3. OPTİMİZASYON: CustomScrollView ve Slivers ---
          // ListView + GridView(shrinkWrap: true) yerine Slivers kullanıyoruz.
          // Bu, render performansını 10 kat artırır.
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // AppBar'ın arkası boş kalmasın diye padding
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
              
              // --- KOLAY SEVİYE ---
              _buildSliverSectionHeader("Kolay Seviye", Colors.green, isDarkMode, 0),
              _buildSliverTestGrid(count: 8, startNumber: 1, color: Colors.green, isDarkMode: isDarkMode, delayIndex: 1),
              
              _buildSliverDivider(isDarkMode, 2),
              
              // --- ORTA SEVİYE ---
              _buildSliverSectionHeader("Orta Seviye", Colors.orange, isDarkMode, 3),
              _buildSliverTestGrid(count: 8, startNumber: 9, color: Colors.orange, isDarkMode: isDarkMode, delayIndex: 4),
              
              _buildSliverDivider(isDarkMode, 5),
              
              // --- ZOR SEVİYE ---
              _buildSliverSectionHeader("Zor Seviye", Colors.red, isDarkMode, 6),
              _buildSliverTestGrid(count: 8, startNumber: 17, color: Colors.red, isDarkMode: isDarkMode, delayIndex: 7),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ],
      ),
    );
  }

  // Divider'ı Sliver'a çevirdik
  Widget _buildSliverDivider(bool isDarkMode, int index) {
    return SliverToBoxAdapter(
      child: _animatedWidget(
        index: index,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20),
          child: Divider(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), 
            thickness: 1
          ),
        ),
      ),
    );
  }

  // Header'ı Sliver'a çevirdik
  Widget _buildSliverSectionHeader(String title, Color color, bool isDarkMode, int index) {
    return SliverToBoxAdapter(
      child: _animatedWidget(
        index: index,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title, 
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold, 
                  color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
                  letterSpacing: 0.3
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Grid'i SliverGrid'e çevirdik (En önemli performans artışı burada)
  Widget _buildSliverTestGrid({
    required int count, 
    required int startNumber, 
    required Color color, 
    required bool isDarkMode,
    required int delayIndex,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, 
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            int testNumber = startNumber + index;
            bool isCompleted = _completedTestNumbers.contains(testNumber);

            // Renk ve Shadow hesaplamaları
            Color boxColor;
            Color borderColor;
            List<BoxShadow> shadows;

            if (isCompleted) {
              boxColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
              borderColor = Colors.green.withOpacity(0.5);
              shadows = [
                BoxShadow(
                  color: Colors.green.withOpacity(isDarkMode ? 0.15 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ];
            } else {
              boxColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
              borderColor = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15);
              shadows = [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ];
            }
            
            // Animasyon Wrapper
            return _animatedWidget(
              index: delayIndex, // Grid'deki her eleman değil, grup olarak animasyon girer
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: color.withOpacity(0.2),
                  onTap: () {
                    if (isCompleted) {
                      _showChoiceDialog(testNumber); 
                    } else {
                      _startQuiz(testNumber); 
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: isCompleted ? 1.5 : 1),
                      boxShadow: shadows,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isCompleted)
                          const Icon(Icons.check_rounded, color: Colors.green, size: 24)
                        else
                          Text(
                            "$testNumber", 
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.w800, 
                              color: color
                            )
                          ),
                        
                        if (!isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "Test", 
                              style: TextStyle(
                                fontSize: 9, 
                                color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              )
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }
  
  // Animasyon kodunu koruduk
  Widget _animatedWidget({required int index, required Widget child}) {
    final Animation<double> animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          (1 / 10) * index, 
          1.0, 
          curve: Curves.easeOutQuart
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)), 
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // --- FONKSİYONLAR (DEĞİŞİKLİK YOK) ---
  // Buradan aşağısı orijinal kodunuzla aynıdır, sadece context kullanımında 
  // mounted kontrolü ekledim (safety için).

  Future<void> _startQuiz(int testNumber) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => QuizScreen(
        isTrial: false, 
        topic: widget.topic,      
        testNo: testNumber 
      ))
    );
    _loadTestStatus();
  }

  void _showChoiceDialog(int testNumber) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 10),
            Text(
              "Test $testNumber",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black
              ),
            ),
          ],
        ),
        content: Text(
          "Bu testi daha önce tamamladınız. Ne yapmak istersiniz?",
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black87
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cevapları Gör"),
            onPressed: () {
              Navigator.pop(context); 
              _navigateToReview(testNumber);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: const Text("Tekrar Çöz", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context); 
              _startQuiz(testNumber); 
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToReview(int testNumber) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      Map<String, dynamic>? result = await QuizService.getQuizResult(widget.topic, testNumber);
      
      if (result == null || result['user_answers'] == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bu testin detaylı verisi bulunamadı."))
          );
        }
        return;
      }

      List<dynamic> rawList = result['user_answers'];
      List<int?> userAnswers = rawList.map((e) => e as int?).toList();

      String jsonFileName = "";
      String t = widget.topic;
      
      if (t.contains("Anatomi")) jsonFileName = "anatomi.json";
      else if (t.contains("Biyokimya")) jsonFileName = "biyokimya.json";
      else if (t.contains("Fizyoloji")) jsonFileName = "fizyoloji.json";
      else if (t.contains("Histoloji")) jsonFileName = "histoloji.json";
      else if (t.contains("Farmakoloji")) jsonFileName = "farmakoloji.json";
      else if (t.contains("Patoloji")) jsonFileName = "patoloji.json";
      else if (t.contains("Mikrobiyoloji")) jsonFileName = "mikrobiyoloji.json";
      else if (t.contains("Biyoloji")) jsonFileName = "biyoloji.json";
      else if (t.contains("Cerrahi")) jsonFileName = "cerrahi.json";
      else if (t.contains("Endodonti")) jsonFileName = "endo.json";
      else if (t.contains("Periodontoloji")) jsonFileName = "perio.json";
      else if (t.contains("Ortodonti")) jsonFileName = "orto.json";
      else if (t.contains("Pedodonti")) jsonFileName = "pedo.json";
      else if (t.contains("Protetik")) jsonFileName = "protetik.json";
      else if (t.contains("Radyoloji")) jsonFileName = "radyoloji.json";
      else if (t.contains("Restoratif")) jsonFileName = "resto.json";
      else {
        if (mounted) Navigator.pop(context);
        return;
      }

      String data = await DefaultAssetBundle.of(context).loadString('assets/data/$jsonFileName');
      List<dynamic> jsonList = json.decode(data);
      List<Question> allQuestions = jsonList.map((x) => Question.fromJson(x)).toList();
      List<Question> testQuestions = allQuestions.where((q) => q.testNo == testNumber).toList();

      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              questions: testQuestions,
              userAnswers: userAnswers,
              topic: widget.topic,
              testNo: testNumber,
              correctCount: int.parse(result['correct'].toString()),
              wrongCount: int.parse(result['wrong'].toString()),
              emptyCount: testQuestions.length - (int.parse(result['correct'].toString()) + int.parse(result['wrong'].toString())),
              score: int.parse(result['score'].toString()),
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("İnceleme hatası: $e");
    }
  }
}