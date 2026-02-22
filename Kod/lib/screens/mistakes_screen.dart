import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; 
import '../services/mistakes_service.dart';
import '../services/bookmark_service.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';

// ==========================================
// 1. EKRAN: YANLIŞLARIM KOKPİTİ
// ==========================================

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
    "Anatomi": const Color(0xFFFB8C00),
    "Histoloji": const Color(0xFFEC407A),
    "Fizyoloji": const Color(0xFFEF5350),
    "Biyokimya": const Color(0xFFAB47BC),
    "Mikrobiyoloji": const Color(0xFF66BB6A),
    "Patoloji": const Color(0xFF8D6E63),
    "Farmakoloji": const Color(0xFF26A69A),
    "Biyoloji": const Color(0xFFD4E157),
    "Protetik": const Color(0xFF29B6F6),
    "Restoratif": const Color(0xFF42A5F5),
    "Endodonti": const Color(0xFFFFA726),
    "Perio": const Color(0xFFFF7043),
    "Ortodonti": const Color(0xFF5C6BC0),
    "Pedodonti": const Color(0xFFFFCA28),
    "Cerrahi": const Color(0xFFB71C1C),
    "Radyoloji": const Color(0xFF78909C),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var rawMistakes = await MistakesService.getMistakes();
      Map<String, Map<String, dynamic>> distinctMap = {};
      for (var m in rawMistakes) {
        String topic = m['topic'] ?? "genel";
        int qIndex = m['questionIndex'] ?? 0;
        int testNo = m['testNo'] ?? 0;
        String key = "${topic}_${testNo}_$qIndex";
        String zeroKey = "${topic}_0_$qIndex";
        if (testNo > 0 && distinctMap.containsKey(zeroKey)) {
          distinctMap.remove(zeroKey);
          distinctMap[key] = m;
        } else {
          distinctMap[key] = m;
        }
      }
      List<Map<String, dynamic>> cleanList = distinctMap.values.toList();
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
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    late Map<String, int> counts;
    late List<String> sortedSubjects;

    if (!_isLoading && _allMistakes.isNotEmpty) {
      counts = {};
      for (var m in _allMistakes) {
        String sub = m['topic'] ?? m['subject'] ?? "Diğer";
        sub = _toTitleCase(sub);
        counts[sub] = (counts[sub] ?? 0) + 1;
      }
      sortedSubjects = counts.keys.toList();
      sortedSubjects.sort((a, b) => counts[b]!.compareTo(counts[a]!));
    }

    return Container(
      decoration: isDark 
        ? const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E14), Color(0xFF161B22)],
            ),
          )
        : const BoxDecoration(color: Color.fromARGB(255, 224, 247, 250)),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Burası çok önemli, arka planı şeffaf yaptık
        appBar: AppBar(
        title: Text("Eksiklerimi Kapat",
            style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadData,
            ),
          )
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: isDark ? Colors.white : Colors.teal),
                  const SizedBox(height: 16),
                  Text("Yükleniyor...", style: GoogleFonts.inter(color: textColor.withOpacity(0.6))),
                ],
              ),
            )
          : _allMistakes.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.teal,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(_allMistakes.length, isDark),
                        const SizedBox(height: 32),
                        Text("Ders Analizi",
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.4,
                          ),
                          itemCount: sortedSubjects.length,
                          itemBuilder: (context, index) {
                            String subject = sortedSubjects[index];
                            int count = counts[subject] ?? 0;
                            Color color = Colors.teal;
                            for (var key in _subjectColors.keys) {
                              if (subject.toLowerCase().contains(key.toLowerCase())) {
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
      ), // Scaffold'u kapatıyoruz
    ); // Container'ı kapatıyoruz (Bunu ekledik!)
  }
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded, size: 80, color: Colors.teal.shade400),
          ),
          const SizedBox(height: 24),
          Text("Harikasın!",
              style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text("Hiç yanlışın yok, böyle devam et.",
              style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int total, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF009688), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF009688).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Toplam Hata", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("$total Soru",
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 32),
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MistakesListScreen(mistakes: _allMistakes, title: "Tüm Yanlışlarım")));
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00695C),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Hepsini Tekrar Et", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
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
          await Navigator.push(context,
              MaterialPageRoute(builder: (context) => MistakesListScreen(mistakes: filtered, title: subject)));
          _loadData();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned(right: -10, bottom: -10, child: Icon(Icons.book, size: 60, color: color.withOpacity(0.05))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.bookmark_outline, color: color, size: 20),
                  ),
                  const Spacer(),
                  Text(subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text("$count Soru", style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. EKRAN: YANLIŞ SORULARIN LİSTESİ
// ==========================================

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

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
    if (_currentList.isEmpty) return;
    List<Question> questionList = _currentList.map<Question>((m) {
      String? imageUrl = m['imageUrl'] ?? m['image_url'];
      return Question(
        id: m['questionIndex'] ?? 0,
        question: m['question'] ?? "Soru Yüklenemedi",
        options: List<String>.from(m['options'] ?? []),
        answerIndex: m['correctIndex'] ?? 0,
        explanation: m['explanation'] ?? "",
        testNo: m['testNo'] ?? 0,
        level: m['topic'] ?? m['subject'] ?? "Genel",
        imageUrl: imageUrl,
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
    dynamic id = mistake['id'];
    String subject = mistake['topic'] ?? mistake['subject'];

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Öğrendin mi?"),
        content: const Text(
          "Bu soruyu tamamen kavradıysan listeden silelim. Bir daha karşına çıkmayacak.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Kalsın", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Evet, Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _currentList.removeWhere((m) => m['id'] == id);
      });
      await MistakesService.removeMistake(id, subject);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.celebration, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Süper! Bir eksiği daha kapattın.")),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        if (_currentList.isEmpty) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

    return Container(
      decoration: isDark 
        ? const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E14), Color(0xFF161B22)],
            ),
          )
        : const BoxDecoration(color: Color.fromARGB(255, 224, 247, 250)),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Yine şeffaf yapıyoruz ki arkadaki efekt görünsün
        floatingActionButton: _currentList.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startMistakeQuiz,
              backgroundColor: const Color(0xFF009688),
              elevation: 4,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text("Bu Yanlışları Çöz",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          PopupMenuButton<SortOption>(
            tooltip: "Sırala",
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            icon: Icon(Icons.sort, color: textColor),
            onSelected: (SortOption result) {
              _currentSort = result;
              _sortList();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              PopupMenuItem<SortOption>(
                  value: SortOption.newest,
                  child: Text("Yeniden Eskiye", style: TextStyle(color: textColor))),
              PopupMenuItem<SortOption>(
                  value: SortOption.oldest,
                  child: Text("Eskiden Yeniye", style: TextStyle(color: textColor))),
              PopupMenuItem<SortOption>(
                  value: SortOption.subject,
                  child: Text("Derslere Göre", style: TextStyle(color: textColor))),
              const PopupMenuDivider(),
              PopupMenuItem<SortOption>(
                  value: SortOption.random,
                  child: Text("Karışık Sırala", style: TextStyle(color: textColor))),
            ],
          ),
        ],
      ),
      body: _currentList.isEmpty
          ? Center(child: Text("Liste boş! 🎉", style: GoogleFonts.inter(color: textColor, fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _currentList.length,
              itemBuilder: (context, index) {
                final mistake = _currentList[index];
                return RepaintBoundary(
                    child: _buildMistakeCard(mistake, isDark, cardColor, textColor, subTextColor));
              },
            ),
      ), // Scaffold'u kapatıyoruz
    ); // Container'ı kapatıyoruz (Bunu ekledik!)
  }

  Widget _buildMistakeCard(
    Map<String, dynamic> mistake,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    String questionText = mistake['question'] ?? "Soru yok";
    String topicText = mistake['topic'] ?? mistake['subject'] ?? "";
    topicText = _toTitleCase(topicText);
    int testNo = mistake['testNo'] ?? 0;
    String? imageUrl = mistake['imageUrl'] ?? mistake['image_url'];

    Question questionObj = Question(
      id: mistake['questionIndex'] ?? 0,
      question: questionText,
      options: List<String>.from(mistake['options'] ?? []),
      answerIndex: mistake['correctIndex'] ?? 0,
      level: topicText,
      testNo: testNo,
      explanation: mistake['explanation'] ?? "",
      imageUrl: imageUrl,
    );

    List<String> options = [];
    if (mistake['options'] != null) {
      options = List<String>.from(mistake['options']);
    }

    int correctIndex = mistake['correctIndex'] ?? 0;
    int userIndex = mistake['userIndex'] ?? -1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ DÜZELTME: Konu chip'i ve butonlar ayrı satırlarda
            _buildCardHeader(
              context: context,
              isDark: isDark,
              topicText: topicText,
              testNo: testNo,
              subTextColor: subTextColor,
              questionObj: questionObj,
              mistake: mistake,
            ),

            const SizedBox(height: 14),

            // Soru Metni
            Text(
              questionText,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: textColor),
            ),

            const SizedBox(height: 16),

            // Görsel
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  width: double.infinity,
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            color: Colors.teal,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 50,
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Şıklar
            if (options.isNotEmpty)
              ...List.generate(options.length, (i) {
                bool isCorrect = (i == correctIndex);
                bool isUserWrong = (i == userIndex && !isCorrect);

                Color rowBg = Colors.transparent;
                Color rowBorder = isDark ? Colors.white10 : Colors.grey.shade200;
                IconData? icon;
                Color iconColor = subTextColor;

                if (isCorrect) {
                  rowBg = isDark ? Colors.green.withOpacity(0.15) : const Color(0xFFF0FDF4);
                  rowBorder = Colors.green.withOpacity(0.4);
                  icon = Icons.check_circle;
                  iconColor = Colors.green;
                } else if (isUserWrong) {
                  rowBg = isDark ? Colors.red.withOpacity(0.15) : const Color(0xFFFEF2F2);
                  rowBorder = Colors.red.withOpacity(0.4);
                  icon = Icons.cancel;
                  iconColor = Colors.redAccent;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: rowBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: rowBorder)),
                  child: Row(
                    children: [
                      Text(String.fromCharCode(65 + i),
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: (isCorrect || isUserWrong) ? iconColor : subTextColor)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(options[i],
                              style: GoogleFonts.inter(
                                  color: (isCorrect || isUserWrong)
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : subTextColor,
                                  fontWeight: (isCorrect || isUserWrong)
                                      ? FontWeight.w500
                                      : FontWeight.normal))),
                      if (icon != null) Icon(icon, size: 18, color: iconColor)
                    ],
                  ),
                );
              })
            else
              const Text("⚠️ Şık verisi bulunamadı.", style: TextStyle(color: Colors.red, fontSize: 12)),

            // Açıklama
            if (mistake['explanation'] != null && mistake['explanation'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isDark ? Colors.blueGrey.withOpacity(0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: subTextColor),
                        const SizedBox(width: 8),
                        Text("Açıklama",
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("${mistake['explanation']}",
                        style: GoogleFonts.inter(
                            color: textColor.withOpacity(0.8),
                            fontSize: 13,
                            height: 1.4,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  // ✅ ÇÖZÜM: Kart başlığı ayrı widget — konu chip'i ve butonlar asla çakışmaz
  Widget _buildCardHeader({
    required BuildContext context,
    required bool isDark,
    required String topicText,
    required int testNo,
    required Color subTextColor,
    required Question questionObj,
    required Map<String, dynamic> mistake,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SATIR 1: Konu chip'i (tam genişlik kullanabilir)
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  "$topicText • Test $testNo",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Çok uzun olursa kırpılır, asla taşmaz
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // SATIR 2: Butonlar (sağa hizalı, konu chip'inden bağımsız)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // KAYDET BUTONU
            StreamBuilder<QuerySnapshot>(
              stream: BookmarkService.getBookmarksStream(),
              builder: (context, snapshot) {
                bool isBookmarked = false;
                if (snapshot.hasData) {
                  isBookmarked = snapshot.data!.docs.any((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return data['id'] == questionObj.id;
                  });
                }
                return GestureDetector(
                  onTap: () async {
                    await BookmarkService.toggleBookmark(questionObj, topicText);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(!isBookmarked ? "Soru kaydedildi 📌" : "Kaydedilenlerden çıkarıldı"),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: !isBookmarked ? Colors.green : Colors.grey,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBookmarked
                          ? Colors.orange.withOpacity(isDark ? 0.15 : 0.08)
                          : (isDark ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBookmarked ? Colors.orange.withOpacity(0.5) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 15,
                          color: isBookmarked ? Colors.orange : subTextColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isBookmarked ? "Kaydedildi" : "Kaydet",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isBookmarked ? Colors.orange : subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 8),

            // ÖĞRENDİM BUTONU
            GestureDetector(
              onTap: () => _deleteMistake(mistake),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 15, color: Colors.green.shade600),
                    const SizedBox(width: 5),
                    Text(
                      "Öğrendim",
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
