import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../models/achievement_model.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Servisten canlı veriyi alıyoruz
    final achievements = AchievementService.instance.achievements;
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF), // Hafif mavi-beyaz arka plan
      appBar: AppBar(
        title: const Text("Kupa Dolabı 🏆"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // --- ÜST BİLGİ KARTI ---
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Mavi geçiş
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Toplam Başarı",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "$unlockedCount / ${achievements.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),

          // --- ROZET IZGARASI (GRID) ---
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Yan yana 2 kutu
                childAspectRatio: 0.85, // Kutuların boy oranı
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                return _buildAchievementCard(achievements[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: item.isUnlocked 
            ? Border.all(color: Colors.orange.shade300, width: 2) // Kazanıldıysa turuncu çerçeve
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İKON ALANI
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isUnlocked ? Colors.orange.shade50 : Colors.grey.shade100,
                ),
              ),
              Icon(
                item.iconData,
                size: 32,
                color: item.isUnlocked ? Colors.orange : Colors.grey,
              ),
              if (!item.isUnlocked)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.lock, size: 16, color: Colors.grey), // Kilit ikonu
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // BAŞLIK
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: item.isUnlocked ? Colors.black87 : Colors.grey,
            ),
          ),
          
          const SizedBox(height: 6),
          
          // AÇIKLAMA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // İLERLEME ÇUBUĞU (Henüz kazanılmadıysa göster)
          if (!item.isUnlocked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: item.progressPercentage,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.blueAccent,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item.currentValue} / ${item.targetValue}",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            
          // KAZANILDI ETİKETİ
          if (item.isUnlocked)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "KAZANILDI",
                style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}