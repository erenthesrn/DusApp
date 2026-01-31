// lib/screens/result_screen.dart

import 'package:flutter/material.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart'; // İnceleme modunu açmak için lazım

class ResultScreen extends StatelessWidget {
  final List<Question> questions;
  final List<int?> userAnswers;
  final String topic;
  final int testNo;
  final int correctCount;
  final int wrongCount;
  final int emptyCount;
  final int score;

  const ResultScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.topic,
    required this.testNo,
    required this.correctCount,
    required this.wrongCount,
    required this.emptyCount,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("Sınav Sonucu 📝"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false, // Geri butonunu kaldırıyoruz
      ),
      body: Column(
        children: [
          // --- ÖZET KARTI ---
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Text(
                  "$score Puan",
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.bold, 
                    color: score >= 70 ? Colors.green : Colors.orange
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("Doğru", correctCount, Colors.green),
                    _buildStatItem("Yanlış", wrongCount, Colors.red),
                    _buildStatItem("Boş", emptyCount, Colors.grey),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Cevap Anahtarı (İncelemek için tıkla)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
          ),

          // --- SORU NUMARALARI GRID ---
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                int? userAnswer = userAnswers[index];
                int correctAnswer = questions[index].answerIndex;
                
                // Renk Belirleme
                Color bgColor;
                if (userAnswer == null) {
                  bgColor = Colors.grey.shade300; // Boş
                } else if (userAnswer == correctAnswer) {
                  bgColor = Colors.green; // Doğru
                } else {
                  bgColor = Colors.red; // Yanlış
                }

                return InkWell(
                  onTap: () {
                    // 🔥 İNCELEME MODU: Tıklanan soruya git
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizScreen(
                          isTrial: false,
                          topic: topic,
                          testNo: testNo,
                          
                          // 🔥 BU PARAMETRELER ÇOK ÖNEMLİ:
                          questions: questions, // Aynı soruları gönder
                          userAnswers: userAnswers, // Kullanıcının cevaplarını gönder
                          initialIndex: index, // Tıkladığı sorudan başla
                          isReviewMode: true, // İNCELEME MODUNU AÇ
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- ANA SAYFAYA DÖN BUTONU ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Tüm ekranları kapatıp Test Listesine dön
                  Navigator.pop(context); 
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home_rounded),
                label: const Text("Listeye Dön"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text("$count", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}