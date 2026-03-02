import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/question_model.dart';
import '../services/quiz_service.dart';
import '../services/theme_provider.dart';
import '../services/mistakes_service.dart';
import '../services/bookmark_service.dart';
import '../services/offline_service.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final bool isTrial;
  final int? fixedDuration;
  final String? topic;
  final int? testNo;

  final List<Question>? questions;
  final List<int?>? userAnswers;
  final bool isReviewMode;
  final int initialIndex;
  final bool useOffline;

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
    this.useOffline = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question> _questions = [];
  bool _isLoading = true;

  int _currentQuestionIndex = 0;
  late List<int?> _userAnswers;

  Timer? _timer;
  int _seconds = 0;
  bool _isTimerRunning = false;

  bool _isBookmarked = false;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _isOfflineMode = widget.useOffline;

    if (widget.questions != null && widget.questions!.isNotEmpty) {
      _questions = widget.questions!;
      if (widget.userAnswers != null) {
        _userAnswers = widget.userAnswers!;
        _currentQuestionIndex = widget.initialIndex;
        _isLoading = false;
        _checkBookmarkStatus();
      } else {
        _userAnswers = List.filled(_questions.length, null);
        _isLoading = false;
        _initializeTimer();
        _checkBookmarkStatus();
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

  Future<void> _checkBookmarkStatus() async {
    if (_questions.isEmpty) return;

    Question currentQ = _questions[_currentQuestionIndex];
    String topic = widget.topic ?? currentQ.level;
    String safeTopic = topic.replaceAll(' ', '_').toLowerCase();
    String uniqueId = "${safeTopic}_${currentQ.testNo}_${currentQ.id}";

    bool status = await BookmarkService.isBookmarked(uniqueId);

    if (mounted) {
      setState(() {
        _isBookmarked = status;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_questions.isEmpty) return;

    Question currentQ = _questions[_currentQuestionIndex];
    String topic = widget.topic ?? currentQ.level;

    bool newState = await BookmarkService.toggleBookmark(currentQ, topic);

    if (mounted) {
      setState(() {
        _isBookmarked = newState;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? "Soru kaydedildi 📌" : "Kaydedilenlerden çıkarıldı"),
          duration: const Duration(seconds: 1),
          backgroundColor: newState ? Colors.green : Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadQuestions() async {
    try {
      if (_isOfflineMode && widget.topic != null && widget.testNo != null) {
        debugPrint("📡 Offline mod aktif - Yerel veriden yükleniyor...");

        String cleanTopic = widget.topic!.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        List<Question> offlineQuestions = await OfflineService.loadOfflineQuestions(
          cleanTopic,
          widget.testNo!,
        );

        if (offlineQuestions.isNotEmpty) {
          if (mounted) {
            setState(() {
              _questions = offlineQuestions;
              _userAnswers = List.filled(_questions.length, null);
              _isLoading = false;
            });

            _initializeTimer();
            _checkBookmarkStatus();
          }
          return;
        } else {
          debugPrint("⚠️ Offline veri bulunamadı, Firebase'e geçiliyor...");
        }
      }

      // NORMAL FIREBASE AKIŞI
      String dbTopic = "";
      if (widget.topic != null) {
        String t = widget.topic!;
        if (t.contains("Anatomi")) dbTopic = "anatomi";
        else if (t.contains("Biyokimya")) dbTopic = "biyokimya";
        else if (t.contains("Fizyoloji")) dbTopic = "fizyoloji";
        else if (t.contains("Histoloji")) dbTopic = "histoloji";
        else if (t.contains("Farmakoloji")) dbTopic = "farma";
        else if (t.contains("Patoloji")) dbTopic = "patoloji";
        else if (t.contains("Mikrobiyoloji")) dbTopic = "mikrobiyo";
        else if (t.contains("Biyoloji")) dbTopic = "biyoloji";
        else if (t.contains("Cerrahi")) dbTopic = "cerrahi";
        else if (t.contains("Endodonti")) dbTopic = "endo";
        else if (t.contains("Perio")) dbTopic = "perio";
        else if (t.contains("Orto")) dbTopic = "orto";
        else if (t.contains("Pedo")) dbTopic = "pedo";
        else if (t.contains("Protetik")) dbTopic = "protetik";
        else if (t.contains("Radyoloji")) dbTopic = "radyoloji";
        else if (t.contains("Restoratif")) dbTopic = "resto";
        else dbTopic = t.toLowerCase();
      }

      QuerySnapshot snapshot;

      if (widget.isTrial) {
        snapshot = await FirebaseFirestore.instance
            .collection('questions')
            .where('topic', isEqualTo: dbTopic)
            .limit(50)
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
            .collection('questions')
            .where('topic', isEqualTo: dbTopic)
            .where('testNo', isEqualTo: widget.testNo)
            .orderBy('questionIndex')
            .get();
      }

      List<Question> fetchedQuestions = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return Question(
          id: data['questionIndex'] ?? 0,
          question: data['question'] ?? "",
          options: List<String>.from(data['options'] ?? []),
          answerIndex: data['correctIndex'] ?? 0,
          explanation: data['explanation'] ?? "",
          testNo: data['testNo'] ?? 0,
          level: data['topic'] ?? "Genel",
          imageUrl: data['image_url'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _questions = fetchedQuestions;
          _userAnswers = List.filled(_questions.length, null);
          _isLoading = false;
        });

        if (_questions.isNotEmpty) {
          _initializeTimer();
          _checkBookmarkStatus();
        }
      }
    } catch (e) {
      debugPrint("Firebase Soru Yükleme Hatası: $e");

      if (widget.topic != null && widget.testNo != null && !_isOfflineMode) {
        debugPrint("🔄 Firebase hatası, offline deneniyor...");
        setState(() => _isOfflineMode = true);
        _loadQuestions();
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _questions = [];
        });
      }
    }
  }

  void _initializeTimer() {
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      setState(() => _seconds = 0);
      _startTimer();
      return;
    }

    if (widget.isTrial) {
      if (widget.fixedDuration != null) {
        setState(() => _seconds = widget.fixedDuration! * 60);
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
        if (widget.isTrial && widget.fixedDuration != null) {
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

  Future<bool> _onWillPop() async {
    if (widget.isReviewMode) return true;

    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Sınavdan Çık?"),
            content: const Text("İlerlemen kaybolacak. Emin misin?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Hayır"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Evet, Çık"),
              ),
            ],
          ),
        )) ??
        false;
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
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
              decoration: const InputDecoration(
                labelText: "Dakika",
                border: OutlineInputBorder(),
                suffixText: "dk",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Vazgeç"),
          ),
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
      _checkBookmarkStatus();
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
      _checkBookmarkStatus();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCORE CALCULATION — pure, no side-effects, always safe to call
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _calculateResults() {
    int correct = 0;
    int wrong = 0;
    int empty = 0;

    List<Map<String, dynamic>> wrongQuestionsToSave = [];
    List<String> correctQuestionsToRemove = [];

    bool isMistakeReview = widget.questions != null && !widget.isReviewMode;

    for (int i = 0; i < _questions.length; i++) {
      int? answer = _userAnswers[i];
      int trueIndex = _questions[i].answerIndex;

      if (answer == null) {
        empty++;
        if (!isMistakeReview) {
          wrongQuestionsToSave.add({
            'id': _questions[i].id,
            'question': _questions[i].question,
            'options': _questions[i].options,
            'correctIndex': _questions[i].answerIndex,
            'userIndex': -1,
            'topic': widget.topic ?? _questions[i].level,
            'testNo': widget.testNo ?? _questions[i].testNo,
            'questionIndex': _questions[i].id,
            'explanation': _questions[i].explanation,
            'image_url': _questions[i].imageUrl,
            'date': DateTime.now().toIso8601String(),
          });
        }
      } else if (answer == trueIndex) {
        correct++;
        if (isMistakeReview) {
          String topic = widget.topic ?? _questions[i].level;
          int testNo = widget.testNo ?? _questions[i].testNo;
          int qId = _questions[i].id;
          correctQuestionsToRemove.add("${topic}_${testNo}_$qId");
        }
      } else {
        wrong++;
        if (!isMistakeReview) {
          wrongQuestionsToSave.add({
            'id': _questions[i].id,
            'question': _questions[i].question,
            'options': _questions[i].options,
            'correctIndex': _questions[i].answerIndex,
            'userIndex': answer,
            'topic': widget.topic ?? _questions[i].level,
            'testNo': widget.testNo ?? _questions[i].testNo,
            'questionIndex': _questions[i].id,
            'explanation': _questions[i].explanation,
            'image_url': _questions[i].imageUrl,
            'date': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    int score = _questions.isNotEmpty
        ? ((correct / _questions.length) * 100).toInt()
        : 0;

    return {
      'correct': correct,
      'wrong': wrong,
      'empty': empty,
      'score': score,
      'wrongQuestionsToSave': wrongQuestionsToSave,
      'correctQuestionsToRemove': correctQuestionsToRemove,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BACKGROUND SAVE — all errors are caught internally; never throws
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveResultsInBackground({
    required int correct,
    required int wrong,
    required int empty,
    required int score,
    required List<Map<String, dynamic>> wrongQuestionsToSave,
    required List<String> correctQuestionsToRemove,
  }) async {
    if (_isOfflineMode) {
      // ── OFFLINE SAVE ────────────────────────────────────────────────────
      try {
        for (var mistake in wrongQuestionsToSave) {
          await OfflineService.saveOfflineMistake(mistake);
        }
      } catch (e) {
        debugPrint("⚠️ Offline mistake save error (non-fatal): $e");
      }

      try {
        if (!widget.isReviewMode &&
            widget.topic != null &&
            widget.testNo != null) {
          await OfflineService.saveOfflineResult(
            topic: widget.topic!,
            testNo: widget.testNo!,
            score: score,
            correctCount: correct,
            wrongCount: wrong,
            emptyCount: empty,
            userAnswers: _userAnswers,
          );
        }
      } catch (e) {
        debugPrint("⚠️ Offline result save error (non-fatal): $e");
      }

      // Show snackbar after returning, so we don't block
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text("Veriler offline kaydedildi")),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // ── ONLINE SAVE ─────────────────────────────────────────────────────
      try {
        if (wrongQuestionsToSave.isNotEmpty) {
          await MistakesService.addMistakes(wrongQuestionsToSave);
        }
      } catch (e) {
        debugPrint("⚠️ MistakesService.addMistakes error (non-fatal): $e");
      }

      try {
        if (correctQuestionsToRemove.isNotEmpty) {
          await MistakesService.removeMistakeList(correctQuestionsToRemove);
        }
      } catch (e) {
        debugPrint("⚠️ MistakesService.removeMistakeList error (non-fatal): $e");
      }

      try {
        if (!widget.isReviewMode) {
          await _updateFirebaseStats(correct, wrong + empty);
        }
      } catch (e) {
        debugPrint("⚠️ _updateFirebaseStats error (non-fatal): $e");
      }

      try {
        if (!widget.isTrial &&
            widget.topic != null &&
            widget.testNo != null) {
          await QuizService.saveQuizResult(
            topic: widget.topic!,
            testNo: widget.testNo!,
            score: score,
            correctCount: correct,
            wrongCount: wrong,
            emptyCount: empty,
            userAnswers: _userAnswers,
          );
        }
      } catch (e) {
        debugPrint("⚠️ QuizService.saveQuizResult error (non-fatal): $e");
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FINISH DIALOG — navigation is GUARANTEED even if saves fail
  // ─────────────────────────────────────────────────────────────────────────
  void _showFinishDialog({bool timeUp = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(timeUp ? "Süre Doldu!" : "Sınavı Bitir?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Sonuçları görmek ve kaydetmek için bitir."),
            if (_isOfflineMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Offline mod aktif. Veriler internet gelince senkronize edilecek.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!timeUp)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              // 1️⃣  Close the dialog immediately — no awaits before this
              Navigator.pop(ctx);

              // 2️⃣  Stop the timer
              _timer?.cancel();

              // 3️⃣  Calculate scores synchronously — this never fails
              final results = _calculateResults();
              final int correct = results['correct'] as int;
              final int wrong = results['wrong'] as int;
              final int empty = results['empty'] as int;
              final int score = results['score'] as int;
              final List<Map<String, dynamic>> wrongQuestionsToSave =
                  results['wrongQuestionsToSave'] as List<Map<String, dynamic>>;
              final List<String> correctQuestionsToRemove =
                  results['correctQuestionsToRemove'] as List<String>;

              // 4️⃣  Navigate to ResultScreen IMMEDIATELY — before any async saves
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(
                      questions: _questions,
                      userAnswers: _userAnswers,
                      topic: widget.topic ?? "Genel Tekrar",
                      testNo: widget.testNo ?? 1,
                      correctCount: correct,
                      wrongCount: wrong,
                      emptyCount: empty,
                      score: score,
                      isOfflineMode: _isOfflineMode,
                    ),
                  ),
                );
              }

              // 5️⃣  Fire-and-forget background save (errors are all caught inside)
              //     This runs AFTER the user has already seen ResultScreen.
              //     We intentionally don't await this before popping.
              _saveResultsInBackground(
                correct: correct,
                wrong: wrong,
                empty: empty,
                score: score,
                wrongQuestionsToSave: wrongQuestionsToSave,
                correctQuestionsToRemove: correctQuestionsToRemove,
              ).catchError((e) {
                debugPrint("⚠️ Background save failed (non-fatal): $e");
              });

              // 6️⃣  Pop quiz screen
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("Bitir"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFirebaseStats(int correct, int totalSolved) async {
    // İstatistik güncelleme (opsiyonel)
  }

  void _showQuestionMap() {
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
          decoration: BoxDecoration(
            color: modalBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "Soru Haritası",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    bool isAnswered = _userAnswers[index] != null;
                    bool isCurrent = index == _currentQuestionIndex;

                    Color boxColor;
                    if (widget.isReviewMode) {
                      int correctIndex = _questions[index].answerIndex;
                      int? userAnswer = _userAnswers[index];
                      if (userAnswer == correctIndex) {
                        boxColor = Colors.green;
                      } else if (userAnswer != null) {
                        boxColor = Colors.red;
                      } else {
                        boxColor = Colors.grey;
                      }
                    } else {
                      boxColor = isCurrent
                          ? Colors.orange
                          : (isAnswered
                              ? const Color(0xFF1565C0)
                              : (isDarkMode
                                  ? Colors.white10
                                  : Colors.grey[200])!);
                    }

                    Color boxTextColor =
                        (isCurrent || isAnswered || widget.isReviewMode)
                            ? Colors.white
                            : (isDarkMode ? Colors.white60 : Colors.black54);

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _currentQuestionIndex = index);
                        _checkBookmarkStatus();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: boxColor,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(
                                  color: Colors.orangeAccent, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: boxTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // REPORT DIALOG — kullanıcıdan not alır, Firestore'a kaydeder
  // ─────────────────────────────────────────────────────────────────────────
  void _showReportDialog(Question question) {
    final TextEditingController noteController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text("Hata Bildir"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bu soruda ne tür bir hata var?",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Hatayı açıklayın...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context),
              child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      final note = noteController.text.trim();
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Lütfen hatayı açıklayın."),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        await FirebaseFirestore.instance
                            .collection('question_reports')
                            .add({
                          'questionId': question.id,
                          'questionText': question.question,
                          'reportedAt': FieldValue.serverTimestamp(),
                          'status': 'open',
                          'userId': user?.uid ?? 'anonymous',
                          'userNote': note,
                        });

                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bildiriminiz alındı. Teşekkürler! 🙏"),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        debugPrint("⚠️ Report save error: $e");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bildirim gönderilemedi. Tekrar deneyin."),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Bildir"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    Color scaffoldBg =
        isDarkMode ? const Color(0xFF0A0E14) : const Color(0xFFE3F2FD);
    Color cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    Color textColor =
        isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    Color subTextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey[600]!;
    Color bottomBarBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: isDarkMode ? Colors.white : null),
              const SizedBox(height: 16),
              if (_isOfflineMode)
                const Text(
                  "📡 Offline modda yükleniyor...",
                  style: TextStyle(color: Colors.orange),
                ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(
          child: Text(
            "Bu konuda henüz soru bulunmuyor.",
            style: TextStyle(color: textColor),
          ),
        ),
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
            icon: Icon(
              widget.isReviewMode ? Icons.arrow_back : Icons.close,
              color: isDarkMode ? Colors.white70 : Colors.grey,
            ),
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
              ? Text(
                  "İnceleme 👁️",
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.bold),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isOfflineMode) ...[
                      const Icon(Icons.wifi_off,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      widget.isTrial
                          ? Icons.hourglass_bottom
                          : Icons.timer_outlined,
                      size: 20,
                      color: isDarkMode
                          ? Colors.blue.shade200
                          : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(_seconds),
                      style: TextStyle(
                        color: widget.isTrial && _seconds < 60
                            ? Colors.red
                            : (isDarkMode
                                ? Colors.blue.shade200
                                : const Color(0xFF1565C0)),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
          actions: [
            IconButton(
              onPressed: _toggleBookmark,
              icon: Icon(
                _isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border_rounded,
                color: _isBookmarked
                    ? Colors.orange
                    : (isDarkMode ? Colors.white70 : Colors.grey),
                size: 26,
              ),
              tooltip: "Soruyu Kaydet",
            ),
            const SizedBox(width: 16),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6.0),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor:
                  isDarkMode ? Colors.white10 : Colors.grey.shade300,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 6,
            ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Soru ${_currentQuestionIndex + 1} / ${_questions.length}",
                            style: TextStyle(
                              color: subTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (widget.topic != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.topic!.length > 20
                                    ? "${widget.topic!.substring(0, 18)}..."
                                    : widget.topic!,
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (currentQuestion.imageUrl != null &&
                          currentQuestion.imageUrl!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black26
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              currentQuestion.imageUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress
                                                .expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress
                                                .expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 50, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                  isDarkMode ? 0.3 : 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            )
                          ],
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          currentQuestion.question,
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      ...List.generate(
                        currentQuestion.options.length,
                        (index) => _buildOptionButton(
                          index,
                          currentQuestion.options[index],
                          isDarkMode,
                        ),
                      ),

                      if (widget.isReviewMode &&
                          currentQuestion.explanation.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.green.withOpacity(0.1)
                                : const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lightbulb,
                                      color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Çözüm Açıklaması",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentQuestion.explanation,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.green.shade900,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              _showReportDialog(currentQuestion),
                          icon: Icon(Icons.flag_outlined,
                              color: subTextColor, size: 18),
                          label: Text(
                            "Hata Bildir",
                            style: TextStyle(
                              color: subTextColor,
                              decoration: TextDecoration.underline,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: bottomBarBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(isDarkMode ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _currentQuestionIndex > 0
                            ? TextButton.icon(
                                onPressed: _prevQuestion,
                                icon: const Icon(Icons.arrow_back_ios,
                                    size: 16, color: Colors.grey),
                                label: const Text("Önceki",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    InkWell(
                      onTap: _showQuestionMap,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white10
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white24
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: const Icon(Icons.grid_view_rounded,
                            color: Color(0xFF1565C0), size: 24),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _nextQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF1565C0)
                                .withOpacity(0.4),
                          ),
                          child: Text(
                            _currentQuestionIndex == _questions.length - 1
                                ? (widget.isReviewMode ? "Kapat" : "Bitir")
                                : "Sonraki",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        ),
      ),
    );
  }

  Widget _buildOptionButton(
      int index, String optionText, bool isDarkMode) {
    int? userAnswer = _userAnswers[_currentQuestionIndex];
    int correctAnswer = _questions[_currentQuestionIndex].answerIndex;

    Color borderColor = Colors.transparent;
    Color bgColor =
        isDarkMode ? const Color(0xFF0D1117) : Colors.white;
    Color textColor =
        isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    IconData? icon;

    if (widget.isReviewMode) {
      if (index == correctAnswer) {
        bgColor = isDarkMode
            ? Colors.green.withOpacity(0.2)
            : Colors.green.shade100;
        borderColor = Colors.green;
        textColor = isDarkMode
            ? Colors.green.shade200
            : Colors.green.shade900;
        icon = Icons.check_circle;
      } else if (index == userAnswer) {
        bgColor = isDarkMode
            ? Colors.red.withOpacity(0.2)
            : Colors.red.shade100;
        borderColor = Colors.red;
        textColor =
            isDarkMode ? Colors.red.shade200 : Colors.red.shade900;
        icon = Icons.cancel;
      }
    } else {
      if (userAnswer == index) {
        borderColor = const Color(0xFF1565C0);
        bgColor = isDarkMode
            ? const Color(0xFF1565C0).withOpacity(0.2)
            : const Color(0xFFE3F2FD);
        textColor = isDarkMode
            ? const Color(0xFF64B5F6)
            : const Color(0xFF1565C0);
        icon = Icons.check_circle_outline;
      } else {
        borderColor = isDarkMode ? Colors.white10 : Colors.transparent;
      }
    }

    String optionLetter = String.fromCharCode(65 + index);

    String displayText = optionText;
    if (optionText.length > 3 && optionText[1] == ')') {
      displayText = optionText.substring(3).trim();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectOption(index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: borderColor == Colors.transparent
                    ? (isDarkMode
                        ? Colors.white10
                        : Colors.transparent)
                    : borderColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: (widget.isReviewMode || userAnswer == index)
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                            isDarkMode ? 0.2 : 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (widget.isReviewMode && index == correctAnswer)
                        ? Colors.green
                        : (userAnswer == index
                            ? textColor.withOpacity(0.2)
                            : (isDarkMode
                                ? Colors.white10
                                : Colors.grey[200])),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    optionLetter,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (widget.isReviewMode &&
                              index == correctAnswer)
                          ? Colors.white
                          : (userAnswer == index
                              ? textColor
                              : (isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[600])),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          (userAnswer == index ||
                                  (widget.isReviewMode &&
                                      index == correctAnswer))
                              ? FontWeight.bold
                              : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: textColor, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
