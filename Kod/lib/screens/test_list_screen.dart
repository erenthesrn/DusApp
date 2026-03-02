// lib/screens/test_list_screen.dart - OFFLINE DESTEKLI

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';
import 'result_screen.dart'; 
import '../services/quiz_service.dart';
import '../services/offline_service.dart';

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
  late String _cleanTitle;
  bool _isDownloaded = false;

  // widget.topic → Firebase 'topic' field eşlemesi
  // question_uploader.dart'ta topic.toLowerCase() ile kaydediliyor
  static const Map<String, String> _topicKeyMap = {
    'Anatomi'       : 'anatomi',
    'Biyokimya'     : 'biyokimya',
    'Fizyoloji'     : 'fizyoloji',
    'Histoloji'     : 'histoloji',
    'Farmakoloji'   : 'farma',
    'Patoloji'      : 'patoloji',
    'Mikrobiyoloji' : 'mikrobiyo',
    'Biyoloji'      : 'biyoloji',
    'Cerrahi'       : 'cerrahi',
    'Endodonti'     : 'endo',
    'Periodontoloji': 'perio',
    'Ortodonti'     : 'orto',
    'Pedodonti'     : 'pedo',
    'Protetik'      : 'protetik',
    'Radyoloji'     : 'radyoloji',
    'Restoratif'    : 'resto',
  };

  String _getTopicKey(String topic) {
    for (final entry in _topicKeyMap.entries) {
      if (topic.contains(entry.key)) return entry.value;
    }
    // Fallback: küçük harfe çevir
    return topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ğüşıöç]'), '').trim();
  }

  @override
  void initState() {
    super.initState();
    
    _cleanTitle = widget.topic.replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), '').trim();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadTestStatus();
      _checkDownloadStatus();
    });
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTestStatus() async {
    List<int> completedList = await QuizService.getCompletedTests(widget.topic);
    if (mounted) {
      setState(() {
        _completedTestNumbers = completedList.toSet();
      });
    }
  }

  Future<void> _checkDownloadStatus() async {
    bool downloaded = await OfflineService.isTopicDownloaded(_cleanTitle);
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color appBarTitleColor = isDarkMode ? const Color(0xFFE2E8F0) : Colors.black87;

    Widget background = isDarkMode
      ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E14), Color(0xFF161B22)],
            )
          ),
        )
      : Container(color: const Color.fromARGB(255, 224, 247, 250));

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: Colors.transparent,
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
            child: Container(
              color: (isDarkMode ? const Color(0xFF0D1117) : Colors.white).withOpacity(0.5),
            ),
          ),
        ),
        actions: [
          if (_isDownloaded)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.download_done, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "Offline",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          background,

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

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
              
              _buildSliverSectionHeader("Kolay Seviye", Colors.green, isDarkMode, 0),
              _buildSliverTestGrid(count: 8, startNumber: 1, color: Colors.green, isDarkMode: isDarkMode, delayIndex: 1),
              
              _buildSliverDivider(isDarkMode, 2),
              
              _buildSliverSectionHeader("Orta Seviye", Colors.orange, isDarkMode, 3),
              _buildSliverTestGrid(count: 8, startNumber: 9, color: Colors.orange, isDarkMode: isDarkMode, delayIndex: 4),
              
              _buildSliverDivider(isDarkMode, 5),
              
              _buildSliverSectionHeader("Zor Seviye", Colors.red, isDarkMode, 6),
              _buildSliverTestGrid(count: 8, startNumber: 17, color: Colors.red, isDarkMode: isDarkMode, delayIndex: 7),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ],
      ),
    );
  }

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
            
            return _animatedWidget(
              index: delayIndex,
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
                  onLongPress: _isDownloaded ? () => _showOfflineDialog(testNumber) : null,
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

  void _showOfflineDialog(int testNumber) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              "Offline Mod",
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          ],
        ),
        content: Text(
          "Bu testi internetsiz çözmek ister misin?",
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.cloud_off),
            label: const Text("Offline Başlat"),
            onPressed: () {
              Navigator.pop(context);
              _startQuizOffline(testNumber);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startQuizOffline(int testNumber) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => QuizScreen(
        isTrial: false, 
        topic: widget.topic,      
        testNo: testNumber,
        useOffline: true,
      ))
    );
    _loadTestStatus();
  }

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

  // 🔥 GÜNCELLENDİ: Soruları Firebase 'questions' collection'ından çekiyor
  Future<void> _navigateToReview(int testNumber) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      // 1️⃣ user_answers, score vb. sonuç verisini getir
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

      List<int?> userAnswers = (result['user_answers'] as List)
          .map((e) => e as int?)
          .toList();

      // 2️⃣ widget.topic → Firebase topic key dönüşümü
      final String topicKey = _getTopicKey(widget.topic);

      // 3️⃣ Firebase 'questions' collection'ından soruları çek
      final QuerySnapshot questionsSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('topic', isEqualTo: topicKey)
          .where('testNo', isEqualTo: testNumber)
          .orderBy('questionIndex')
          .get();

      if (questionsSnapshot.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Sorular bulunamadı. (topic: $topicKey, test: $testNumber)"))
          );
        }
        return;
      }

      // 4️⃣ Firestore dokümanlarını Question modeline dönüştür
      final List<Question> testQuestions = questionsSnapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return Question.fromJson({
          'id'           : d['questionIndex'] ?? 0,
          'questionIndex': d['questionIndex'] ?? 0,
          'question'     : d['question']      ?? '',
          'options'      : d['options']       ?? [],
          'answerIndex'  : d['correctIndex']  ?? 0,  // uploader'da 'correctIndex' olarak kaydediliyor
          'explanation'  : d['explanation']   ?? '',
          'level'        : d['level']         ?? '',
          'testNo'       : d['testNo']        ?? testNumber,
          'image_url'    : d['image_url'],
        });
      }).toList();

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
              emptyCount: testQuestions.length - (
                int.parse(result['correct'].toString()) + 
                int.parse(result['wrong'].toString())
              ),
              score: int.parse(result['score'].toString()),
              isFromSaved: true,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("İnceleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bir hata oluştu: $e"))
        );
      }
    }
  }
}
