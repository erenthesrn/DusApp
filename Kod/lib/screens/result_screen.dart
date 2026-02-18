// lib/screens/result_screen.dart — v2
//
// DEĞİŞİKLİKLER:
//  • _updateStreakAndStats() artık (streak, isNewDay) çiftini döndürür
//  • Banner sadece lastStudyDate != today olduğunda gösterilir
//  • NotificationQueue.enqueueStreak'e isNewDay parametresi iletilir

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';
import '../services/achievement_service.dart';
import '../services/notification_queue.dart';
import '../services/theme_provider.dart';
import '../services/mistakes_service.dart';
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
  final bool isOfflineMode;
  final bool isFromSaved;

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
    this.isFromSaved = false,
    this.isOfflineMode = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (!widget.isOfflineMode && !widget.isFromSaved) {
        await _triggerNotificationSequence();
      } else {
        debugPrint(
          'Bildirim atlandı. (Offline: ${widget.isOfflineMode}, '
          'Kayıtlı: ${widget.isFromSaved})',
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANA SIRALAMA MANTIĞI
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _triggerNotificationSequence() async {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    // 1️⃣  Firebase güncelle → streak sayısı + yeni gün mü?
    final result = await _updateStreakAndStats();
    final int newStreak = result.$1;
    final bool isNewDay = result.$2;    // 🆕 yeni gün kontrolü

    // 2️⃣  Streak bildirimi — SADECE yeni günde
    if (mounted) {
      NotificationQueue.instance.enqueueStreak(
        context: context,
        streakDays: newStreak,
        isNewDay: isNewDay,             // 🆕
        isDarkMode: isDarkMode,
      );
    }

    // 3️⃣  Achievement bildirimleri — her zaman (seri bittikten sonra)
    if (mounted) {
      NotificationQueue.instance.enqueueAchievement(() async {
        if (!mounted) return;
        AchievementService.instance.incrementCategory(
          context,
          widget.topic,
          widget.correctCount,
        );
        AchievementService.instance.checkTimeAndScore(
          context,
          widget.score,
          100,
          widget.correctCount,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIREBASE GÜNCELLEME
  // Dönüş: (yeniStreak, isNewDay)
  //   isNewDay → lastStudyDate bugün değildi (yani seri yeni arttı)
  // ─────────────────────────────────────────────────────────────────────────

  Future<(int, bool)> _updateStreakAndStats() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ Kullanıcı oturum açmamış');
      return (0, false);
    }

    try {
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      DocumentSnapshot doc = await userDocRef.get();
      if (!doc.exists) {
        debugPrint('⚠️ Kullanıcı dokümanı bulunamadı');
        return (0, false);
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      final String today = DateTime.now().toIso8601String().split('T')[0];
      final String lastStudyDate = data['lastStudyDate'] ?? '';
      final int currentStreak = data['streak'] ?? 0;

      int newStreak = currentStreak;
      // 🆕 Bugün zaten çalışıldıysa isNewDay = false → banner GÖSTERILMEZ
      final bool isNewDay = lastStudyDate != today;

      if (isNewDay) {
        if (lastStudyDate.isNotEmpty) {
          final dateToday = DateTime.parse(today);
          final dateLast = DateTime.parse(lastStudyDate);
          final diff = dateToday.difference(dateLast).inDays;
          newStreak = (diff == 1) ? currentStreak + 1 : 1;
        } else {
          newStreak = 1; // İlk defa çalışıyor
        }
      }
      // isNewDay == false ise newStreak değişmez (aynı gün ikinci test)

      final String safeTopic = widget.topic.trim();

      await userDocRef.update({
        'lastStudyDate': today,
        'streak': newStreak,
        'totalSolved': FieldValue.increment(widget.questions.length),
        'totalCorrect': FieldValue.increment(widget.correctCount),
        'dailySolved': FieldValue.increment(widget.questions.length),
        'stats.dailyHistory.$today':
            FieldValue.increment(widget.questions.length),
        'stats.subjects.$safeTopic.total':
            FieldValue.increment(widget.questions.length),
        'stats.subjects.$safeTopic.correct':
            FieldValue.increment(widget.correctCount),
      });

      // Yanlışları kaydet
      final List<Map<String, dynamic>> mistakesToSave = [];
      for (int i = 0; i < widget.questions.length; i++) {
        final bool isWrong = widget.userAnswers[i] != null &&
            widget.userAnswers[i] != widget.questions[i].answerIndex;
        if (isWrong) {
          final q = widget.questions[i];
          mistakesToSave.add({
            'id': q.id,
            'question': q.question,
            'options': q.options,
            'correctIndex': q.answerIndex,
            'userIndex': widget.userAnswers[i],
            'explanation': q.explanation,
            'topic': widget.topic,
            'testNo': widget.testNo,
            'questionIndex': q.id,
            'image_url': q.imageUrl,
            'date': DateTime.now().toIso8601String(),
          });
        }
      }
      if (mistakesToSave.isNotEmpty) {
        await MistakesService.addMistakes(mistakesToSave);
      }

      debugPrint(
        '🔥 Firebase güncellendi. Streak: $newStreak | '
        'İsNewDay: $isNewDay',
      );

      return (newStreak, isNewDay);
    } catch (e) {
      debugPrint('❌ İstatistik güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İnternet bağlantısı yok. '
                    'Veriler daha sonra senkronize edilecek.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return (0, false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD (değiştirilmedi — aynen korundu)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    Color textColor =
        isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    Color subTextColor = isDarkMode ? Colors.white60 : Colors.black54;

    Widget background = isDarkMode
        ? Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0E14), Color(0xFF161B22)],
              ),
            ),
          )
        : Container(color: const Color(0xFFF5F9FF));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.isOfflineMode ? 'Sınav Sonucu 📡' : 'Sınav Sonucu 📝',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: widget.isOfflineMode
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          background,
          SafeArea(
            child: Column(
              children: [
                _buildGlassCard(
                  isDark: isDarkMode,
                  margin: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '${widget.score}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: widget.score >= 70
                              ? (isDarkMode ? Colors.greenAccent : Colors.green)
                              : (isDarkMode
                                  ? Colors.orangeAccent
                                  : Colors.orange),
                        ),
                      ),
                      Text(
                        'PUAN',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: subTextColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Doğru', widget.correctCount,
                              Colors.green, isDarkMode),
                          _buildStatItem('Yanlış', widget.wrongCount,
                              Colors.red, isDarkMode),
                          _buildStatItem(
                              'Boş', widget.emptyCount, Colors.grey, isDarkMode),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cevap Anahtarı (İncelemek için tıkla)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: widget.questions.length,
                    itemBuilder: (context, index) {
                      int? userAnswer = widget.userAnswers[index];
                      int correctAnswer =
                          widget.questions[index].answerIndex;

                      Color bgColor;
                      Color txtColor = Colors.white;
                      Border? border;

                      if (userAnswer == null) {
                        bgColor = isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade300;
                        txtColor = isDarkMode
                            ? Colors.white38
                            : Colors.black54;
                      } else if (userAnswer == correctAnswer) {
                        bgColor = isDarkMode
                            ? Colors.green.withOpacity(0.2)
                            : Colors.green;
                        border = isDarkMode
                            ? Border.all(
                                color:
                                    Colors.greenAccent.withOpacity(0.5))
                            : null;
                        txtColor = isDarkMode
                            ? Colors.greenAccent
                            : Colors.white;
                      } else {
                        bgColor = isDarkMode
                            ? Colors.red.withOpacity(0.2)
                            : Colors.red;
                        border = isDarkMode
                            ? Border.all(
                                color: Colors.redAccent.withOpacity(0.5))
                            : null;
                        txtColor = isDarkMode
                            ? Colors.redAccent
                            : Colors.white;
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                isTrial: false,
                                topic: widget.topic,
                                testNo: widget.testNo,
                                questions: widget.questions,
                                userAnswers: widget.userAnswers,
                                initialIndex: index,
                                isReviewMode: true,
                                useOffline: widget.isOfflineMode,
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
                            '${index + 1}',
                            style: TextStyle(
                              color: txtColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home_rounded, size: 22),
                      label: const Text(
                        'Listeye Dön',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        elevation: isDarkMode ? 0 : 4,
                        shadowColor: isDarkMode
                            ? Colors.transparent
                            : Colors.blue.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: isDarkMode
                              ? BorderSide(
                                  color: Colors.white.withOpacity(0.1))
                              : BorderSide.none,
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

  Widget _buildStatItem(
      String label, int count, Color color, bool isDark) {
    Color displayColor =
        isDark && color != Colors.grey ? color.withOpacity(0.8) : color;
    if (isDark && color == Colors.green) displayColor = Colors.greenAccent;
    if (isDark && color == Colors.red) displayColor = Colors.redAccent;

    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.robotoMono(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: displayColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    required bool isDark,
    EdgeInsetsGeometry? margin,
  }) {
    if (!isDark) {
      return Container(
        margin: margin,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: child,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
