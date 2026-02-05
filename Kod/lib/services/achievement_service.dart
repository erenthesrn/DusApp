// lib/services/achievement_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement_model.dart';

class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  static AchievementService get instance => _instance;

  AchievementService._internal() {
    _loadProgress();
  }

  // 🔥 30 ROZETLİK HATASIZ VE DEV KADRO 🔥
  final List<Achievement> _achievements = [
    // --- 1. BAŞLANGIÇ & KLASİKLER ---
    Achievement(
      id: 'first_blood',
      title: 'İlk Kan',
      description: 'DUS yolculuğundaki ilk sorunu çözdün. Başarılar!',
      iconData: Icons.local_hospital_rounded,
      targetValue: 1,
    ),
    
    // --- 2. BRANŞ RÜTBELERİ ---
    Achievement(
      id: 'anatomy_wolf',
      title: 'Anatomi Kurdu',
      description: 'Fossa\'lar, Sinüs\'ler senden sorulur! (50 Doğru)',
      iconData: Icons.accessibility_new_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'bio_genius',
      title: 'Biyokimya Dehası',
      description: 'Moleküllerle dans ediyorsun. (50 Doğru)',
      iconData: Icons.science_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'perio_guard',
      title: 'Diş Eti Muhafızı',
      description: 'Sond sende, diş etleri güvende. (50 Doğru)',
      iconData: Icons.health_and_safety_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'pro_architect',
      title: 'Gülüş Mimarı',
      description: 'Kuronlar, köprüler... Tam bir sanatçısın. (50 Doğru)',
      iconData: Icons.architecture_rounded,
      targetValue: 50,
    ),
    // 🛠️ DÜZELTME: cut -> content_cut_rounded
    Achievement(
      id: 'surgery_master',
      title: 'Bistüri Dansçısı',
      description: 'Cerrahi sorularını tereyağından kıl çeker gibi çözdün. (50 Doğru)',
      iconData: Icons.content_cut_rounded, 
      targetValue: 50,
    ),
    Achievement(
      id: 'radio_eye',
      title: 'Görünmeyeni Gören',
      description: 'Radyoloji sorularında x-ray vizyonunu kullandın. (50 Doğru)',
      iconData: Icons.visibility_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'endo_king',
      title: 'Köklerin Efendisi',
      description: 'Kanal tedavisinde zirvedesin. (50 Doğru)',
      iconData: Icons.vpn_key_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'pedo_hero',
      title: 'Süt Dişi Koruyucusu',
      description: 'Pedodonti sorularının süper kahramanı! (50 Doğru)',
      iconData: Icons.child_friendly_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'orto_bender',
      title: 'Eğriyi Doğrultan',
      description: 'Braketler ve teller senin işin. (50 Doğru)',
      iconData: Icons.linear_scale_rounded,
      targetValue: 50,
    ),
    Achievement(
      id: 'resto_artist',
      title: 'Diş Terzisi',
      description: 'Restoratif tedavide estetik dokunuşlar. (50 Doğru)',
      iconData: Icons.brush_rounded,
      targetValue: 50,
    ),

    // --- 3. HACİM VE SAYI GÖNDERMELERİ ---
    Achievement(
      id: 'clinical_chief',
      title: 'Klinik Şefi',
      description: '100 Soru barajı aşıldı. Stajyerler selam duruyor!',
      iconData: Icons.medical_services_rounded,
      targetValue: 100,
    ),
    // 🚑 DÜZELTME: ambulance -> monitor_heart_rounded (Hatasız)
    Achievement(
      id: 'emergency_112',
      title: '112 Acil Servis',
      description: 'Tam 112 soru çözdün. Müdahale başarılı!',
      iconData: Icons.monitor_heart_rounded, 
      targetValue: 112,
    ),
    Achievement(
      id: 'sparta_300',
      title: '300 Spartalı',
      description: '300 Soru devirdin. Bu DUS bizim!',
      iconData: Icons.shield_rounded,
      targetValue: 300,
    ),
    Achievement(
      id: 'question_monster',
      title: 'Soru Canavarı',
      description: '500 Soru mu? Seni kimse tutamaz.',
      iconData: Icons.psychology_rounded,
      targetValue: 500,
    ),
    Achievement(
      id: 'dus_legend',
      title: 'DUS Efsanesi',
      description: '1000 Soru. Artık sen bir soru makinesisin.',
      iconData: Icons.workspace_premium_rounded,
      targetValue: 1000,
    ),
    Achievement(
      id: 'conquest_1453',
      title: 'Fetih 1453',
      description: '1453 soru çözerek DUS\'u fethettin!',
      iconData: Icons.flag_rounded,
      targetValue: 1453,
    ),
    Achievement(
      id: 'republic_1923',
      title: 'Cumhuriyet',
      description: '1923 soruya ulaştın. Nice başarılara!',
      iconData: Icons.celebration_rounded,
      targetValue: 1923,
    ),

    // --- 4. ZAMAN VE YAŞAM TARZI ---
    Achievement(
      id: 'night_owl',
      title: 'Gece Nöbeti',
      description: 'Herkes uyurken (00:00-05:00) sen çalışıyorsun.',
      iconData: Icons.nights_stay_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'early_bird',
      title: 'Erkenci Kuş',
      description: 'Güneş doğarken (05:00-08:00) zihin açık olur.',
      iconData: Icons.wb_sunny_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'lunch_break',
      title: 'Öğle Molası',
      description: 'Yemek yerine soru yiyorsun (12:00-13:30). Afiyet olsun!',
      iconData: Icons.restaurant_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'weekend_warrior',
      title: 'Hafta Sonu Kampı',
      description: 'Cumartesi veya Pazar günü de boş durmadın.',
      iconData: Icons.weekend_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'monday_hero',
      title: 'Sendromsuz Pazartesi',
      description: 'Pazartesi günü soru çözerek haftaya bomba gibi başladın.',
      iconData: Icons.calendar_today_rounded,
      targetValue: 1,
    ),

    // --- 5. PERFORMANS VE ŞANS ---
    Achievement(
      id: 'perfectionist',
      title: 'Hatasız Kul Olmaz',
      description: 'Ama sen hatasızdın! (%100 Başarı)',
      iconData: Icons.verified_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'lucky_seven',
      title: 'Şanslı Yedili',
      description: 'Bir testte tam 7 doğru yaptın. Şans seninle!',
      iconData: Icons.casino_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'passed_threshold',
      title: 'Barajı Geçtik',
      description: 'Testten 50 puan ve üzeri aldın. Yürrü be!',
      iconData: Icons.check_circle_outline_rounded,
      targetValue: 1,
    ),
  ];

  List<Achievement> get achievements => _achievements;

  // --- MANTIK KISMI ---

  Future<void> updateProgress(BuildContext context, String id, int amount) async {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final achievement = _achievements[index];
    if (achievement.isUnlocked) return;

    achievement.currentValue += amount;
    
    if (achievement.currentValue >= achievement.targetValue) {
      achievement.currentValue = achievement.targetValue;
      achievement.isUnlocked = true;
      _showUnlockNotification(context, achievement);
    }

    notifyListeners();
    _saveProgress();
  }

  // 🔥 GELİŞMİŞ KATEGORİ ALGILAMA
  Future<void> incrementCategory(BuildContext context, String categoryName, int correctCount) async {
    // 1. Genel sayaçları her zaman artır
    updateProgress(context, 'first_blood', 1);
    updateProgress(context, 'clinical_chief', correctCount);
    updateProgress(context, 'emergency_112', correctCount); 
    updateProgress(context, 'sparta_300', correctCount);    
    updateProgress(context, 'question_monster', correctCount);
    updateProgress(context, 'dus_legend', correctCount);
    updateProgress(context, 'conquest_1453', correctCount); 
    updateProgress(context, 'republic_1923', correctCount); 

    // 2. Kategoriye özel artışlar
    final lowerName = categoryName.toLowerCase();

    if (lowerName.contains('anatomi')) updateProgress(context, 'anatomy_wolf', correctCount);
    else if (lowerName.contains('biyokimya')) updateProgress(context, 'bio_genius', correctCount);
    else if (lowerName.contains('perio')) updateProgress(context, 'perio_guard', correctCount);
    else if (lowerName.contains('protetik') || lowerName.contains('protez')) updateProgress(context, 'pro_architect', correctCount);
    else if (lowerName.contains('cerrah')) updateProgress(context, 'surgery_master', correctCount);
    else if (lowerName.contains('radyo')) updateProgress(context, 'radio_eye', correctCount);
    else if (lowerName.contains('endo')) updateProgress(context, 'endo_king', correctCount);
    else if (lowerName.contains('pedo') || lowerName.contains('çocuk')) updateProgress(context, 'pedo_hero', correctCount);
    else if (lowerName.contains('orto')) updateProgress(context, 'orto_bender', correctCount);
    else if (lowerName.contains('resto') || lowerName.contains('tedavi')) updateProgress(context, 'resto_artist', correctCount);
  }

  // 🔥 GELİŞMİŞ ZAMAN VE SKOR KONTROLÜ
  void checkTimeAndScore(BuildContext context, int totalScore, int maxScore, int correctCount) {
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday; // 1=Pazartesi, 7=Pazar

    // --- SKOR ROZETLERİ ---
    if (totalScore == maxScore && maxScore > 0) {
      updateProgress(context, 'perfectionist', 1);
    }
    if (correctCount == 7) {
      updateProgress(context, 'lucky_seven', 1); // Tam 7 doğru
    }
    if (totalScore >= 50) {
      updateProgress(context, 'passed_threshold', 1);
    }

    // --- ZAMAN ROZETLERİ ---
    if (hour >= 0 && hour < 5) updateProgress(context, 'night_owl', 1);
    if (hour >= 5 && hour < 8) updateProgress(context, 'early_bird', 1);
    if (hour >= 12 && hour < 14) updateProgress(context, 'lunch_break', 1); // Öğle arası

    // Hafta sonu (Cumartesi=6, Pazar=7)
    if (weekday == 6 || weekday == 7) {
      updateProgress(context, 'weekend_warrior', 1);
    }
    // Pazartesi (1)
    if (weekday == 1) {
      updateProgress(context, 'monday_hero', 1);
    }
  }

  // --- KAYIT VE YÜKLEME ---
  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _achievements.map((a) => a.toMap()).toList();
    await prefs.setString('achievements_v4', jsonEncode(data));
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString('achievements_v4');

    if (dataString != null) {
      final List<dynamic> jsonList = jsonDecode(dataString);
      for (var jsonItem in jsonList) {
        final index = _achievements.indexWhere((a) => a.id == jsonItem['id']);
        if (index != -1) {
          _achievements[index] = Achievement.fromMap(jsonItem, _achievements[index]);
        }
      }
      notifyListeners();
    }
  }

  // --- BİLDİRİM (SNACKBAR) ---
  void _showUnlockNotification(BuildContext context, Achievement achievement) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)], // Premium Mavi Geçiş
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              // İkon Kutusu
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(achievement.iconData, color: Colors.amberAccent, size: 28),
              ),
              const SizedBox(width: 16),
              // Yazı Alanı
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BAŞARIM AÇILDI! 🎉',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      achievement.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
}