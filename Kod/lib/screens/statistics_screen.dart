import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:intl/intl.dart'; // Tarih formatı için ekledik (pubspec.yaml'a eklemelisin: intl: ^0.18.0)
import '/services/theme_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // --- Veri Değişkenleri ---
  bool _isLoading = true;
  int _totalSolved = 0;
  int _totalCorrect = 0;
  int _totalWrong = 0;
  
  // Varsayılan boş veri (Dersler yüklenene kadar veya hiç çözülmemişse)
  Map<String, double> _subjectPerformance = {};
  
  // Grafik için varsayılan boş liste
  List<FlSpot> _weeklyProgress = [];
  List<String> _weeklyLabels = []; // X ekseni etiketleri (Pzt, Sal...)

  @override
  void initState() {
    super.initState();
    _fetchRealStatistics();
  }

Future<void> _fetchRealStatistics() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        // 1. Temel Sayaçlar (Yoksa 0 ata)
        int solved = data['totalSolved'] ?? 0;
        int correct = data['totalCorrect'] ?? 0;

        // "stats" haritasını güvenli çek. Eğer yoksa boş map ata.
        Map<String, dynamic> stats = (data['stats'] is Map<String, dynamic>) 
            ? data['stats'] as Map<String, dynamic> 
            : {};

        // ----------------------------------------------------
        // 2. Ders Bazlı Performans İşleme
        // ----------------------------------------------------
        Map<String, double> newSubjectPerf = {};
        
        if (stats.containsKey('subjects') && stats['subjects'] is Map) {
          Map<String, dynamic> subjects = stats['subjects'] as Map<String, dynamic>;

          subjects.forEach((key, value) {
            // value şuna benzer: { "correct": 10, "total": 20 }
            if (value is Map) {
              int sTotal = value['total'] ?? 0;
              int sCorrect = value['correct'] ?? 0;

              if (sTotal > 0) {
                newSubjectPerf[key] = sCorrect / sTotal; // Örn: 0.85
              } else {
                newSubjectPerf[key] = 0.0;
              }
            }
          });
        }

        // ----------------------------------------------------
        // 3. Haftalık Grafik Verisi Hazırlama (Son 7 Gün)
        // ----------------------------------------------------
        List<FlSpot> spots = [];
        List<String> labels = [];
        
        // stats['dailyHistory'] verisini güvenli al
        Map<String, dynamic> history = (stats['dailyHistory'] is Map<String, dynamic>) 
            ? stats['dailyHistory'] as Map<String, dynamic> 
            : {};

        DateTime now = DateTime.now();
        
        // Bugünden geriye 7 gün git
        for (int i = 6; i >= 0; i--) {
          DateTime dateToCheck = now.subtract(Duration(days: i));
          
          // ResultScreen'de kaydettiğimiz format: "2024-02-10"
          String dateKey = DateFormat('yyyy-MM-dd').format(dateToCheck);
          
          // Grafik altında görünecek gün ismi: "Pzt", "Sal"
          // 'tr_TR' kullanmak için main.dart'ta initializeDateFormatting yapılmış olmalı,
          // yapılmadıysa varsayılan dil İngilizce görünür (Mon, Tue).
          String dayLabel = DateFormat('EEE', 'tr_TR').format(dateToCheck);

          // O günkü çözülen sayıyı al, yoksa 0
          double solvedCount = 0;
          if (history.containsKey(dateKey)) {
             solvedCount = (history[dateKey] as num).toDouble();
          }

          // X ekseni: 0, 1, 2...6 (Grafikte soldan sağa dizilim)
          // Y ekseni: Çözülen soru sayısı
          spots.add(FlSpot((6 - i).toDouble(), solvedCount));
          labels.add(dayLabel);
        }

        if (mounted) {
          setState(() {
            _totalSolved = solved;
            _totalCorrect = correct;
            _totalWrong = solved - correct; // Basit hesap
            _subjectPerformance = newSubjectPerf;
            _weeklyProgress = spots;
            _weeklyLabels = labels;
            _isLoading = false;
          });
        }
      } else {
        // Kullanıcı dökümanı yoksa yüklemeyi bitir
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("İstatistik hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.instance;
    final isDarkMode = themeProvider.isDarkMode;

    Widget background = isDarkMode 
      ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E14), Color(0xFF161B22)]
            )
          ),
        )
      : Container(color: const Color.fromARGB(255, 236, 242, 255));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("DUS Analiz", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          background,
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_totalSolved == 0)
             _buildEmptyState(isDarkMode) // Hiç soru çözülmemişse
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 30),
              child: Column(
                children: [
                  _buildGlassContainer(
                    isDark: isDarkMode,
                    child: _buildSuccessSummary(isDarkMode),
                  ),
                  
                  const SizedBox(height: 20),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard("Toplam Soru", "$_totalSolved", Icons.assignment, Colors.blue, isDarkMode),
                      _buildStatCard("Doğru", "$_totalCorrect", Icons.check_circle, Colors.green, isDarkMode),
                      _buildStatCard("Yanlış", "$_totalWrong", Icons.cancel, Colors.red, isDarkMode),
                      // Net hesabı: DUS'ta 4 yanlış 1 doğruyu götürmez genelde ama YÖK dil vb. mantığıyla kalmışsa:
                      _buildStatCard("Başarı", "%${((_totalCorrect/_totalSolved)*100).toStringAsFixed(1)}", Icons.timeline, Colors.orange, isDarkMode),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Haftalık Aktivite 🔥", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassContainer(
                    isDark: isDarkMode,
                    padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
                    child: AspectRatio(
                      aspectRatio: 1.7,
                      child: _buildLineChart(isDarkMode),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Ders Bazlı Başarım 📚", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassContainer(
                    isDark: isDarkMode,
                    child: _subjectPerformance.isEmpty 
                      ? const Text("Henüz ders bazlı veri oluşmadı.")
                      : Column(
                          children: _subjectPerformance.entries.map((entry) {
                            return _buildSubjectBar(entry.key, entry.value, isDarkMode);
                          }).toList(),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: isDark ? Colors.white24 : Colors.grey),
          const SizedBox(height: 20),
          Text("Henüz veri yok!", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Test çözdükçe istatistiklerin burada belirecek.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSuccessSummary(bool isDark) {
    double successRate = _totalSolved == 0 ? 0 : (_totalCorrect / _totalSolved);
    
    // En iyi ve en kötü dersi bulma
    String bestSubject = "-";
    String worstSubject = "-";
    if (_subjectPerformance.isNotEmpty) {
      var sortedEntries = _subjectPerformance.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Büyükten küçüğe
      bestSubject = sortedEntries.first.key;
      worstSubject = sortedEntries.last.key;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        CircularPercentIndicator(
          radius: 60.0,
          lineWidth: 10.0,
          animation: true,
          percent: successRate,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "%${(successRate * 100).toInt()}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0, color: isDark ? Colors.white : Colors.black),
              ),
              Text("Genel", style: TextStyle(fontSize: 12.0, color: isDark ? Colors.white60 : Colors.grey)),
            ],
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: const Color(0xFF00C6FF),
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Analiz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLegendItem(Icons.arrow_upward, Colors.green, "En İyi: $bestSubject"),
            const SizedBox(height: 4),
            _buildLegendItem(Icons.arrow_downward, Colors.red, "Geliştir: $worstSubject"),
            const SizedBox(height: 8),
          ],
        )
      ],
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2732) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLineChart(bool isDark) {
    List<Color> gradientColors = [const Color(0xFF23b6e6), const Color(0xFF02d39a)];

    if (_weeklyProgress.isEmpty) {
      return Center(child: Text("Veri yok", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
    }

    // Y ekseni için maksimum değeri bul (grafik taşmasın)
    double maxY = _weeklyProgress.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 10; // Hiç veri yoksa düz çizgi olmasın

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.white10 : Colors.grey.shade300, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < _weeklyLabels.length) {
                  // Sadece baş, orta ve son etiketleri veya hepsini (yer varsa) göster
                  return Text(_weeklyLabels[index], style: TextStyle(fontSize: 10, color: isDark? Colors.white70 : Colors.black54));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6, // 7 gün için 0..6
        minY: 0,
        maxY: maxY * 1.2, // Biraz boşluk bırak
        lineBarsData: [
          LineChartBarData(
            spots: _weeklyProgress,
            isCurved: true,
            gradient: LinearGradient(colors: gradientColors),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true), // Noktaları göster ki veri belli olsun
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(colors: gradientColors.map((color) => color.withOpacity(0.3)).toList()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBar(String subject, double percent, bool isDark) {
    Color getColor(double p) {
      if (p >= 0.75) return Colors.green;
      if (p >= 0.50) return Colors.orange;
      return Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subject, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
              Text("%${(percent * 100).toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: getColor(percent))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(getColor(percent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDark, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    if (!isDark) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}