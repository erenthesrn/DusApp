// lib/screens/test_list_screen.dart
import 'dart:convert'; // JSON okumak için lazım
import 'package:flutter/material.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';
import 'result_screen.dart'; // 🔥 ResultScreen'e gideceğimiz için lazım
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

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: Text("$cleanTitle Testleri"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Kolay Seviye", Colors.green),
          _buildTestGrid(count: 8, startNumber: 1, color: Colors.green),
          _buildDivider(),
          _buildSectionHeader("Orta Seviye", Colors.orange),
          _buildTestGrid(count: 8, startNumber: 9, color: Colors.orange),
          _buildDivider(),
          _buildSectionHeader("Zor Seviye", Colors.red),
          _buildTestGrid(count: 8, startNumber: 17, color: Colors.red),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Divider(color: Colors.grey.withOpacity(0.3), thickness: 1),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTestGrid({required int count, required int startNumber, required Color color}) {
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
                color: isCompleted ? Colors.green.shade50 : Colors.white,
                border: Border.all(
                  color: isCompleted ? Colors.green : color.withOpacity(0.3),
                  width: 2
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)
                    ),
                  Text(
                    isCompleted ? "Bitti" : "Test", 
                    style: TextStyle(
                      fontSize: 10, 
                      color: isCompleted ? Colors.green.shade700 : Colors.grey[600],
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
        title: Text("Test $testNumber Tamamlandı ✅"),
        content: const Text("Ne yapmak istersin?"),
        actions: [
          // 🔥 1. SEÇENEK: SONUCU İNCELE (ResultScreen'e gider)
          TextButton.icon(
            icon: const Icon(Icons.receipt_long, color: Colors.blue),
            label: const Text("Cevapları İncele"),
            onPressed: () {
              Navigator.pop(context); 
              // Soruları ve cevapları yükleyip ResultScreen'e giden fonksiyonu çağır
              _navigateToReview(testNumber);
            },
          ),
          
          // 🔥 2. SEÇENEK: BAŞTAN BAŞLA
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Baştan Çöz"),
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

  // 🔥 YENİ VE ÖNEMLİ: GEÇMİŞ TESTİ İNCELEMEK İÇİN YÜKLEME YAPAN FONKSİYON
  Future<void> _navigateToReview(int testNumber) async {
    // Yükleniyor göster
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      // 1. Veritabanından kayıtlı sonucu çek
      Map<String, dynamic>? result = await QuizService.getQuizResult(widget.topic, testNumber);
      if (result == null || result['user_answers'] == null) {
        if (mounted) Navigator.pop(context); // Loading kapat
        return;
      }

      // 2. 'user_answers' listesini düzelt (JSON'dan List<int?>'e çevir)
      List<dynamic> rawList = result['user_answers'];
      List<int?> userAnswers = rawList.map((e) => e as int?).toList();

      // 3. Soruları JSON dosyasından yükle (Aynı QuizScreen'deki mantık)
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
      
      // Sadece o testin sorularını al
      List<Question> testQuestions = allQuestions.where((q) => q.testNo == testNumber).toList();

      // Loading kapat
      if (mounted) Navigator.pop(context);

      // 4. ResultScreen'e git
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
      if (mounted) Navigator.pop(context); // Hata olursa loading kapat
      debugPrint("İnceleme hatası: $e");
    }
  }

  // Eski özet fonksiyonunu silebiliriz veya 'Puanımı Gör' için tutabiliriz. 
  // Ama yukarıdaki 'Cevapları İncele' çok daha işlevsel.
  Future<void> _showScoreSummary(int testNumber) async {
    // ... (Eski kod burada kalabilir ama _showChoiceDialog artık bunu kullanmıyor)
  }
}