import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/theme_provider.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  // Performans için static formatlayıcılar
  static final DateFormat _ymdFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dayMonthFormat = DateFormat('d MMM');
  static final DateFormat _dayNameFormat = DateFormat('E');

  // ... _processPremiumData fonksiyonu (Veri işleme mantığı) ...
  Map<String, dynamic> _processPremiumData(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return {};

    int totalCorrect = 0;
    int totalWrong = 0;
    int totalEmpty = 0;
    int totalQuestions = 0;
    
    Map<String, Map<String, dynamic>> subjectData = {};
    List<FlSpot> trendSpots = [];
    List<double> recentNets = [];
    
    Map<String, int> dailyActivity = {};
    DateTime now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      dailyActivity[_ymdFormat.format(now.subtract(Duration(days: i)))] = 0;
    }

    List<String> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      last7Days.add(_dayMonthFormat.format(now.subtract(Duration(days: i))));
    }

    Map<String, double> dailyNets = {};
    Map<String, int> dailyCounts = {};
    for (int i = 6; i >= 0; i--) {
      String dayKey = _ymdFormat.format(now.subtract(Duration(days: i)));
      dailyNets[dayKey] = 0;
      dailyCounts[dayKey] = 0;
    }

    Map<String, int> timeOfDayStats = {
      'Sabah': 0, 'Öğlen': 0, 'Akşam': 0, 'Gece': 0
    };
    
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      
      int c = data['correct'] ?? 0;
      int w = data['wrong'] ?? 0;
      int e = data['empty'] ?? 0;
      int t = data['total'] ?? (c + w + e);
      if (t == 0) continue;

      String topic = data['topic'] ?? "Genel";
      DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      String dayKey = _ymdFormat.format(date);
      
      int hour = date.hour;
      String timeSlot;
      if (hour < 12) {
        timeSlot = 'Sabah';
      } else if (hour < 17) {
        timeSlot = 'Öğlen';
      } else if (hour < 21) {
        timeSlot = 'Akşam';
      } else {
        timeSlot = 'Gece';
      }
      timeOfDayStats[timeSlot] = (timeOfDayStats[timeSlot] ?? 0) + 1;

      totalCorrect += c;
      totalWrong += w;
      totalEmpty += e;
      totalQuestions += t;

      double net = c - (w * 0.25);
      if (net < 0) net = 0;
      double accuracy = c / t;

      if (!subjectData.containsKey(topic)) {
        subjectData[topic] = {
          'correct': 0,
          'wrong': 0,
          'empty': 0,
          'total': 0,
          'nets': [],
          'accuracies': [],
          'lastAttempt': date,
          'testCount': 0,
        };
      }
      
      var topicStats = subjectData[topic]!;
      topicStats['correct'] += c;
      topicStats['wrong'] += w;
      topicStats['empty'] += e;
      topicStats['total'] += t;
      topicStats['nets'].add(net);
      topicStats['accuracies'].add(accuracy);
      topicStats['testCount'] += 1;
      
      if (date.isAfter(topicStats['lastAttempt'])) {
        topicStats['lastAttempt'] = date;
      }

      if (dailyActivity.containsKey(dayKey)) {
        dailyActivity[dayKey] = (dailyActivity[dayKey] ?? 0) + t;
      }

      if (dailyNets.containsKey(dayKey)) {
        dailyNets[dayKey] = (dailyNets[dayKey] ?? 0) + net;
        dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
      }
    }

    trendSpots = [];
    recentNets = [];
    int spotIndex = 0;
    for (int i = 6; i >= 0; i--) {
      String dayKey = _ymdFormat.format(now.subtract(Duration(days: i)));
      double totalNet = dailyNets[dayKey] ?? 0;
      int count = dailyCounts[dayKey] ?? 0;
      double avgNetForDay = count > 0 ? totalNet / count : 0;
      trendSpots.add(FlSpot(spotIndex.toDouble(), avgNetForDay));
      recentNets.add(avgNetForDay);
      spotIndex++;
    }

    double avgNet = 0;
    var validNets = recentNets.where((n) => n > 0);
    if (validNets.isNotEmpty) {
        avgNet = validNets.reduce((a, b) => a + b) / validNets.length;
    }
    
    double overallAccuracy = totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;
    
    String trend = "Stabil";
    List<double> nonZeroNets = validNets.toList();
    
    if (nonZeroNets.length >= 3) {
      int halfPoint = nonZeroNets.length ~/ 2;
      if (halfPoint > 0) {
        var firstHalfList = nonZeroNets.sublist(0, halfPoint);
        var secondHalfList = nonZeroNets.sublist(halfPoint);
        
        double firstHalf = firstHalfList.reduce((a, b) => a + b) / firstHalfList.length;
        double secondHalf = secondHalfList.reduce((a, b) => a + b) / secondHalfList.length;
        
        double change = firstHalf > 0 ? ((secondHalf - firstHalf) / firstHalf) * 100 : 0;
        
        if (change > 10) trend = "Yükseliş";
        else if (change < -10) trend = "Düşüş";
      }
    }

    List<Map<String, dynamic>> topicInsights = [];
    subjectData.forEach((topic, stats) {
      List<double> nets = stats['nets'].cast<double>();
      List<double> accuracies = stats['accuracies'].cast<double>();
      
      double avgAcc = accuracies.reduce((a, b) => a + b) / accuracies.length;
      double avgTopicNet = nets.reduce((a, b) => a + b) / nets.length;
      
      String improvement = "→";
      if (nets.length >= 6) {
        double early = nets.take(3).reduce((a, b) => a + b) / 3;
        double recent = nets.skip(nets.length - 3).reduce((a, b) => a + b) / 3;
        if (recent > early * 1.15) improvement = "↗️";
        else if (recent < early * 0.85) improvement = "↘️";
      }
      
      String status;
      Color color;
      String recommendation;

      if (avgAcc >= 0.85) {
        status = "🔥 Uzman";
        color = const Color(0xFF10b981);
        recommendation = "Mükemmel! Hızlanmaya odaklan.";
      } else if (avgAcc >= 0.70) {
        status = "✅ İyi";
        color = const Color(0xFF3b82f6);
        recommendation = "İyi gidiyorsun, pekiştirmeye devam!";
      } else if (avgAcc < 0.50) {
        status = "⚠️ Kritik";
        color = const Color(0xFFef4444);
        recommendation = "Acil konu tekrarı gerekiyor.";
      } else {
        status = "🔨 Gelişmeli";
        color = const Color(0xFFf59e0b);
        recommendation = "Biraz daha pratikle halledersin.";
      }

      int daysSinceLastAttempt = now.difference(stats['lastAttempt']).inDays;
      bool needsAttention = daysSinceLastAttempt > 7;

      topicInsights.add({
        'topic': topic,
        'average': avgAcc,
        'avgNet': avgTopicNet,
        'status': status,
        'color': color,
        'count': stats['testCount'],
        'improvement': improvement,
        'recommendation': recommendation,
        'correct': stats['correct'],
        'wrong': stats['wrong'],
        'empty': stats['empty'],
        'total': stats['total'],
        'daysSince': daysSinceLastAttempt,
        'needsAttention': needsAttention,
      });
    });

    topicInsights.sort((a, b) => b['average'].compareTo(a['average']));

    String bestTimeOfDay = timeOfDayStats.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'totalQuestions': totalQuestions,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'totalEmpty': totalEmpty,
      'totalNet': totalCorrect - (totalWrong * 0.25),
      'avgNet': avgNet,
      'avgAccuracy': overallAccuracy,
      'trendSpots': trendSpots,
      'trendDates': last7Days,
      'topicInsights': topicInsights,
      'dailyActivity': dailyActivity.values.toList(),
      'dailyLabels': dailyActivity.keys.map((k) => _dayNameFormat.format(DateTime.parse(k))).toList(),
      'trend': trend,
      'testCount': docs.length,
      'bestTimeOfDay': bestTimeOfDay,
      'timeOfDayStats': timeOfDayStats,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DÜZELTME 1: Dinamik Üst Boşluk Hesabı (Notch + AppBar + 20px)
    // Bu sayede "Performans Analizi" yazısı içeriğin üstüne binmez.
    final double topContentPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 20;

    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) {
        final theme = ThemeProvider.instance;
        final isDark = theme.isDarkMode;
        final user = FirebaseAuth.instance.currentUser;

        final bgColors = isDark 
            ? [const Color(0xFF0A0E14), const Color(0xFF161B22)] 
            : [const Color(0xFFfafafa), const Color(0xFFf5f5f5)];
        
        final textColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1e293b);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text("Performans Analizi", style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textColor, fontSize: 20)),
            centerTitle: true,
            backgroundColor: Colors.transparent, 
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: (isDark ? const Color(0xFF0A0E14) : Colors.white).withOpacity(0.5),
                ),
              ),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bgColors)),
            child: user == null 
                ? const Center(child: Text("Giriş yapmalısınız."))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('results')
                        .orderBy('timestamp', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState(isDark);
                      }

                      var analytics = _processPremiumData(snapshot.data!.docs);
                      if (analytics.isEmpty) return _buildEmptyState(isDark);

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        // 🔥 DÜZELTME 2: 
                        // top: topContentPadding (Dinamik üst boşluk)
                        // bottom: 150 (Dashboard üstüne binmemesi için güvenli alan)
                        padding: EdgeInsets.only(top: topContentPadding, left: 16, right: 16, bottom: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMotivationalHeader(analytics, isDark, textColor),
                            const SizedBox(height: 20),

                            _buildMainMetrics(analytics, isDark),
                            const SizedBox(height: 24),

                            _buildSectionTitle("Son 7 Günlük Net Trendi", "Günlük ortalama net değişimlerin", isDark, textColor),
                            const SizedBox(height: 12),
                            _buildGlassContainer(
                              height: 260,
                              isDark: isDark,
                              child: _buildTrendChart(analytics['trendSpots'], analytics['trendDates'], analytics['avgNet'], isDark),
                            ),
                            const SizedBox(height: 24),

                            _buildSectionTitle("7 Günlük Çalışma Ritmi", "Düzenli çalışma başarının anahtarı", isDark, textColor),
                            const SizedBox(height: 12),
                            _buildWeeklyActivity(analytics['dailyActivity'], analytics['dailyLabels'], isDark),
                            const SizedBox(height: 24),

                            _buildStatsGrid(analytics, isDark),
                            const SizedBox(height: 24),

                            _buildSectionTitle("Konu Bazlı Detaylı Analiz", "Güçlü ve zayıf yönlerini keşfet", isDark, textColor),
                            const SizedBox(height: 12),
                            ...(analytics['topicInsights'] as List).map((topic) {
                              return _buildTopicCard(topic, isDark);
                            }).toList(),

                            const SizedBox(height: 24),
                            _buildActionableInsights(analytics, isDark, textColor),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      }
    );
  }

  // --- Yardımcı Widget'lar (Değişiklik yok) ---

  Widget _buildMotivationalHeader(Map<String, dynamic> data, bool isDark, Color textColor) {
    String trend = data['trend'];
    IconData trendIcon = trend == "Yükseliş" ? Icons.trending_up : trend == "Düşüş" ? Icons.trending_down : Icons.trending_flat;
    Color trendColor = trend == "Yükseliş" ? const Color(0xFF69F0AE) : trend == "Düşüş" ? const Color(0xFFFF5252) : const Color(0xFFFFD740);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF2563EB).withOpacity(0.8), const Color(0xFF7C3AED).withOpacity(0.8)]
              : [const Color(0xFF60a5fa), const Color(0xFFa78bfa)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: (isDark ? Colors.black : Colors.blue).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
        ],
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Genel Performansın", style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  "${data['totalNet'].toStringAsFixed(1)} Net",
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, color: trendColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        trend,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_graph, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE6EDF3) : Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainMetrics(Map<String, dynamic> data, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            "Ortalama Net",
            data['avgNet'].toStringAsFixed(1),
            Icons.analytics_outlined,
            const Color(0xFF3b82f6),
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            "Başarı Oranı",
            "%${(data['avgAccuracy'] * 100).toInt()}",
            Icons.check_circle_outline,
            const Color(0xFF10b981),
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            "Test Sayısı",
            "${data['testCount']}",
            Icons.quiz_outlined,
            const Color(0xFFf59e0b),
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildTrendChart(List<FlSpot> spots, List<String> dates, double avgNet, bool isDark) {
    if (spots.isEmpty) return Center(child: Text("Veri Yok", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));

    double rawMaxY = spots.map((s) => s.y).reduce(max);
    double maxY = (rawMaxY + 0.5).ceilToDouble();
    if (maxY < 4) maxY = 4;
    double minY = 0;

    double interval = 1;
    if (maxY > 10) interval = (maxY / 5).ceilToDouble();
    if (maxY % interval != 0) maxY = ((maxY ~/ interval) + 1) * interval;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3b82f6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3b82f6).withOpacity(0.3))
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.show_chart, size: 14, color: Color(0xFF3b82f6)),
                const SizedBox(width: 6),
                Text(
                  "Ortalama: ${avgNet.toStringAsFixed(1)}",
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF3b82f6) : const Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
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
                        if (index >= 0 && index < dates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              dates[index],
                              style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        String text = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
                        return Text(
                          text,
                          style: GoogleFonts.robotoMono(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchSpotThreshold: 20,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => isDark ? const Color(0xFF1F2937) : Colors.white,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipBorder: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        if (spot.barIndex == 0) {
                          int index = spot.x.toInt();
                          String date = index < dates.length ? dates[index] : "";
                          return LineTooltipItem(
                            "$date\n${spot.y.toStringAsFixed(1)} net",
                            GoogleFonts.inter(color: const Color(0xFF3b82f6), fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        } else {
                          return LineTooltipItem(
                            "Ort: ${spot.y.toStringAsFixed(1)}",
                            GoogleFonts.inter(color: const Color(0xFFf59e0b), fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF3b82f6),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF161B22),
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF3b82f6),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3b82f6).withOpacity(0.3),
                          const Color(0xFF3b82f6).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: [FlSpot(0, avgNet), FlSpot(spots.length - 1, avgNet)],
                    isCurved: false,
                    color: const Color(0xFFf59e0b).withOpacity(0.5),
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivity(List<int> activities, List<String> labels, bool isDark) {
    int maxActivity = activities.reduce(max);
    if (maxActivity == 0) maxActivity = 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(activities.length, (index) {
                    int count = activities[index];
                    double heightFactor = count / maxActivity;
                    if (count > 0 && heightFactor < 0.15) heightFactor = 0.15;

                    bool isToday = index == activities.length - 1;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text(
                            '$count',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              color: isToday ? const Color(0xFF3b82f6) : (isDark ? Colors.white38 : Colors.grey),
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            width: 24,
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: count == 0 ? 0.05 : heightFactor,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: count == 0
                                        ? [isDark ? Colors.white10 : Colors.grey.shade300, isDark ? Colors.white10 : Colors.grey.shade300]
                                        : isToday
                                            ? [const Color(0xFF3b82f6), const Color(0xFF8b5cf6)]
                                            : [const Color(0xFF60a5fa).withOpacity(0.7), const Color(0xFF3b82f6).withOpacity(0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[index],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isToday ? const Color(0xFF3b82f6) : (isDark ? Colors.white38 : Colors.grey),
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem("Toplam Soru", "${data['totalQuestions']}", Icons.quiz, const Color(0xFF8b5cf6), isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatItem("Doğru", "${data['totalCorrect']}", Icons.check_circle, const Color(0xFF10b981), isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem("Yanlış", "${data['totalWrong']}", Icons.cancel, const Color(0xFFef4444), isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatItem("Boş", "${data['totalEmpty']}", Icons.remove_circle_outline, const Color(0xFFf59e0b), isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE6EDF3) : Colors.black87),
                    ),
                    Text(label, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> data, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (data['color'] as Color).withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(color: (data['color'] as Color).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: data['color'],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['topic'],
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFE6EDF3) : Colors.black87),
                              ),
                            ),
                            Text(
                              data['improvement'],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${data['count']} test • ${data['status']}",
                          style: GoogleFonts.inter(fontSize: 12, color: data['color'], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (data['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (data['color'] as Color).withOpacity(0.2))
                    ),
                    child: Column(
                      children: [
                        Text(
                          "%${(data['average'] * 100).toInt()}",
                          style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold, color: data['color']),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : (data['color'] as Color).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStat("Ortalama", data['avgNet'].toStringAsFixed(1), isDark),
                        _buildMiniStat("Doğru", "${data['correct']}", isDark),
                        _buildMiniStat("Yanlış", "${data['wrong']}", isDark),
                        _buildMiniStat("Boş", "${data['empty']}", isDark),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (data['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: data['color']),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['recommendation'],
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFFE6EDF3) : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data['needsAttention'])
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFf59e0b)),
                            const SizedBox(width: 6),
                            Text(
                              "${data['daysSince']} gündür bu konuyla ilgili test çözmedin!",
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFf59e0b), fontWeight: FontWeight.w600),
                            ),
                          ],
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

  Widget _buildMiniStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE6EDF3) : Colors.black87)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey)),
      ],
    );
  }

  Widget _buildActionableInsights(Map<String, dynamic> data, bool isDark, Color textColor) {
    List<Map<String, dynamic>> insights = [];
    
    var topics = data['topicInsights'] as List;
    if (topics.isNotEmpty) {
      var weakest = topics.last;
      if (weakest['average'] < 0.6) {
        insights.add({
          'icon': Icons.school,
          'title': 'Öncelikli Konu',
          'message': '${weakest['topic']} konusuna yoğunlaş (%${(weakest['average'] * 100).toInt()} başarı)',
          'color': const Color(0xFFef4444),
        });
      }
    }

    if (data['trend'] == 'Düşüş') {
      insights.add({
        'icon': Icons.trending_down,
        'title': 'Performans Düşüşü',
        'message': 'Son testlerinde düşüş var. Dinlen ve strateji değiştir.',
        'color': const Color(0xFFf59e0b),
      });
    }

    insights.add({
      'icon': Icons.access_time,
      'title': 'En Verimli Saatin',
      'message': '${data['bestTimeOfDay']} saatlerinde daha iyi performans gösteriyorsun.',
      'color': const Color(0xFF3b82f6),
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("💡 Akıllı Öneriler", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        ...insights.map((insight) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (insight['color'] as Color).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(color: (insight['color'] as Color).withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (insight['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(insight['icon'], color: insight['color'], size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(insight['title'], style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE6EDF3) : Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(insight['message'], style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDark, double? height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22).withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 8))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 100, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
          const SizedBox(height: 20),
          Text("Henüz Test Çözmedin", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
          const SizedBox(height: 8),
          Text("Test çözmeye başladığında analizlerin burada görünecek", style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey)),
        ],
      ),
    );
  }
}