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
      dailyActivity[DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)))] = 0;
    }

    // SON 7 GÜNLÜK SABİT TARİHLER
    List<String> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      last7Days.add(DateFormat('d MMM').format(now.subtract(Duration(days: i))));
    }

    // Günlere göre net toplamları
    Map<String, double> dailyNets = {};
    Map<String, int> dailyCounts = {};
    for (int i = 6; i >= 0; i--) {
      String dayKey = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      dailyNets[dayKey] = 0;
      dailyCounts[dayKey] = 0;
    }

    Map<String, int> timeOfDayStats = {
      'Sabah': 0, 'Öğlen': 0, 'Akşam': 0, 'Gece': 0
    };

    List<Map<String, dynamic>> last30Days = [];
    
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      
      int c = data['correct'] ?? 0;
      int w = data['wrong'] ?? 0;
      int e = data['empty'] ?? 0;
      int t = data['total'] ?? (c + w + e);
      if (t == 0) continue;

      String topic = data['topic'] ?? "Genel";
      DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      String dayKey = DateFormat('yyyy-MM-dd').format(date);
      
      int hour = date.hour;
      String timeSlot = hour < 12 ? 'Sabah' : hour < 17 ? 'Öğlen' : hour < 21 ? 'Akşam' : 'Gece';
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
      
      subjectData[topic]!['correct'] += c;
      subjectData[topic]!['wrong'] += w;
      subjectData[topic]!['empty'] += e;
      subjectData[topic]!['total'] += t;
      subjectData[topic]!['nets'].add(net);
      subjectData[topic]!['accuracies'].add(accuracy);
      subjectData[topic]!['testCount'] += 1;
      
      if (date.isAfter(subjectData[topic]!['lastAttempt'])) {
        subjectData[topic]!['lastAttempt'] = date;
      }

      if (dailyActivity.containsKey(dayKey)) {
        dailyActivity[dayKey] = (dailyActivity[dayKey] ?? 0) + t;
      }

      // Günlük net hesabı
      if (dailyNets.containsKey(dayKey)) {
        dailyNets[dayKey] = (dailyNets[dayKey] ?? 0) + net;
        dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
      }
      
      if (now.difference(date).inDays <= 30) {
        last30Days.add({'date': date, 'net': net, 'accuracy': accuracy});
      }
    }

    // Son 7 günlük grafik verisi oluştur
    trendSpots = [];
    recentNets = [];
    int spotIndex = 0;
    for (int i = 6; i >= 0; i--) {
      String dayKey = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      double totalNet = dailyNets[dayKey] ?? 0;
      int count = dailyCounts[dayKey] ?? 0;
      double avgNetForDay = count > 0 ? totalNet / count : 0;
      trendSpots.add(FlSpot(spotIndex.toDouble(), avgNetForDay));
      recentNets.add(avgNetForDay);
      spotIndex++;
    }

    double avgNet = recentNets.isEmpty ? 0 : recentNets.where((n) => n > 0).isEmpty ? 0 : recentNets.where((n) => n > 0).reduce((a, b) => a + b) / recentNets.where((n) => n > 0).length;
    double overallAccuracy = totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;
    
    String trend = "Stabil";
    List<double> nonZeroNets = recentNets.where((n) => n > 0).toList();
    if (nonZeroNets.length >= 3) {
      int halfPoint = nonZeroNets.length ~/ 2;
      if (halfPoint > 0) {
        double firstHalf = nonZeroNets.take(halfPoint).reduce((a, b) => a + b) / halfPoint;
        double secondHalf = nonZeroNets.skip(halfPoint).reduce((a, b) => a + b) / (nonZeroNets.length - halfPoint);
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
      
      String status = "🔨 Gelişmeli";
      Color color = Colors.orange;
      String recommendation = "";

      if (avgAcc >= 0.85) {
        status = "🔥 Uzman";
        color = const Color(0xFF10b981);
        recommendation = "Mükemmel! Bu konuyu hızlı çözmeye devam et.";
      } else if (avgAcc >= 0.70) {
        status = "✅ İyi";
        color = const Color(0xFF3b82f6);
        recommendation = "İyi gidiyorsun, pekiştirmeye devam!";
      } else if (avgAcc < 0.50) {
        status = "⚠️ Kritik";
        color = const Color(0xFFef4444);
        recommendation = "Acil çalışma gerekiyor! Temel konuları tekrar et.";
      } else {
        color = const Color(0xFFf59e0b);
        recommendation = "Biraz daha çalışma ile halledebilirsin.";
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

    topicInsights.sort((a, b) => a['average'].compareTo(b['average']));

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
      'dailyLabels': dailyActivity.keys.map((k) => DateFormat('E').format(DateTime.parse(k))).toList(),
      'trend': trend,
      'testCount': docs.length,
      'bestTimeOfDay': bestTimeOfDay,
      'timeOfDayStats': timeOfDayStats,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final isDark = theme.isDarkMode;
    final user = FirebaseAuth.instance.currentUser;

    final bgColors = isDark 
        ? [const Color(0xFF0f172a), const Color(0xFF1e293b)] 
        : [const Color(0xFFfafafa), const Color(0xFFf5f5f5)];
    final textColor = isDark ? Colors.white : const Color(0xFF1e293b);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("📊 Performans Analizi", style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textColor, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bgColors)),
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
                    padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 100),
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

  Widget _buildMotivationalHeader(Map<String, dynamic> data, bool isDark, Color textColor) {
    String trend = data['trend'];
    IconData trendIcon = trend == "Yükseliş" ? Icons.trending_up : trend == "Düşüş" ? Icons.trending_down : Icons.trending_flat;
    Color trendColor = trend == "Yükseliş" ? Colors.green : trend == "Düşüş" ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF3b82f6), const Color(0xFF8b5cf6)]
              : [const Color(0xFF60a5fa), const Color(0xFFa78bfa)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
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
                Row(
                  children: [
                    Icon(trendIcon, color: trendColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      trend,
                      style: GoogleFonts.inter(fontSize: 14, color: trendColor, fontWeight: FontWeight.w600),
                    ),
                  ],
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
            child: const Icon(Icons.auto_graph, color: Colors.white, size: 40),
          ),
        ],
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

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.robotoMono(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildTrendChart(List<FlSpot> spots, List<String> dates, double avgNet, bool isDark) {
    if (spots.isEmpty) return const Center(child: Text("Veri Yok"));

    double maxY = spots.map((s) => s.y).reduce(max);
    double minY = spots.map((s) => s.y).reduce(min);
    
    double range = maxY - minY;
    if (range < 5) range = 5;
    maxY = maxY + (range * 0.2);
    minY = minY - (range * 0.1);
    if (minY < 0) minY = 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3b82f6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFf59e0b),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Ortalama: ${avgNet.toStringAsFixed(1)} net",
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600),
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
                  horizontalInterval: (maxY - minY) / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
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
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
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
                      reservedSize: 40,
                      interval: (maxY - minY) / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    left: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => isDark ? const Color(0xFF1e293b) : Colors.white,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        int index = spot.x.toInt();
                        String date = index < dates.length ? dates[index] : "";
                        return LineTooltipItem(
                          "$date\n${spot.y.toStringAsFixed(1)} net",
                          GoogleFonts.inter(
                            color: const Color(0xFF3b82f6),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
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
                        bool isEndPoint = index == 0 || index == spots.length - 1;
                        return FlDotCirclePainter(
                          radius: isEndPoint ? 5 : 3,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF3b82f6),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3b82f6).withOpacity(0.25),
                          const Color(0xFF3b82f6).withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: [FlSpot(0, avgNet), FlSpot(spots.length - 1, avgNet)],
                    isCurved: false,
                    color: const Color(0xFFf59e0b),
                    barWidth: 2,
                    dashArray: [8, 4],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
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
                          color: isToday ? const Color(0xFF3b82f6) : Colors.grey,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Container(
                        width: 28,
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: count == 0 ? 0.1 : heightFactor,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: count == 0
                                    ? [Colors.grey.shade300, Colors.grey.shade300]
                                    : isToday
                                        ? [const Color(0xFF3b82f6), const Color(0xFF8b5cf6)]
                                        : [const Color(0xFF60a5fa), const Color(0xFF3b82f6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isToday ? const Color(0xFF3b82f6) : Colors.grey,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> data, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b).withOpacity(0.7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (data['color'] as Color).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: (data['color'] as Color).withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 50,
                decoration: BoxDecoration(
                  color: data['color'],
                  borderRadius: BorderRadius.circular(3),
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
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        Text(
                          data['improvement'],
                          style: const TextStyle(fontSize: 18),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [(data['color'] as Color).withOpacity(0.2), (data['color'] as Color).withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "%${(data['average'] * 100).toInt()}",
                      style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold, color: data['color']),
                    ),
                    Text(
                      "Başarı",
                      style: GoogleFonts.inter(fontSize: 9, color: data['color']),
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
              color: (data['color'] as Color).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat("Ortalama Net", data['avgNet'].toStringAsFixed(1), isDark),
                    _buildMiniStat("Doğru", "${data['correct']}", isDark),
                    _buildMiniStat("Yanlış", "${data['wrong']}", isDark),
                    _buildMiniStat("Boş", "${data['empty']}", isDark),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (data['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: data['color']),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['recommendation'],
                          style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
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
    );
  }

  Widget _buildMiniStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionableInsights(Map<String, dynamic> data, bool isDark, Color textColor) {
    List<Map<String, dynamic>> insights = [];
    
    var topics = data['topicInsights'] as List;
    if (topics.isNotEmpty) {
      var weakest = topics.first;
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
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1e293b).withOpacity(0.6) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (insight['color'] as Color).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (insight['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(insight['icon'], color: insight['color'], size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insight['title'], style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(insight['message'], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDark, double? height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.1 : 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: child,
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
          Text("Test çözmeye başladığında analizlerin burada görünecek", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}