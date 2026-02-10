import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/theme_provider.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with WidgetsBindingObserver {
  // --- Veri Değişkenleri ---
  bool _isLoading = true;
  int _totalSolved = 0;
  int _totalCorrect = 0;
  int _totalWrong = 0;
  
  Map<String, double> _subjectPerformance = {}; 
  List<FlSpot> _weeklyProgress = []; 
  List<String> _weeklyLabels = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _calculateFirebaseStatistics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _calculateFirebaseStatistics();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateFirebaseStatistics();
  }

  Future<void> _calculateFirebaseStatistics() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('results')
          .get();

      // 🔥 SIFIRLAMA KONTROLÜ: Eğer hiç kayıt yoksa ekranı temizle
      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _totalSolved = 0;
            _totalCorrect = 0;
            _totalWrong = 0;
            _subjectPerformance = {};
            _weeklyProgress = [];
            _weeklyLabels = [];
            _isLoading = false;
          });
        }
        return;
      }

      int tSolved = 0;
      int tCorrect = 0;
      int tWrong = 0;
      
      Map<String, int> subjectCorrectCounts = {};
      Map<String, int> subjectTotalCounts = {};
      Map<String, int> dailyCounts = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        
        int correct = data['correct'] ?? 0;
        int wrong = data['wrong'] ?? 0;
        int total = correct + wrong;
        String topic = data['topic'] ?? "Genel";
        String? dateStr = data['date']; 

        tSolved += total;
        tCorrect += correct;
        tWrong += wrong;

        subjectCorrectCounts[topic] = (subjectCorrectCounts[topic] ?? 0) + correct;
        subjectTotalCounts[topic] = (subjectTotalCounts[topic] ?? 0) + total;

        if (dateStr != null) {
          DateTime date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            date = DateTime.now();
          }
          String dayKey = DateFormat('yyyy-MM-dd').format(date);
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + total;
        }
      }

      Map<String, double> finalSubjectPerf = {};
      subjectTotalCounts.forEach((topic, total) {
        if (total > 0) {
          int correct = subjectCorrectCounts[topic] ?? 0;
          finalSubjectPerf[topic] = correct / total;
        }
      });

      List<FlSpot> spots = [];
      List<String> labels = [];
      DateTime now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        DateTime d = now.subtract(Duration(days: i));
        String dayKey = DateFormat('yyyy-MM-dd').format(d);
        String label = DateFormat('EEE', 'tr_TR').format(d);

        double count = (dailyCounts[dayKey] ?? 0).toDouble();
        
        spots.add(FlSpot((6 - i).toDouble(), count));
        labels.add(label);
      }

      if (mounted) {
        setState(() {
          _totalSolved = tSolved;
          _totalCorrect = tCorrect;
          _totalWrong = tWrong;
          _subjectPerformance = finalSubjectPerf;
          _weeklyProgress = spots;
          _weeklyLabels = labels;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Analiz hatası: $e");
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
        title: Text("Performans Analizi", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        // 🔥 YENİLEME BUTONU (SAĞ ÜST)
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white : Colors.black87),
            onPressed: () {
              setState(() => _isLoading = true);
              _calculateFirebaseStatistics();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          background,
          
          // 🔥 Pull-to-Refresh Özelliği Eklendi
          RefreshIndicator(
            onRefresh: _calculateFirebaseStatistics,
            color: Colors.orange,
            backgroundColor: isDarkMode ? const Color(0xFF1E2732) : Colors.white,
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _totalSolved == 0
                 // Boş durumda da aşağı çekilip yenilenebilmesi için ListView içinde sarmaladık
                 ? LayoutBuilder(
                     builder: (context, constraints) => SingleChildScrollView(
                       physics: const AlwaysScrollableScrollPhysics(),
                       child: SizedBox(
                         height: constraints.maxHeight,
                         child: _buildEmptyState(isDarkMode),
                       ),
                     ),
                   )
                 : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(), // Her zaman kaydırılabilir olsun
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
                    child: Column(
                      children: [
                        // 1. GENEL BAŞARI CHART
                        _buildGlassContainer(
                          isDark: isDarkMode,
                          child: _buildSuccessSummary(isDarkMode),
                        ),
                        
                        const SizedBox(height: 20),

                        // 2. KARTLAR
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
                            _buildStatCard("Net", "${(_totalCorrect - (_totalWrong / 4)).toStringAsFixed(1)}", Icons.timeline, Colors.orange, isDarkMode),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 3. HAFTALIK GRAFİK
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Haftalık İlerleme 📈", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
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

                        // 4. DERS PERFORMANSI
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Ders Bazlı Başarı 📚", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                        ),
                        const SizedBox(height: 10),
                        _buildGlassContainer(
                          isDark: isDarkMode,
                          child: Column(
                            children: _subjectPerformance.entries.map((entry) {
                              return _buildSubjectBar(entry.key, entry.value, isDarkMode);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PARÇALARI ---

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: isDark ? Colors.white24 : Colors.grey),
          const SizedBox(height: 20),
          Text("Henüz veri yok!", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Test çözdükçe bulut istatistiklerin burada belirecek.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSuccessSummary(bool isDark) {
    double successRate = _totalSolved == 0 ? 0 : (_totalCorrect / _totalSolved);
    if (successRate > 1.0) successRate = 1.0;
    if (successRate < 0.0) successRate = 0.0;
    
    String bestSubject = "-";
    String worstSubject = "-";
    if (_subjectPerformance.isNotEmpty) {
      var sortedEntries = _subjectPerformance.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
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
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLineChart(bool isDark) {
    List<Color> gradientColors = [const Color(0xFF23b6e6), const Color(0xFF02d39a)];
    
    double maxY = 10;
    if (_weeklyProgress.isNotEmpty) {
       double maxVal = _weeklyProgress.map((e) => e.y).reduce((a, b) => a > b ? a : b);
       maxY = maxVal + 5;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6, 
        minY: 0,
        maxY: maxY,
        
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= _weeklyLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _weeklyLabels[index],
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        borderData: FlBorderData(show: false),
        
        lineBarsData: [
          LineChartBarData(
            spots: _weeklyProgress,
            isCurved: true,
            preventCurveOverShooting: true, 
            gradient: LinearGradient(colors: gradientColors),
            barWidth: 4,
            isStrokeCapRound: true,
            
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: isDark ? Colors.white : Colors.blue,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF23b6e6),
                );
              },
            ),
            
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors.map((c) => c.withOpacity(0.3)).toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBar(String subject, double percent, bool isDark) {
    Color getColor(double p) => p >= 0.75 ? Colors.green : (p >= 0.50 ? Colors.orange : Colors.red);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subject, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
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