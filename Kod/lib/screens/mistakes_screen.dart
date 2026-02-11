import 'package:flutter/material.dart';
import '../services/mistakes_service.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';

enum SortOption { newest, oldest, subject, random }

class MistakesDashboard extends StatefulWidget {
  const MistakesDashboard({super.key});

  @override
  State<MistakesDashboard> createState() => _MistakesDashboardState();
}

class _MistakesDashboardState extends State<MistakesDashboard> {
  List<Map<String, dynamic>> _allMistakes = [];
  bool _isLoading = true;

  final Map<String, Color> _subjectColors = {
    "Anatomi": Colors.orange,
    "Histoloji": Colors.pinkAccent,
    "Fizyoloji": Colors.redAccent,
    "Biyokimya": Colors.purple,
    "Mikrobiyoloji": Colors.green,
    "Patoloji": Colors.brown,
    "Farmakoloji": Colors.teal,
    "Biyoloji": Colors.lime,
    "Protetik": Colors.cyan,
    "Restoratif": Colors.lightBlue,
    "Endodonti": Colors.yellow.shade800,
    "Perio": Colors.deepOrange,
    "Ortodonti": Colors.indigo,
    "Pedodonti": Colors.amber,
    "Cerrahi": Colors.red.shade900,
    "Radyoloji": Colors.blueGrey,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var rawMistakes = await MistakesService.getMistakes();
    
    // 🔥 DÜZELTME: ARTIK TEST NUMARASINA DA BAKIYORUZ
    // Böylece Test 1 Soru 1 ile Test 2 Soru 1 birbirini silmeyecek.
    
    Map<String, Map<String, dynamic>> distinctMap = {};

    for (var m in rawMistakes) {
      String topic = m['topic'] ?? "genel";
      int qIndex = m['questionIndex'] ?? 0;
      int testNo = m['testNo'] ?? 0;
      
      // Anahtar artık BENZERSİZ: konu_testNo_soruIndex
      // Örn: anatomi_1_5 (Anatomi Test 1 Soru 5)
      String key = "${topic}_${testNo}_$qIndex";

      // Test 0 sorununu çözmek için ek kontrol:
      // Eğer aynı konu ve sorudan Test 0 varsa ve şimdi Test 1 geldiyse, Test 0'ı sil.
      String zeroKey = "${topic}_0_$qIndex";
      
      if (testNo > 0 && distinctMap.containsKey(zeroKey)) {
        // Test 0 olan hatalı kaydı kaldır, yerine gerçek test nolu olanı koy
        distinctMap.remove(zeroKey);
        distinctMap[key] = m;
      } else {
        // Normal ekleme
        distinctMap[key] = m;
      }
    }
    
    List<Map<String, dynamic>> cleanList = distinctMap.values.toList();
    
    // Tarihe göre sırala (En yeni en üstte)
    cleanList.sort((a, b) {
       var dateA = a['date'] != null ? DateTime.tryParse(a['date'].toString()) : null;
       var dateB = b['date'] != null ? DateTime.tryParse(b['date'].toString()) : null;
       if (dateA == null) return 1;
       if (dateB == null) return -1;
       return dateB.compareTo(dateA);
    });
    
    if (mounted) {
      setState(() {
        _allMistakes = cleanList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Map<String, int> counts = {};
    for (var m in _allMistakes) {
      String sub = m['topic'] ?? m['subject'] ?? "Diğer";
      if(sub.isNotEmpty && sub.length > 1) {
         sub = sub[0].toUpperCase() + sub.substring(1).toLowerCase();
      }
      counts[sub] = (counts[sub] ?? 0) + 1;
    }

    List<String> sortedSubjects = counts.keys.toList();
    sortedSubjects.sort((a, b) => counts[b]!.compareTo(counts[a]!)); 

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFE0F2F1),
      appBar: AppBar(
        title: Text("Eksiklerimi Kapat",
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allMistakes.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryCard(_allMistakes.length),
                        const SizedBox(height: 24),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Derslere Göre Hatalar",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87))),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: sortedSubjects.length,
                          itemBuilder: (context, index) {
                            String subject = sortedSubjects[index];
                            int count = counts[subject] ?? 0;
                            Color color = Colors.teal;
                            for(var key in _subjectColors.keys) {
                              if(subject.toLowerCase().contains(key.toLowerCase())) {
                                color = _subjectColors[key]!;
                                break;
                              }
                            }
                            return _buildSubjectCard(subject, count, color, isDark);
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.teal.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text("Harikasın! Hiç yanlışın yok.",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade700]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          const Text("Toplam Hatalı Soru", style: TextStyle(color: Colors.white70)),
          Text("$total",
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MistakesListScreen(
                          mistakes: _allMistakes, title: "Tüm Yanlışlarım")));
              _loadData(); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
            child: const Text("Hepsini Tekrar Et"),
          )
        ],
      ),
    );
  }

  Widget _buildSubjectCard(String subject, int count, Color color, bool isDark) {
    return GestureDetector(
      onTap: () async {
        var filtered = _allMistakes.where((m) {
          String s = m['topic'] ?? m['subject'] ?? "";
          return s.toLowerCase().contains(subject.toLowerCase());
        }).toList();

        if (filtered.isNotEmpty) {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => MistakesListScreen(mistakes: filtered, title: subject)));
          _loadData();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: isDark ? Colors.black12 : Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, color: color),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(subject,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87)),
            ),
            Text("$count Soru", style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class MistakesListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> mistakes;
  final String title;

  const MistakesListScreen({super.key, required this.mistakes, required this.title});

  @override
  State<MistakesListScreen> createState() => _MistakesListScreenState();
}

class _MistakesListScreenState extends State<MistakesListScreen> {
  late List<Map<String, dynamic>> _currentList;
  SortOption _currentSort = SortOption.newest;

  @override
  void initState() {
    super.initState();
    _currentList = List.from(widget.mistakes);
    _sortList();
  }

  void _sortList() {
    setState(() {
      switch (_currentSort) {
        case SortOption.newest:
          _currentList.sort((a, b) {
            var dateA = a['date'] != null ? DateTime.tryParse(a['date'].toString()) : null;
            var dateB = b['date'] != null ? DateTime.tryParse(b['date'].toString()) : null;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });
          break;
        case SortOption.oldest:
           _currentList.sort((a, b) {
            var dateA = a['date'] != null ? DateTime.tryParse(a['date'].toString()) : null;
            var dateB = b['date'] != null ? DateTime.tryParse(b['date'].toString()) : null;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateA.compareTo(dateB);
          });
          break;
        case SortOption.subject:
          _currentList.sort((a, b) => (a['topic'] ?? "").compareTo(b['topic'] ?? ""));
          break;
        case SortOption.random:
          _currentList.shuffle();
          break;
      }
    });
  }

  void _startMistakeQuiz() async {
    if(_currentList.isEmpty) return;

    List<Question> questionList = _currentList.map<Question>((m) {
      return Question(
        id: m['questionIndex'] ?? 0,
        question: m['question'] ?? "Soru Yüklenemedi",
        options: List<String>.from(m['options'] ?? []),
        answerIndex: m['correctIndex'] ?? 0,
        explanation: m['explanation'] ?? "",
        testNo: m['testNo'] ?? 0,
        level: m['topic'] ?? m['subject'] ?? "Genel",
      );
    }).toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          isTrial: false,
          topic: widget.title,
          questions: questionList,
          userAnswers: null,
          isReviewMode: false,
        ),
      ),
    );
  }

  Future<void> _deleteMistake(Map<String, dynamic> mistake) async {
    // Silme için benzersiz ID'yi kullan (Firebase Document ID'si)
    dynamic id = mistake['id']; 
    String subject = mistake['topic'] ?? mistake['subject'];

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: const Text("Bu soruyu listeden çıkarmak istiyor musun?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hayır")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("Evet, Sil")
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MistakesService.removeMistake(id, subject);
      if (mounted) {
        setState(() {
          _currentList.removeWhere((m) => m['id'] == id);
        });
        if (_currentList.isEmpty) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      floatingActionButton: _currentList.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startMistakeQuiz,
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Yanlışları Çöz"),
            )
          : null,
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _currentList.isEmpty
          ? Center(child: Text("Liste boş! 🎉", style: TextStyle(color: isDark ? Colors.white : Colors.black)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentList.length,
              itemBuilder: (context, index) {
                final mistake = _currentList[index];
                return _buildMistakeCard(mistake, isDark);
              },
            ),
    );
  }

  Widget _buildMistakeCard(Map<String, dynamic> mistake, bool isDark) {
    String questionText = mistake['question'] ?? "Soru yok";
    String topicText = mistake['topic'] ?? mistake['subject'] ?? "";
    if(topicText.isNotEmpty && topicText.length > 1) topicText = topicText[0].toUpperCase() + topicText.substring(1).toLowerCase();
    
    int testNo = mistake['testNo'] ?? 0;
    
    List<String> options = [];
    if (mistake['options'] != null) {
      options = List<String>.from(mistake['options']);
    }
    
    int correctIndex = mistake['correctIndex'] ?? 0;

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                    label: Text("$topicText - Test $testNo", 
                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: Colors.blueGrey,
                    padding: EdgeInsets.zero),
                IconButton(
                  onPressed: () => _deleteMistake(mistake),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(questionText,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            
            const SizedBox(height: 12),
            
            if (options.isNotEmpty)
              ...List.generate(options.length, (i) {
                bool isCorrect = (i == correctIndex);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isCorrect ? Border.all(color: Colors.green.withOpacity(0.6)) : Border.all(color: Colors.grey.withOpacity(0.2))
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${String.fromCharCode(65 + i)}) ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : (isDark ? Colors.white70 : Colors.black87))),
                      Expanded(
                        child: Text(options[i], 
                          style: TextStyle(
                            color: isCorrect ? Colors.green[800] : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal
                          )
                        )
                      ),
                      if (isCorrect) const Icon(Icons.check_circle, size: 18, color: Colors.green)
                    ],
                  ),
                );
              })
            else
              const Text("⚠️ Şık verisi bulunamadı.", style: TextStyle(color: Colors.red, fontSize: 12)),

            if (mistake['explanation'] != null && mistake['explanation'].toString().isNotEmpty) ...[
              const Divider(),
              Text("Açıklama: ${mistake['explanation']}",
                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }
}