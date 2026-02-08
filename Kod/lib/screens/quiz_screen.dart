// lib/screens/quiz_screen.dart

import 'dart:async';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import '../models/question_model.dart'; 
import '../services/quiz_service.dart';
import '../services/theme_provider.dart'; // 🔥 TEMA SAĞLAYICISI EKLENDİ
import 'result_screen.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/mistakes_service.dart';

class QuizScreen extends StatefulWidget {
  final bool isTrial; 
  final int? fixedDuration; 
  final String? topic;   
  final int? testNo;     
  
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
    this.questions,    
    this.userAnswers,  
    this.isReviewMode = false, 
    this.initialIndex = 0,     
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
    
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      _questions = widget.questions!;
      
      if (widget.userAnswers != null) {
        _userAnswers = widget.userAnswers!;
        _currentQuestionIndex = widget.initialIndex;
        _isLoading = false;
      } else {
        _userAnswers = List.filled(_questions.length, null);
        _isLoading = false;
        _initializeTimer(); 
      }
    } else {
      _loadQuestions(); 
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- JSON YÜKLEME ---
  Future<void> _loadQuestions() async {
    try {
      String jsonFileName = "anatomi.json"; 
      String topicName = widget.topic ?? "";

      if (topicName.contains("Anatomi")) jsonFileName = "anatomi.json";
      else if (topicName.contains("Biyokimya")) jsonFileName = "biyokimya.json";
      else if (topicName.contains("Fizyoloji")) jsonFileName = "fizyoloji.json";
      else if (topicName.contains("Histoloji")) jsonFileName = "histoloji.json";
      else if (topicName.contains("Farmakoloji")) jsonFileName = "farmakoloji.json";
      else if (topicName.contains("Patoloji")) jsonFileName = "patoloji.json";
      else if (topicName.contains("Mikrobiyoloji")) jsonFileName = "mikrobiyoloji.json";
      else if (topicName.contains("Biyoloji ve Genetik")) jsonFileName = "biyoloji.json";
      else if (topicName.contains("Ağız, Diş ve Çene Cerrahisi")) jsonFileName = "cerrahi.json";
      else if (topicName.contains("Endodonti")) jsonFileName = "endo.json";
      else if (topicName.contains("Periodontoloji")) jsonFileName = "perio.json";
      else if (topicName.contains("Ortodonti")) jsonFileName = "orto.json";
      else if (topicName.contains("Pedodonti")) jsonFileName = "pedo.json";
      else if (topicName.contains("Protetik Diş Tedavisi")) jsonFileName = "protetik.json";
      else if (topicName.contains("Ağız, Diş ve Çene Radyolojisi")) jsonFileName = "radyoloji.json";
      else if (topicName.contains("Restoratif Diş Tedavisi")) jsonFileName = "resto.json";
      
      String data = await DefaultAssetBundle.of(context).loadString('assets/data/$jsonFileName');
      List<dynamic> jsonList = json.decode(data);

      List<Question> allQuestions = jsonList.map((x) => Question.fromJson(x)).toList();
      List<Question> filteredQuestions = [];

      if (widget.isTrial) {
        filteredQuestions = allQuestions;
      } else {
        if (widget.testNo != null) {
           filteredQuestions = allQuestions.where((q) => q.testNo == widget.testNo).toList();
        } else {
           filteredQuestions = allQuestions;
        }
      }

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
      debugPrint("Dosya Hatası: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _questions = []; 
        });
      }
    }
  }

  // --- SAYAÇ ---
  void _initializeTimer() {
    if (widget.questions != null && widget.questions!.isNotEmpty) {
       setState(() {
         _seconds = 60 * 60; 
       });
       _startTimer();
       return;
    }

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
    if (widget.isReviewMode) return; 

    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (widget.isTrial || (widget.questions != null)) { 
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

  // --- YARDIMCI FONKSİYONLAR ---

  Future<bool> _onWillPop() async {
    if (widget.isReviewMode) return true; 

    return (await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sınavdan Çık?"),
        content: const Text("İlerlemen kaybolacak. Emin misin?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Hayır")),
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
    final TextEditingController durationController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Hedef Süre 🎯"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kaç dakika?"),
            const SizedBox(height: 20),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: "Dakika", border: OutlineInputBorder(), suffixText: "dk"),
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
    if (widget.isReviewMode) return; 

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
      if (widget.isReviewMode) {
        Navigator.pop(context); 
      } else {
        _showFinishDialog(); 
      }
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  void _showReportDialog(Question question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hata Bildir"),
        content: const Text("Bu soruda hata mı var?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bildirildi.")));
            }, 
            child: const Text("Bildir")
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
        title: Text(timeUp ? "Süre Doldu!" : "Sınavı Bitir?"),
        content: const Text("Sonuçları görmek için bitir."),
        actions: [
          if (!timeUp)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Vazgeç"),
            ),
            
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              _timer?.cancel(); 

              int correct = 0;
              int wrong = 0;  
              int empty = 0;
              
              List<Map<String, dynamic>> wrongQuestionsToSave = [];
              List<Map<String, dynamic>> correctQuestionsToRemove = [];

              bool isMistakeReview = widget.questions != null && widget.questions!.isNotEmpty;

              for (int i = 0; i < _questions.length; i++) {
                if (_userAnswers[i] == null) {
                  empty++;
                  if (!isMistakeReview) {
                    wrongQuestionsToSave.add({
                      'id': _questions[i].id,
                      'question': _questions[i].question,
                      'options': _questions[i].options,
                      'correctIndex': _questions[i].answerIndex,
                      'userIndex': -1, 
                      'subject': widget.topic ?? "Genel",
                      'explanation': _questions[i].explanation,
                      'date': DateTime.now().toIso8601String(),
                    });
                  }
                } else if (_userAnswers[i] == _questions[i].answerIndex) {
                  correct++;
                  if (isMistakeReview) {
                     correctQuestionsToRemove.add({
                       'id': _questions[i].id,
                       'subject': _questions[i].level
                     });
                  }
                } else {
                  wrong++;
                  if (!isMistakeReview) {
                    wrongQuestionsToSave.add({
                      'id': _questions[i].id,
                      'question': _questions[i].question,
                      'options': _questions[i].options,
                      'correctIndex': _questions[i].answerIndex,
                      'userIndex': _userAnswers[i],
                      'subject': widget.topic ?? "Genel",
                      'explanation': _questions[i].explanation,
                      'date': DateTime.now().toIso8601String(),
                    });
                  }
                }
              }

              int score = 0;
              if (_questions.isNotEmpty) {
                score = ((correct / _questions.length) * 100).toInt();
              }

              if (wrongQuestionsToSave.isNotEmpty) {
                await MistakesService.addMistakes(wrongQuestionsToSave);
              }
              
              if (correctQuestionsToRemove.isNotEmpty) {
                await MistakesService.removeMistakeList(correctQuestionsToRemove);
              }

              if (!widget.isTrial && widget.topic != null && widget.testNo != null) {
                QuizService.saveQuizResult(
                  topic: widget.topic!,
                  testNo: widget.testNo!,
                  score: score,
                  correctCount: correct,
                  wrongCount: wrong,
                  userAnswers: _userAnswers,
                );
              }

              if (!widget.isReviewMode) {
                _updateFirebaseStats(correct, wrong + empty); 
              }

              if (mounted) {
                await Navigator.push(
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
                if(mounted){
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Bitir"),
          )
        ],
      ),
    );
  }

  Future<void> _updateFirebaseStats(int correct, int wrong) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await userDoc.get(); 

      int totalSolvedNow = correct + wrong;
      int minutesSpent = (_seconds > 0 && !widget.isTrial) ? (_seconds ~/ 60) : 0; 
      
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

      String todayStr = now.toIso8601String().split('T')[0];

      if (lastStudyDate == null) {
        currentStreak = 1;
      } else {
        final lastDay = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);
        final difference = today.difference(lastDay).inDays;

        if (difference == 1) {
          currentStreak++; 
        } else if (difference > 1) {
          currentStreak = 1; 
        }
      }

      await userDoc.update({
        'totalSolved': FieldValue.increment(totalSolvedNow),
        'totalMinutes': FieldValue.increment(minutesSpent),
        'totalCorrect': FieldValue.increment(correct), 

        'dailySolved': FieldValue.increment(totalSolvedNow),
        'dailyMinutes': FieldValue.increment(minutesSpent),

        'streak': currentStreak,
        'lastStudyDate': FieldValue.serverTimestamp(),
        'lastActivityDate': todayStr,

      });
      
    } catch (e) {
      debugPrint("İstatistik hatası: $e");
    }
  }

  void _showQuestionMap() {
    // 🔥 Modal Rengi (Tema)
    bool isDarkMode = ThemeProvider.instance.isDarkMode;
    Color modalBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Text("Soru Haritası", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _questions.length, 
                  itemBuilder: (context, index) {
                    bool isAnswered = _userAnswers[index] != null;
                    bool isCurrent = index == _currentQuestionIndex;
                    
                    // Harita Renkleri
                    Color boxColor = isCurrent ? Colors.orange 
                      : (isAnswered 
                          ? (isDarkMode ? const Color(0xFF1565C0) : const Color(0xFF1565C0)) 
                          : (isDarkMode ? Colors.white10 : Colors.grey[100])!
                        );
                    Color boxTextColor = (isCurrent || isAnswered) ? Colors.white : (isDarkMode ? Colors.white60 : Colors.black54);

                    return GestureDetector(
                      onTap: () { Navigator.pop(context); setState(() => _currentQuestionIndex = index); },
                      child: Container(
                        decoration: BoxDecoration(
                          color: boxColor, 
                          borderRadius: BorderRadius.circular(12), 
                          border: isCurrent ? Border.all(color: Colors.orangeAccent, width: 2) : null
                        ),
                        alignment: Alignment.center,
                        child: Text("${index + 1}", style: TextStyle(color: boxTextColor, fontWeight: FontWeight.bold)),
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
    // --- 🔥 TEMA AYARLARI ---
    final isDarkMode = ThemeProvider.instance.isDarkMode;
    
    // Arka Plan
    Color scaffoldBg = isDarkMode ? const Color(0xFF0A0E14) : const Color(0xFFE3F2FD);
    // Soru Kartı
    Color cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white.withOpacity(0.9);
    // Metinler
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    Color subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey[600]!;
    
    // Bottom Bar
    Color bottomBarBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.white : null)),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(child: Text("Soru yok.", style: TextStyle(color: textColor))),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: scaffoldBg, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(widget.isReviewMode ? Icons.arrow_back : Icons.close, color: isDarkMode ? Colors.white70 : Colors.grey),
            onPressed: () async {
               if (widget.isReviewMode) {
                 Navigator.pop(context); 
               } else {
                 if (await _onWillPop()) {
                   if (mounted) Navigator.of(context).pop();
                 }
               }
            },
          ),
          title: widget.isReviewMode 
            ? Text("İnceleme 👁️", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.isTrial ? Icons.hourglass_bottom : Icons.timer_outlined, size: 20, color: isDarkMode ? Colors.blue.shade200 : const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_seconds), 
                  style: TextStyle(
                    color: widget.isTrial && _seconds < 60 ? Colors.red : (isDarkMode ? Colors.blue.shade200 : const Color(0xFF1565C0)), 
                    fontWeight: FontWeight.bold, 
                    fontSize: 18, 
                  )
                ),
              ],
            ),
          actions: [const SizedBox(width: 48)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6.0), 
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length, 
              backgroundColor: isDarkMode ? Colors.white10 : Colors.white, 
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
                      Text("Soru ${_currentQuestionIndex + 1} / ${_questions.length}", style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg, 
                          borderRadius: BorderRadius.circular(24), 
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 5))], 
                          border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 2)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            if (widget.topic != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                              child: Text(
                                widget.topic!, 
                                style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold)
                              )
                            ), 
                            const SizedBox(height: 16), 
                            Text(currentQuestion.question, style: TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w600, color: textColor))
                          ]
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(currentQuestion.options.length, (index) => _buildOptionButton(index, currentQuestion.options[index], isDarkMode)),
                      
                      if (widget.isReviewMode && (currentQuestion.explanation.isNotEmpty)) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.green.withOpacity(0.1) : const Color(0xFFF1F8E9), 
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Çözüm Açıklaması", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              const SizedBox(height: 8),
                              Text(currentQuestion.explanation, style: TextStyle(fontSize: 15, color: isDarkMode ? Colors.white70 : Colors.green.shade900)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _showReportDialog(currentQuestion),
                          icon: Icon(Icons.flag_outlined, color: subTextColor, size: 20),
                          label: Text("Hata Bildir", style: TextStyle(color: subTextColor, decoration: TextDecoration.underline)),
                        ),
                      ),       
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                decoration: BoxDecoration(color: bottomBarBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -5))]), 
                child: Row(
                  children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: _currentQuestionIndex > 0 ? TextButton.icon(onPressed: _prevQuestion, icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey), label: const Text("Önceki", style: TextStyle(color: Colors.grey, fontSize: 16))) : const SizedBox.shrink())), 
                    InkWell(onTap: _showQuestionMap, borderRadius: BorderRadius.circular(30), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.grey[100], shape: BoxShape.circle, border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey[300]!)), child: const Icon(Icons.apps_rounded, color: Color(0xFF1565C0), size: 28))), 
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
  
  Widget _buildOptionButton(int index, String optionText, bool isDarkMode) {
    int? userAnswer = _userAnswers[_currentQuestionIndex];
    int correctAnswer = _questions[_currentQuestionIndex].answerIndex;
    
    Color borderColor = Colors.transparent;
    Color bgColor = isDarkMode ? const Color(0xFF0D1117) : Colors.white; // Şık Arka Planı
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    IconData? icon;

    if (widget.isReviewMode) {
      if (index == correctAnswer) {
        bgColor = isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green.shade100;
        borderColor = Colors.green;
        textColor = isDarkMode ? Colors.green.shade200 : Colors.green.shade900;
        icon = Icons.check_circle;
      } else if (index == userAnswer) {
        bgColor = isDarkMode ? Colors.red.withOpacity(0.2) : Colors.red.shade100;
        borderColor = Colors.red;
        textColor = isDarkMode ? Colors.red.shade200 : Colors.red.shade900;
        icon = Icons.cancel;
      }
    } else {
      if (userAnswer == index) {
        borderColor = const Color(0xFF1565C0); // Seçili çerçeve rengi
        bgColor = isDarkMode ? const Color(0xFF1565C0).withOpacity(0.2) : const Color(0xFFE3F2FD); // Seçili arka plan
        textColor = isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
        icon = Icons.check_circle_outline;
      } else {
        // Seçilmemiş Şıklar İçin Border
        borderColor = isDarkMode ? Colors.white10 : Colors.transparent;
      }
    }
    
    String optionLetter = String.fromCharCode(65 + index);
    String displayText = optionText.length > 3 ? optionText.substring(3) : optionText; 

    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Material(color: Colors.transparent, child: InkWell(onTap: () => _selectOption(index), borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor == Colors.transparent ? Colors.white : borderColor, width: 2), borderRadius: BorderRadius.circular(16), boxShadow: (widget.isReviewMode || userAnswer == index) ? [] : [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Row(children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: (widget.isReviewMode && index == correctAnswer) ? Colors.green : (userAnswer == index ? textColor.withOpacity(0.2) : (isDarkMode ? Colors.white10 : Colors.grey[200])), shape: BoxShape.circle), child: Text(optionLetter, style: TextStyle(fontWeight: FontWeight.bold, color: (widget.isReviewMode && index == correctAnswer) ? Colors.white : (userAnswer == index ? textColor : (isDarkMode ? Colors.white70 : Colors.grey[600]))))), const SizedBox(width: 16), Expanded(child: Text(displayText, style: TextStyle(color: textColor, fontWeight: (userAnswer == index || (widget.isReviewMode && index == correctAnswer)) ? FontWeight.w600 : FontWeight.normal, fontSize: 15))), if (icon != null) Icon(icon, color: textColor)])))));
  }
}