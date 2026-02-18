import 'dart:ui'; // Blur efektleri için
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../models/achievement_model.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    // Giriş animasyonu için kontrolcü
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
    
    // Verilerin güncelliğinden emin olmak için reload tetiklenebilir (Opsiyonel)
    // AchievementService.instance.reload(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- TEMA AYARLARI ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Premium Renk Paleti
    final backgroundColor = isDarkMode ? const Color(0xFF0A0E14) : const Color(0xFFF5F9FF);
    final textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    final cardColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;

    // 🔥 DÜZELTME BURADA: AnimatedBuilder ile servisi dinliyoruz 🔥
    return AnimatedBuilder(
      animation: AchievementService.instance, // Servis değişikliklerini dinle
      builder: (context, child) {
        // Servisten canlı veriyi alıyoruz (Builder içinde olmalı)
        final achievements = AchievementService.instance.achievements;
        final unlockedCount = achievements.where((a) => a.isUnlocked).length;

        return Scaffold(
          extendBodyBehindAppBar: true, // Glass effect için body yukarı uzar
          backgroundColor: backgroundColor, 
          appBar: AppBar(
            title: Text("Kupa Dolabı", style: TextStyle(fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: backgroundColor.withOpacity(0.5)),
              ),
            ),
          ),
          body: Stack(
            children: [
              // Arka Plan Glow Efekti (Sadece Dark Mode)
              if (isDarkMode)
                Positioned(
                  top: -100, left: -50,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(
                      width: 300, height: 300,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

              Column(
                children: [
                  SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 10), // AppBar boşluğu

                  // --- ÜST BİLGİ KARTI (PREMIUM GRADIENT) ---
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
                      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
                    ),
                    child: FadeTransition(
                      opacity: _controller,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDarkMode 
                              ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)] // Derin Gece Mavisi
                              : [const Color(0xFF2962FF), const Color(0xFF42A5F5)], // Canlı Mavi
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2962FF).withOpacity(0.4), 
                              blurRadius: 20, 
                              offset: const Offset(0, 10)
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.stars_rounded, color: Colors.yellowAccent.shade100, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Toplam Başarı",
                                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "$unlockedCount",
                                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
                                      ),
                                      TextSpan(
                                        text: " / ${achievements.length}",
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.6)),
                                      ),
                                    ]
                                  ),
                                ),
                              ],
                            ),
                            // Kupa İkonu Efekti
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]
                                  ),
                                  child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 48), // Altın Rengi
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- ROZET IZGARASI (GRID) ---
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, 
                        childAspectRatio: 0.75, // Daha uzun, şık kartlar
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: achievements.length,
                      itemBuilder: (context, index) {
                        // Her kart için gecikmeli animasyon
                        final Animation<double> animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: Interval((1 / achievements.length) * index, 1.0, curve: Curves.easeOut),
                          ),
                        );

                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, 50 * (1 - animation.value)), // Aşağıdan yukarı kayma
                            child: Opacity(
                              opacity: animation.value,
                              child: _buildAchievementCard(context, achievements[index], isDarkMode, cardColor),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAchievementCard(BuildContext context, Achievement item, bool isDarkMode, Color cardColor) {
    final titleColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    final descColor = isDarkMode ? Colors.white38 : Colors.grey.shade600;

    // Kilitli/Açık durumuna göre border
    BoxBorder border;
    List<BoxShadow> shadows;

    if (item.isUnlocked) {
      border = Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5);
      shadows = [
        BoxShadow(
          color: Colors.amber.withOpacity(isDarkMode ? 0.15 : 0.2), 
          blurRadius: 15, 
          offset: const Offset(0, 8)
        )
      ];
    } else {
      border = Border.all(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05));
      shadows = [
        BoxShadow(
          color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03), 
          blurRadius: 10, 
          offset: const Offset(0, 5)
        )
      ];
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: border,
        boxShadow: shadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İKON ALANI
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              if (item.isUnlocked)
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]
                  ),
                ),
              
              // İkon Arka Planı
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isUnlocked 
                      ? Colors.orange.withOpacity(0.1) 
                      : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                  border: item.isUnlocked ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
                ),
                child: Icon(
                  item.iconData,
                  size: 32,
                  color: item.isUnlocked ? Colors.orange : (isDarkMode ? Colors.white24 : Colors.grey.shade400),
                ),
              ),

              // Kilit İkonu (Mini)
              if (!item.isUnlocked)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF21262D) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
                    ),
                    child: Icon(Icons.lock_outline, size: 14, color: isDarkMode ? Colors.white38 : Colors.grey), 
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // BAŞLIK
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: item.isUnlocked ? titleColor : titleColor.withOpacity(0.5),
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // AÇIKLAMA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: descColor, height: 1.3),
            ),
          ),
          
          const Spacer(),
          
          // DURUM ÇUBUĞU VEYA ROZET
          if (item.isUnlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade500]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)), // Kartın altına yapışık
              ),
              child: const Text(
                "KAZANILDI",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progressPercentage,
                      backgroundColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                      color: const Color(0xFF448AFF),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${item.currentValue} / ${item.targetValue}",
                    style: TextStyle(fontSize: 10, color: descColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}