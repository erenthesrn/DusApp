// lib/screens/quiz_screen.dart
import 'dart:async';
import 'dart:convert'; // 🔥 JSON Çözmek için şart
import 'package:flutter/material.dart';
import '../models/question_model.dart'; 
import '../services/quiz_service.dart';
import 'result_screen.dart'; // 🔥 Sonuç ekranını import ettik
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/mistakes_service.dart';

class QuizScreen extends StatefulWidget {
  final bool isTrial; // Deneme mi?
  final int? fixedDuration; // Sabit süre
  final String? topic;   // Örn: "Anatomi"
  final int? testNo;     // Örn: 1
  
  // 🔥 YENİ EKLENEN PARAMETRELER (Virgüller düzeltildi)
  final List<Question>? questions; 
  final List<int?>? userAnswers; 
  final bool isReviewMode; 
  final int initialIndex; 

  const QuizScreen({
    super.key,
    required this.isTrial,
    this.fixedDuration,
    this.topic,   
    this.testNo,
    this.questions,    // 🔥
    this.userAnswers,  // 🔥
    this.isReviewMode = false, // Varsayılan: Hayır
    this.initialIndex = 0,     // Varsayılan: 0. soru
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // --- DEĞİŞKENLER ---
  List<Question> _questions = []; 
  bool _isLoading = true; 
  
  int _currentQuestionIndex = 0;
  late List<int?> _userAnswers; 

  Timer? _timer;
  int _seconds = 0;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    
    // 🔥 EĞER DIŞARIDAN SORU GELDİYSE (İNCELEME MODU)
    if (widget.questions != null && widget.userAnswers != null) {
      _questions = widget.questions!;
      _userAnswers = widget.userAnswers!;
      _currentQuestionIndex = widget.initialIndex; // Tıklanan sorudan başla
      _isLoading = false;
      // İnceleme modunda zamanlayıcı başlatmıyoruz!
    } else {
      // NORMAL MOD: Soruları yükle
      _loadQuestions(); 
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- SORULARI JSON'DAN ÇEKME FONKSİYONU ---
  Future<void> _loadQuestions() async {
    try {
      String jsonFileName = ""; 
      
      String topicName = widget.topic ?? "";

      // 🔥 DERS EŞLEŞTİRME LİSTESİ
      if (topicName.contains("Anatomi")) {
        jsonFileName = "anatomi.json";
      } 
      else if (topicName.contains("Biyokimya")) {
        jsonFileName = "biyokimya.json";
      } 
      else if (topicName.contains("Fizyoloji")) {
        jsonFileName = "fizyoloji.json";
      }
      else if (topicName.contains("Histoloji")) {
        jsonFileName = "histoloji.json";
      }
      else if (topicName.contains("Farmakoloji")) { 
        jsonFileName = "farmakoloji.json";
      }
      else if (topicName.contains("Patoloji")) {
        jsonFileName = "patoloji.json";
      }
      else if (topicName.contains("Mikrobiyoloji")) {
        jsonFileName = "mikrobiyoloji.json";
      }
      else {
        throw Exception("DersTanimsiz"); 
      }
      
      debugPrint("📂 Açılacak Dosya: $jsonFileName");

      // 2. JSON dosyasını oku
      String data = await DefaultAssetBundle.of(context).loadString('assets/data/$jsonFileName');
      List<dynamic> jsonList = json.decode(data);

      // 3. Tüm soruları listeye çevir
      List<Question> allQuestions = jsonList.map((x) => Question.fromJson(x)).toList();
      List<Question> filteredQuestions = [];

      // 4. 🔥 FİLTRELEME
      if (widget.isTrial) {
        filteredQuestions = allQuestions;
      } else {
        if (widget.testNo != null) {
           filteredQuestions = allQuestions.where((q) => q.testNo == widget.testNo).toList();
        } else {
           filteredQuestions = allQuestions;
        }
      }

      // 5. EKRANI GÜNCELLE
      if (mounted) {
        setState(() {
          _questions = filteredQuestions;
          _userAnswers = List.filled(_questions.length, null); 
          _isLoading = false; 
        });

        if (_questions.isNotEmpty) {
           _initializeTimer();
        }
      }

    } catch (e) {
      debugPrint("🛑 BİLGİ: Dosya bulunamadı veya henüz eklenmedi ($e)");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _questions = []; 
        });
      }
    }
  }

  // --- 2. SAYAÇ MANTIĞI ---
  void _initializeTimer() {
    if (widget.isTrial) {
      if (widget.fixedDuration != null) {
        setState(() {
          _seconds = widget.fixedDuration! * 60;
        });
        _startTimer();
      } else {
        Future.delayed(Duration.zero, () => _showDurationPickerDialog());
      }
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.isReviewMode) return; // 🔥 İnceleme modunda sayaç çalışmaz

    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (widget.isTrial) {
          if (_seconds > 0) {
            _seconds--;
          } else {
            timer.cancel();
            _showFinishDialog(timeUp: true);
          }
        } else {
          _seconds++;
        }
      });
    });
  }

  // --- 3. DİĞER YARDIMCI FONKSİYONLAR ---

  Future<bool> _onWillPop() async {
    if (widget.isReviewMode) return true; // 🔥 İnceleme modundaysa direkt çık

    return (await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sınavdan Çık?"),
        content: const Text("Çıkarsan ilerlemen ve cevapların kaybolacak. Emin misin?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Hayır, Devam Et")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Evet, Çık"),
          ),
        ],
      ),
    )) ?? false;
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _showDurationPickerDialog() {
    // ... (Mevcut kod aynı kalıyor)
    final TextEditingController durationController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Hedef Süreni Belirle 🎯"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Bu denemeyi kaç dakikada bitirmeyi hedefliyorsun?"),
            const SizedBox(height: 20),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: "Dakika (Örn: 50)", border: OutlineInputBorder(), suffixText: "dk"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              if (durationController.text.isNotEmpty) {
                int minutes = int.tryParse(durationController.text) ?? 60;
                setState(() => _seconds = minutes * 60);
                Navigator.pop(context);
                _startTimer();
              }
            },
            child: const Text("Başlat"),
          ),
        ],
      ),
    );
  }

  void _selectOption(int index) {
    if (widget.isReviewMode) return; // 🔥 İnceleme modunda seçim yapılamaz

    setState(() {
      if (_userAnswers[_currentQuestionIndex] == index) {
        _userAnswers[_currentQuestionIndex] = null;
      } else {
        _userAnswers[_currentQuestionIndex] = index;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      // Son soruya gelindiğinde
      if (widget.isReviewMode) {
        Navigator.pop(context); // İncelemedeyse geri dön
      } else {
        _showFinishDialog(); // Normalse bitir
      }
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  void _showReportDialog(Question question) {
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Hata Bildir"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Bu soruda neyin yanlış olduğunu düşünüyorsunuz?"),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: "Örn: Cevap B olmalı çünkü...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            onPressed: () async {
              if (noteController.text.trim().isEmpty) return;

              Navigator.pop(context); // Pencereyi kapat
              
              // Kullanıcıya teşekkür mesajı göster
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Geri bildiriminiz için teşekkürler! İncelenecektir.")),
              );

              // 🔥 FIREBASE'E KAYDETME İŞLEMİ
              try {
                await FirebaseFirestore.instance.collection('question_reports').add({
                  'questionId': question.id,
                  'questionText': question.question, // Hangi soru olduğunu kolay bulman için
                  'userNote': noteController.text.trim(),
                  'userId': FirebaseAuth.instance.currentUser?.uid ?? "Anonim",
                  'reportedAt': FieldValue.serverTimestamp(),
                  'status': 'open', // 'open', 'resolved', 'rejected' gibi durumlar yönetebilirsin
                });
              } catch (e) {
                print("Rapor gönderilemedi: $e");
              }
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }
  void _showFinishDialog({bool timeUp = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(timeUp ? "Süre Doldu! ⌛" : "Sınavı Bitir?"),
        content: Text(timeUp ? "Süre bitti, sonuçların kaydedilecek." : "Sınavı bitirmek ve sonucunu kaydetmek istiyor musun?"),
        actions: [
          if (!timeUp)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Vazgeç"),
            ),
            
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              _timer?.cancel(); // Sayacı durdur

              List<Map<String, dynamic>> wrongQuestionsToSave = [];

              //Yanlışların kaydının tutulması

              for (int i = 0; i < _questions.length; i++) {
                // Eğer kullanıcı yanlış yaptıysa (boşlar dahil edilmeyebilir, tercihen sadece yanlışlar)
                if (_userAnswers[i] != _questions[i].answerIndex) {
                  wrongQuestionsToSave.add({
                    'id': _questions[i].id,
                    'question': _questions[i].question,
                    'options': _questions[i].options,
                    'correctIndex': _questions[i].answerIndex,
                    'userIndex': _userAnswers[i],
                    'subject': widget.topic ?? "Genel", // Dersi buradan alıyoruz
                    'explanation': _questions[i].explanation,
                    'date': DateTime.now().toIso8601String(),
                  });
                }
              }

              if (wrongQuestionsToSave.isNotEmpty) {
                await MistakesService.addMistakes(wrongQuestionsToSave);
              }

              // 1. PUAN HESAPLAMA 🧮
              int correct = 0;
              int wrong = 0;  
              int empty = 0;

              for (int i = 0; i < _questions.length; i++) {
                if (_userAnswers[i] == null) {
                  empty++;
                } else if (_userAnswers[i] == _questions[i].answerIndex) {
                  correct++;
                } else {
                  wrong++;
                }
              }
              if (!widget.isReviewMode) {
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  int totalSolvedNow = correct + wrong; // Boşları saymıyoruz, sadece işaretlenenler
                  int minutesSpent = (_seconds > 0 && !widget.isTrial) ? (_seconds ~/ 60) : 0; 
                  // Not: Deneme sınavında süre geriye saydığı için mantığı farklı kurabilirsin, 
                  // şimdilik normal modda geçen süreyi (dakika cinsinden) alıyoruz.

                  try {
                        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
                        final snapshot = await userDoc.get();
                        
                        int currentStreak = 0;
                        DateTime? lastStudyDate;

                        if (snapshot.exists && snapshot.data() != null) {
                          final data = snapshot.data() as Map<String, dynamic>;
                          currentStreak = data['streak'] ?? 0;
                          
                          if (data['lastStudyDate'] != null) {
                            lastStudyDate = (data['lastStudyDate'] as Timestamp).toDate();
                          }
                        }

                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day); 
                        
                        // İlk defa çalışıyorsa
                        if (lastStudyDate == null) {
                          currentStreak = 1;
                        } else {
                          final lastDay = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);
                          final difference = today.difference(lastDay).inDays;

                          if (difference == 1) {
                            currentStreak++; // Dün çalışmış, seriyi artır! 🚀
                          } else if (difference > 1) {
                            currentStreak = 1; // Ara vermiş, seriyi sıfırla (1 yap) 😢
                          }
                          // difference == 0 ise (Bugün zaten çalışmışsa) dokunma.
                        }

                        // Hepsini (Soru + Dakika + Seri + Tarih) tek seferde kaydet
                        await userDoc.update({
                          'totalSolved': FieldValue.increment(totalSolvedNow),
                          'totalMinutes': FieldValue.increment(minutesSpent),
                          'streak': currentStreak,
                          'lastStudyDate': FieldValue.serverTimestamp(),
                        });

                      } catch (e) {
                        debugPrint("Veri güncelleme hatası: $e");
                      }
                    }
                  }
              int score = 0;
              if (_questions.isNotEmpty) {
                 score = ((correct / _questions.length) * 100).toInt();
              }

              // 2. KAYDETME İŞLEMİ 💾
              if (!widget.isTrial && widget.topic != null && widget.testNo != null) {
                await QuizService.saveQuizResult(
                  topic: widget.topic!,
                  testNo: widget.testNo!,
                  score: score,
                  correctCount: correct,
                  wrongCount: wrong,
                  userAnswers: _userAnswers, // 🔥 YENİ: Listeyi servise gönderdik
                );
              }
              
              // 3. 🔥 SONUÇ EKRANINA GİT
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(
                      questions: _questions,
                      userAnswers: _userAnswers,
                      topic: widget.topic ?? "",
                      testNo: widget.testNo ?? 1,
                      correctCount: correct,
                      wrongCount: wrong,
                      emptyCount: empty,
                      score: score,
                    ),
                  ),
                );
              }
            },
            child: const Text("Bitir"),
          )
        ],
      ),
    );
  }

  void _showQuestionMap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Text("Soru Haritası", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _questions.length, 
                  itemBuilder: (context, index) {
                    bool isAnswered = _userAnswers[index] != null;
                    bool isCurrent = index == _currentQuestionIndex;
                    return GestureDetector(
                      onTap: () { Navigator.pop(context); setState(() => _currentQuestionIndex = index); },
                      child: Container(
                        decoration: BoxDecoration(color: isCurrent ? Colors.orange : (isAnswered ? const Color(0xFF1565C0) : Colors.grey[100]), borderRadius: BorderRadius.circular(12), border: isCurrent ? Border.all(color: Colors.orangeAccent, width: 2) : null),
                        alignment: Alignment.center,
                        child: Text("${index + 1}", style: TextStyle(color: (isCurrent || isAnswered) ? Colors.white : Colors.black54, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE3F2FD),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Bu test için soru bulunamadı.")),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD), 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(widget.isReviewMode ? Icons.arrow_back : Icons.close, color: Colors.grey),
            onPressed: () async {
               if (widget.isReviewMode) {
                 Navigator.pop(context); // İncelemedeyse geri
               } else {
                 if (await _onWillPop()) {
                   if (mounted) Navigator.of(context).pop();
                 }
               }
            },
          ),
          // 🔥 BAŞLIK: İncelemedeyse "İnceleme", değilse Sayaç
          title: widget.isReviewMode 
            ? const Text("Cevap İnceleme 👁️", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.isTrial ? Icons.hourglass_bottom : Icons.timer_outlined, size: 20, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_seconds), 
                  style: TextStyle(
                    color: widget.isTrial && _seconds < 60 ? Colors.red : const Color(0xFF1565C0), 
                    fontWeight: FontWeight.bold, 
                    fontSize: 18, 
                    letterSpacing: 1.5
                  )
                ),
              ],
            ),
          actions: [const SizedBox(width: 48)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6.0), 
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length, 
              backgroundColor: Colors.white, 
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange), 
              minHeight: 6
            )
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Soru ${_currentQuestionIndex + 1} / ${_questions.length}", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))], border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                              child: Text(
                                widget.topic ?? "Deneme Sınavı", 
                                style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold)
                              )
                            ), 
                            const SizedBox(height: 16), 
                            Text(currentQuestion.question, style: const TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w600, color: Colors.black87))
                          ]
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(currentQuestion.options.length, (index) => _buildOptionButton(index, currentQuestion.options[index])),
                      if (widget.isReviewMode && (currentQuestion.explanation.isNotEmpty)) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9), // Açık yeşil ton
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_circle, color: Colors.green.shade700, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Çözüm Açıklaması",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: Colors.green), // İnce çizgi
                              const SizedBox(height: 12),
                              Text(
                                currentQuestion.explanation,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.green.shade900,
                                  height: 1.5, // Okunabilirlik için satır aralığı
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // ... (Açıklama kartı if bloğu burada bitiyor)

                      const SizedBox(height: 30),

                      // 🔥 HATA BİLDİR BUTONU
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _showReportDialog(currentQuestion),
                          icon: Icon(Icons.flag_outlined, color: Colors.grey[600], size: 20),
                          label: Text(
                            "Soru Hatalı mı? Bildir",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              decoration: TextDecoration.underline, // Tıklanabilir hissi verir
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red, // Basınca hafif kırmızı efekt
                          ),
                        ),
                      ),       
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]), 
                child: Row(
                  children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: _currentQuestionIndex > 0 ? TextButton.icon(onPressed: _prevQuestion, icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey), label: const Text("Önceki", style: TextStyle(color: Colors.grey, fontSize: 16))) : const SizedBox.shrink())), 
                    InkWell(onTap: _showQuestionMap, borderRadius: BorderRadius.circular(30), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)), child: const Icon(Icons.apps_rounded, color: Color(0xFF1565C0), size: 28))), 
                    Expanded(child: Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _nextQuestion, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text(_currentQuestionIndex == _questions.length - 1 ? (widget.isReviewMode ? "Kapat" : "Bitir") : "Sonraki", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))))
                  ]
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 🔥 GÜNCELLENEN BUTON TASARIMI (RENKLENDİRME)
  Widget _buildOptionButton(int index, String optionText) {
    int? userAnswer = _userAnswers[_currentQuestionIndex];
    int correctAnswer = _questions[_currentQuestionIndex].answerIndex;
    
    // Varsayılan Renkler
    Color borderColor = Colors.transparent;
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    IconData? icon;

    // --- RENKLENDİRME MANTIĞI ---
    if (widget.isReviewMode) {
      // 👁️ İNCELEME MODU RENKLERİ
      if (index == correctAnswer) {
        // Bu şık doğru cevap -> YEŞİL OLSUN
        bgColor = Colors.green.shade100;
        borderColor = Colors.green;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle;
      } else if (index == userAnswer) {
        // Kullanıcı buna basmış ama yanlış -> KIRMIZI OLSUN
        bgColor = Colors.red.shade100;
        borderColor = Colors.red;
        textColor = Colors.red.shade900;
        icon = Icons.cancel;
      }
    } else {
      // 📝 NORMAL MOD RENKLERİ (Seçiliyse mavi)
      if (userAnswer == index) {
        borderColor = const Color(0xFF1565C0);
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        icon = Icons.check_circle_outline;
      }
    }
    
    String optionLetter = String.fromCharCode(65 + index);
    String displayLabel = optionLetter; 
    String displayText = optionText.length > 3 ? optionText.substring(3) : optionText; 

    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Material(color: Colors.transparent, child: InkWell(onTap: () => _selectOption(index), borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor == Colors.transparent ? Colors.white : borderColor, width: 2), borderRadius: BorderRadius.circular(16), boxShadow: (widget.isReviewMode || userAnswer == index) ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Row(children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: (widget.isReviewMode && index == correctAnswer) ? Colors.green : (userAnswer == index ? textColor.withOpacity(0.2) : Colors.grey[200]), shape: BoxShape.circle), child: Text(displayLabel, style: TextStyle(fontWeight: FontWeight.bold, color: (widget.isReviewMode && index == correctAnswer) ? Colors.white : (userAnswer == index ? textColor : Colors.grey[600])))), const SizedBox(width: 16), Expanded(child: Text(displayText, style: TextStyle(color: textColor, fontWeight: (userAnswer == index || (widget.isReviewMode && index == correctAnswer)) ? FontWeight.w600 : FontWeight.normal, fontSize: 15))), if (icon != null) Icon(icon, color: textColor)])))));
  }
}