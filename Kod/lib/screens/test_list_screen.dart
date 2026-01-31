// lib/screens/test_list_screen.dart
import 'package:flutter/material.dart';
import 'quiz_screen.dart';
import '../services/quiz_service.dart'; // 🔥 Servisimiz

class TestListScreen extends StatefulWidget {
  final String topic; // Örn: "Anatomi"
  final Color themeColor; // Örn: Colors.orange

  const TestListScreen({
    super.key, 
    required this.topic, 
    required this.themeColor
  });

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  // 💾 Çözülen testlerin numaralarını burada tutacağız
  Set<int> _completedTestNumbers = {}; 

  @override
  void initState() {
    super.initState();
    _loadTestStatus(); // Sayfa açılınca durumları kontrol et
  }

  // --- HANGİ TESTLER ÇÖZÜLMÜŞ KONTROL ET ---
  Future<void> _loadTestStatus() async {
    Set<int> completed = {};
    // 1'den 50'ye kadar olan testleri kontrol et
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
    // Başlıktaki emojileri temizleyelim
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
          // --- KOLAY SEVİYE (Test 1-8) ---
          _buildSectionHeader("Kolay Seviye", Colors.green),
          _buildTestGrid(
            count: 8, 
            startNumber: 1, // 1'den başla
            color: Colors.green
          ),
          
          _buildDivider(),

          // --- ORTA SEVİYE (Test 9-16) ---
          _buildSectionHeader("Orta Seviye", Colors.orange),
          _buildTestGrid(
            count: 8, 
            startNumber: 9, // 9'dan başla
            color: Colors.orange
          ),

          _buildDivider(),

          // --- ZOR SEVİYE (Test 17-24) ---
          _buildSectionHeader("Zor Seviye", Colors.red),
          _buildTestGrid(
            count: 8, 
            startNumber: 17, // 17'den başla
            color: Colors.red
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- İNCE ŞERİT (DIVIDER) ---
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Divider(color: Colors.grey.withOpacity(0.3), thickness: 1),
    );
  }

  // --- BAŞLIK TASARIMI ---
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

  // --- TEST KUTULARI (GRID) ---
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
              // 🔥 Tıklama Mantığı
              if (isCompleted) {
                _showChoiceDialog(testNumber); // Çözüldüyse sor
              } else {
                _startQuiz(testNumber); // Çözülmediyse direkt başlat
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

  // ==========================================
  // 🔥 EKSİK OLAN FONKSİYONLAR BURAYA EKLENDİ
  // ==========================================

  // 1. TESTİ BAŞLATAN YARDIMCI
  Future<void> _startQuiz(int testNumber) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => QuizScreen(
        isTrial: false, 
        topic: widget.topic,      
        testNo: testNumber 
      ))
    );
    // Dönünce listeyi yenile
    _loadTestStatus();
  }

  // 2. SEÇİM DİYALOĞU
  void _showChoiceDialog(int testNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Test $testNumber Tamamlandı ✅"),
        content: const Text("Bu testi daha önce çözdün. Ne yapmak istersin?"),
        actions: [
          // SEÇENEK A: SONUCU GÖR
          TextButton.icon(
            icon: const Icon(Icons.visibility, color: Colors.blue),
            label: const Text("Puanımı Gör"),
            onPressed: () {
              Navigator.pop(context); 
              _showScoreSummary(testNumber); 
            },
          ),
          
          // SEÇENEK B: BAŞTAN BAŞLA
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

  // 3. PUAN ÖZET KARTI (GÜVENLİ VERSİYON)
  Future<void> _showScoreSummary(int testNumber) async {
    // Türü açıkça belirttik: Map<String, dynamic>?
    Map<String, dynamic>? result = await QuizService.getQuizResult(widget.topic, testNumber);
    
    if (!mounted || result == null) return;

    // 🔥 GÜVENLİ DÖNÜŞÜM: String hatası almamak için verileri önce buraya çekiyoruz.
    // .toString() ve .parse() kullanarak, gelen veri ne olursa olsun int'e çeviriyoruz.
    int score = int.tryParse(result['score'].toString()) ?? 0;
    int correct = int.tryParse(result['correct'].toString()) ?? 0;
    int wrong = int.tryParse(result['wrong'].toString()) ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(child: Text("Test $testNumber Sonucu 🏆")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Artık burada 'score' değişkenini güvenle kullanabiliriz
                color: score >= 70 ? Colors.green.shade100 : Colors.orange.shade100,
              ),
              child: Text(
                "$score",
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  color: score >= 70 ? Colors.green.shade800 : Colors.orange.shade800
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Puan", style: TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text("$correct", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                  const Text("Doğru", style: TextStyle(fontSize: 12))
                ]),
                Column(children: [
                  Text("$wrong", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
                  const Text("Yanlış", style: TextStyle(fontSize: 12))
                ]),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam"),
          )
        ],
      ),
    );
  }
}