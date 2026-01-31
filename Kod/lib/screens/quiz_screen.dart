// lib/screens/quiz_screen.dart
import 'dart:async';
import 'dart:convert'; // 🔥 JSON Çözmek için şart
import 'package:flutter/material.dart';
import '../models/question_model.dart'; 
import '../services/quiz_service.dart';

class QuizScreen extends StatefulWidget {
  final bool isTrial; // Deneme mi?
  final int? fixedDuration; // Sabit süre
  final String? topic;   // Örn: "Anatomi"
  final int? testNo;     // Örn: 1

  const QuizScreen({
    super.key,
    required this.isTrial,
    this.fixedDuration,
    this.topic,   
    this.testNo 
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
    _loadQuestions(); // 🔥 Sayfa açılınca soruları yükle
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- 1. SORULARI JSON'DAN ÇEKME FONKSİYONU ---
// --- GÜÇLENDİRİLMİŞ SORU YÜKLEME VE FİLTRELEME ---
// --- SORULARI JSON'DAN ÇEKME FONKSİYONU ---
  Future<void> _loadQuestions() async {
    try {
      String jsonFileName = ""; //Başlangıçta boş
      
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
      else if (topicName.contains("Farmakoloji")) { // 💊 Yeni Eklendi
        jsonFileName = "farmakoloji.json";
      }
      else if (topicName.contains("Patoloji")) {
        jsonFileName = "patoloji.json";
      }
      else if (topicName.contains("Mikrobiyoloji")) {
        jsonFileName = "mikrobiyoloji.json";
      }
      // ... Diğer dersleri buraya eklemeye devam edebilirsin ...
      
      else {
        // 🛑 ARTIK ANATOMİ AÇMIYORUZ! Hata fırlatıyoruz ki uyarı versin.
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
          _userAnswers = List.filled(_questions.length, null); // Cevap anahtarını sıfırla
          _isLoading = false; 
        });

        // Eğer soru listesi doluysa sayacı başlat
        if (_questions.isNotEmpty) {
           _initializeTimer();
        }
      }

    } catch (e) {
      debugPrint("🛑 BİLGİ: Dosya bulunamadı veya henüz eklenmedi ($e)");
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _questions = []; // Listeyi boşalt
        });
        
        // 🗑️ DİALOG SİLİNDİ
        // Artık hata mesajı veya popup çıkmayacak.
        // Ekranda sadece boş liste uyarısı görünecek.
      }
    }
  }

  
  // --- 2. SAYAÇ MANTIĞI (EKSİKTİ, EKLENDİ) ---
  void _initializeTimer() {
    if (widget.isTrial) {
      if (widget.fixedDuration != null) {
        // Sabit süre (Genel Deneme)
        setState(() {
          _seconds = widget.fixedDuration! * 60;
        });
        _startTimer();
      } else {
        // Kullanıcıya süre sor (Konu Denemesi)
        Future.delayed(Duration.zero, () => _showDurationPickerDialog());
      }
    } else {
      // Normal Mod (İleri Sayım)
      _startTimer();
    }
  }

  void _startTimer() {
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
      _showFinishDialog();
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
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
                  wrongCount: wrong
                );
              }

              // 3. EKRANDAN ÇIK 🚪
              if (mounted) {
                Navigator.pop(context); 
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
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: Row(
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
                            // 🔥 GÜNCELLEME: Konu etiketi artık dinamik!
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                              child: Text(
                                widget.topic ?? "Deneme Sınavı", // "Anatomi" yerine dinamik metin
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
                    Expanded(child: Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _nextQuestion, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text(_currentQuestionIndex == _questions.length - 1 ? "Bitir" : "Sonraki", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))))
                  ]
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOptionButton(int index, String optionText) {
    bool isSelected = _userAnswers[_currentQuestionIndex] == index;
    Color borderColor = isSelected ? const Color(0xFF1565C0) : Colors.transparent;
    Color bgColor = isSelected ? const Color(0xFFE3F2FD) : Colors.white;
    Color textColor = isSelected ? const Color(0xFF1565C0) : Colors.black87;
    
    String optionLetter = String.fromCharCode(65 + index);
    String displayLabel = optionLetter; 
    String displayText = optionText.length > 3 ? optionText.substring(3) : optionText; 

    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Material(color: Colors.transparent, child: InkWell(onTap: () => _selectOption(index), borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor == Colors.transparent ? Colors.white : borderColor, width: 2), borderRadius: BorderRadius.circular(16), boxShadow: isSelected ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Row(children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: isSelected ? textColor.withOpacity(0.2) : Colors.grey[200], shape: BoxShape.circle), child: Text(displayLabel, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? textColor : Colors.grey[600]))), const SizedBox(width: 16), Expanded(child: Text(displayText, style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 15))), if (isSelected) Icon(Icons.check_circle_outline, color: textColor)])))));
  }
}