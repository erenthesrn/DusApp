// lib/screens/result_screen.dart

import 'dart:ui'; // 🔥 CAM EFEKTİ İÇİN
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Premium Fontlar
import '../models/question_model.dart';
import 'quiz_screen.dart';
import '../services/achievement_service.dart';
import '../services/theme_provider.dart'; // 🔥 TEMA KONTROLÜ
import '../services/mistakes_service.dart'; // ✅ EKLENDİ: Yanlışları kaydetmek için şart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultScreen extends StatefulWidget {
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
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  
  @override
  void initState() {
    super.initState();
    
    // Rozet ve İstatistik işlemleri (Ekran çizildikten hemen sonra çalışır)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AchievementService.instance.incrementCategory(
        context, 
        widget.topic,
        widget.correctCount, 
      );

      AchievementService.instance.checkTimeAndScore(
        context, 
        widget.score, 
        100, 
        widget.correctCount 
      );
      
      // Firebase Güncellemelerini Başlat
      _updateStreakAndStats();
    });
  }

  // 🔥 İSTATİSTİK GÜNCELLEME VE YANLIŞLARI KAYDETME FONKSİYONU
  Future<void> _updateStreakAndStats() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    
    try {
      DocumentSnapshot doc = await userDocRef.get();
      if (!doc.exists) return;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Tarih Formatı: YYYY-MM-DD (Grafikler için bu format şart)
      String today = DateTime.now().toIso8601String().split('T')[0];
      
      String lastStudyDate = data['lastStudyDate'] ?? ""; 
      int currentStreak = data['streak'] ?? 0;
      int newStreak = currentStreak;

      // --- Streak (Seri) Mantığı ---
      if (lastStudyDate != today) {
        if (lastStudyDate.isNotEmpty) {
           DateTime dateToday = DateTime.parse(today);
           DateTime dateLast = DateTime.parse(lastStudyDate);
           int diff = dateToday.difference(dateLast).inDays;

           if (diff == 1) {
             newStreak++; 
           } else {
             newStreak = 1; 
           }
        } else {
          newStreak = 1; 
        }
      }

      // --- ÖNEMLİ KISIM BAŞLIYOR: Veritabanı Güncelleme ---
      
      // Konu ismini güvenli hale getir
      String safeTopic = widget.topic.trim(); 

      // 1. GENEL SAYAÇLARI GÜNCELLE (Burası kalsın, çünkü QuizService burayı yapmıyor olabilir)
      await userDocRef.update({
        'lastStudyDate': today,           
        'streak': newStreak,              
        'totalSolved': FieldValue.increment(widget.questions.length), 
        'totalCorrect': FieldValue.increment(widget.correctCount),    
        'dailySolved': FieldValue.increment(widget.questions.length), 

        // HAFTALIK GRAFİK İÇİN
        'stats.dailyHistory.$today': FieldValue.increment(widget.questions.length),

        // DERS BAZLI GRAFİK İÇİN
        'stats.subjects.$safeTopic.total': FieldValue.increment(widget.questions.length),
        'stats.subjects.$safeTopic.correct': FieldValue.increment(widget.correctCount),
      });

      // 🚨 DÜZELTME: SONUÇ KARTI KAYDINI KALDIRDIK 🚨
      // Bu kısım AnalysisScreen'de çift görünüme sebep oluyordu çünkü
      // büyük ihtimalle QuizService veya önceki ekran bunu zaten kaydediyor.
      /*
      String uniqueResultId = "${widget.topic}_${widget.testNo}_${DateTime.now().millisecondsSinceEpoch}";
      await userDocRef.collection('results').doc(uniqueResultId).set({
        'topic': widget.topic,
        'testNo': widget.testNo,
        'score': widget.score,
        'correct': widget.correctCount,
        'wrong': widget.wrongCount,
        'empty': widget.emptyCount,
        'total': widget.questions.length,
        'user_answers': widget.userAnswers, 
        'date': DateTime.now().toIso8601String(), 
        'timestamp': FieldValue.serverTimestamp(), 
      });
      */

      // 5. YANLIŞLARI BULUT "MISTAKES" KOLEKSİYONUNA EKLE
      // (Burası kalmalı, çünkü yanlışları kaydetmek önemli ve QuizService yapmıyor olabilir)
      List<Map<String, dynamic>> mistakesToSave = [];
      
      for (int i = 0; i < widget.questions.length; i++) {
        // Yanlış cevaplanmış soruları tespit et
        bool isWrong = widget.userAnswers[i] != null && widget.userAnswers[i] != widget.questions[i].answerIndex;
        
        if (isWrong) {
          var q = widget.questions[i];
          mistakesToSave.add({
            'id': q.id,
            'question': q.question,
            'options': q.options,
            'correctIndex': q.answerIndex,
            'userIndex': widget.userAnswers[i], // İşaretlediği yanlış şık
            'explanation': q.explanation,
            'topic': widget.topic,
            'testNo': widget.testNo,
            'questionIndex':q.id,
            'image_url': q.imageUrl,
            'date': DateTime.now().toIso8601String(),
          });
        }
      }

      if (mistakesToSave.isNotEmpty) {
        // Yeni yazdığımız servisi kullanarak toplu ekleme yap
        await MistakesService.addMistakes(mistakesToSave);
        debugPrint("✅ ${mistakesToSave.length} yanlış soru Firebase'e kaydedildi.");
      }
      
      debugPrint("🔥 Firebase Güncellendi: Streak ve Yanlışlar işlendi. Sonuç kartı kaydı atlandı (Duplicate önleme).");

    } catch (e) {
      debugPrint("❌ İstatistik güncelleme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 TEMA AYARLARI
    final isDarkMode = ThemeProvider.instance.isDarkMode;
    
    // Renk Paleti
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    Color subTextColor = isDarkMode ? Colors.white60 : Colors.black54;

    // Arka Plan Gradient
    Widget background = isDarkMode 
      ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0E14), // Derin Uzay Siyahı
                Color(0xFF161B22), // Antrasit
              ]
            )
          ),
        )
      : Container(color: const Color(0xFFF5F9FF));

    return Scaffold(
      backgroundColor: Colors.transparent, 
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text("Sınav Sonucu 📝", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        automaticallyImplyLeading: false, 
        centerTitle: true,
      ),
      body: Stack(
        children: [
          background, // 1. Katman: Zemin 

          // 2. Katman: İçerik
          SafeArea( 
            child: Column(
              children: [
                // --- ÖZET KARTI ---
                _buildGlassCard(
                  isDark: isDarkMode,
                  margin: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Skor
                      Text(
                        "${widget.score}", 
                        style: GoogleFonts.robotoMono( 
                          fontSize: 64, 
                          fontWeight: FontWeight.bold, 
                          color: widget.score >= 70 
                            ? (isDarkMode ? Colors.greenAccent : Colors.green) 
                            : (isDarkMode ? Colors.orangeAccent : Colors.orange)
                        ),
                      ),
                      Text(
                        "PUAN", 
                        style: GoogleFonts.inter(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold, 
                          color: subTextColor,
                          letterSpacing: 2
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // İstatistikler Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem("Doğru", widget.correctCount, Colors.green, isDarkMode),
                          _buildStatItem("Yanlış", widget.wrongCount, Colors.red, isDarkMode),
                          _buildStatItem("Boş", widget.emptyCount, Colors.grey, isDarkMode),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Cevap Anahtarı (İncelemek için tıkla)", 
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: subTextColor, fontSize: 14)
                    ),
                  ),
                ),

                // --- SORU NUMARALARI GRID ---
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: widget.questions.length, 
                    itemBuilder: (context, index) {
                      int? userAnswer = widget.userAnswers[index]; 
                      int correctAnswer = widget.questions[index].answerIndex;
                      
                      Color bgColor;
                      Color txtColor = Colors.white;
                      Border? border;

                      // Grid Renk Mantığı
                      if (userAnswer == null) {
                        // Boş
                        bgColor = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade300; 
                        txtColor = isDarkMode ? Colors.white38 : Colors.black54;
                      } else if (userAnswer == correctAnswer) {
                        // Doğru
                        bgColor = isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green; 
                        border = isDarkMode ? Border.all(color: Colors.greenAccent.withOpacity(0.5)) : null;
                        txtColor = isDarkMode ? Colors.greenAccent : Colors.white;
                      } else {
                        // Yanlış
                        bgColor = isDarkMode ? Colors.red.withOpacity(0.2) : Colors.red; 
                        border = isDarkMode ? Border.all(color: Colors.redAccent.withOpacity(0.5)) : null;
                        txtColor = isDarkMode ? Colors.redAccent : Colors.white;
                      }

                      return InkWell(
                        onTap: () {
                          // İnceleme moduna git (QuizScreen güncellendiği için çalışır)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                isTrial: false,
                                topic: widget.topic,
                                testNo: widget.testNo,
                                questions: widget.questions,
                                userAnswers: widget.userAnswers, // 🔥 Cevaplar gidiyor
                                initialIndex: index, // 🔥 Tıklanan soru açılacak
                                isReviewMode: true, // 🔥 İnceleme modu aktif
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: border,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(color: txtColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // --- ANA SAYFAYA DÖN BUTONU ---
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.home_rounded, size: 22),
                      label: const Text("Listeye Dön", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? const Color(0xFF1E3A8A) : const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        elevation: isDarkMode ? 0 : 4,
                        shadowColor: isDarkMode ? Colors.transparent : Colors.blue.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: isDarkMode ? BorderSide(color: Colors.white.withOpacity(0.1)) : BorderSide.none
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGETLAR ---

  Widget _buildStatItem(String label, int count, Color color, bool isDark) {
    Color displayColor = isDark && color != Colors.grey ? color.withOpacity(0.8) : color;
    if (isDark && color == Colors.green) displayColor = Colors.greenAccent;
    if (isDark && color == Colors.red) displayColor = Colors.redAccent;

    return Column(
      children: [
        Text(
          "$count", 
          style: GoogleFonts.robotoMono(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            color: displayColor
          )
        ),
        Text(
          label, 
          style: GoogleFonts.inter(
            fontSize: 12, 
            color: isDark ? Colors.white54 : Colors.grey[600],
            fontWeight: FontWeight.w600
          )
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, required bool isDark, EdgeInsetsGeometry? margin}) {
    if (!isDark) {
      // Aydınlık Mod: Düz Beyaz Kart
      return Container(
        margin: margin,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: child,
      );
    }

    // Karanlık Mod: Buzlu Cam
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22).withOpacity(0.6), // Saydam Antrasit
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}