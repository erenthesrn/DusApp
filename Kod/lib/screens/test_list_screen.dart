// lib/screens/test_list_screen.dart

import 'dart:convert'; // JSON okumak için lazım
import 'package:flutter/material.dart';
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

class _TestListScreenState extends State<TestListScreen> {
  Set<int> _completedTestNumbers = {}; 

  @override
  void initState() {
    super.initState();
    _loadTestStatus(); 
  }

  Future<void> _loadTestStatus() async {
    Set<int> completed = {};
    for (int i = 1; i <= 50; i++) {
      var result = await QuizService.getQuizResult(widget.topic, i);
      if (result != null) {
        completed.add(i);
      }
    }
    if (mounted) {
      setState(() {
        _completedTestNumbers = completed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String cleanTitle = widget.topic.replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), '').trim();
    
    // 1. Tema Kontrolü
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 2. Renk Tanımları
    // Arkaplan: Koyu modda Siyah, Açık modda Mavi tonu
    final Color scaffoldBackgroundColor = isDarkMode ? Colors.black : const Color(0xFFE3F2FD);
    
    // AppBar Yazı Rengi: Koyu modda Beyaz, Açık modda Siyah
    final Color appBarTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("$cleanTitle Testleri"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: appBarTextColor, 
          fontSize: 20, 
          fontWeight: FontWeight.bold
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Kolay Seviye", Colors.green, isDarkMode),
          _buildTestGrid(count: 8, startNumber: 1, color: Colors.green, isDarkMode: isDarkMode),
          
          _buildDivider(isDarkMode),
          
          _buildSectionHeader("Orta Seviye", Colors.orange, isDarkMode),
          _buildTestGrid(count: 8, startNumber: 9, color: Colors.orange, isDarkMode: isDarkMode),
          
          _buildDivider(isDarkMode),
          
          _buildSectionHeader("Zor Seviye", Colors.red, isDarkMode),
          _buildTestGrid(count: 8, startNumber: 17, color: Colors.red, isDarkMode: isDarkMode),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Divider(
        color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3), 
        thickness: 1
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, color: color),
          const SizedBox(width: 8),
          Text(
            title, 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: color // Başlık rengi seviye rengiyle aynı kalsın (okunabilir)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildTestGrid({
    required int count, 
    required int startNumber, 
    required Color color, 
    required bool isDarkMode
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, 
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, 
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        int testNumber = startNumber + index;
        bool isCompleted = _completedTestNumbers.contains(testNumber);

        // -- KUTU RENKLERİ --
        Color boxColor;
        Color borderColor;
        
        if (isCompleted) {
          // Tamamlanmışsa: Koyu modda koyu yeşil, açık modda açık yeşil
          boxColor = isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50;
          borderColor = Colors.green;
        } else {
          // Tamamlanmamışsa: Koyu modda Koyu Gri (Surface), Açık modda Beyaz
          boxColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
          borderColor = isDarkMode ? Colors.white12 : color.withOpacity(0.3);
        }

        // -- YAZI RENKLERİ --
        Color numberColor = isCompleted ? Colors.green : color;
        
        Color labelColor; 
        if (isCompleted) {
          labelColor = isDarkMode ? Colors.greenAccent : Colors.green.shade700;
        } else {
          labelColor = isDarkMode ? Colors.grey.shade400 : Colors.grey[600]!;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
                color: boxColor, // Dinamik Kutu Rengi
                border: Border.all(
                  color: borderColor, // Dinamik Kenarlık
                  width: 2
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05), 
                    blurRadius: 4, 
                    offset: const Offset(0, 2)
                  )
                ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCompleted)
                    const Icon(Icons.check_circle, color: Colors.green, size: 28)
                  else
                    Text(
                      "$testNumber", 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: numberColor)
                    ),
                  Text(
                    isCompleted ? "Bitti" : "Test", 
                    style: TextStyle(
                      fontSize: 10, 
                      color: labelColor,
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal
                    )
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- FONKSİYONLAR ---

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Koyu mod uyumlu Dialog
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          "Test $testNumber Tamamlandı ✅",
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
          ),
        ),
        content: Text(
          "Ne yapmak istersin?",
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87
          ),
        ),
        actions: [
          // 1. SEÇENEK: SONUCU İNCELE
          TextButton.icon(
            icon: const Icon(Icons.receipt_long, color: Colors.blue),
            label: const Text("Cevapları İncele"),
            onPressed: () {
              Navigator.pop(context); 
              _navigateToReview(testNumber);
            },
          ),
          
          // 2. SEÇENEK: BAŞTAN BAŞLA
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text("Baştan Çöz", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      Map<String, dynamic>? result = await QuizService.getQuizResult(widget.topic, testNumber);
      if (result == null || result['user_answers'] == null) {
        if (mounted) Navigator.pop(context); 
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