// lib/services/achievement_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/achievement_model.dart';
import 'notification_queue.dart';

/// Başarım kademeleri
enum AchievementTier { bronze, silver, gold }

extension AchievementTierExt on AchievementTier {
  String get label {
    switch (this) {
      case AchievementTier.bronze: return 'Bronz';
      case AchievementTier.silver: return 'Gümüş';
      case AchievementTier.gold:   return 'Altın';
    }
  }

  Color get color {
    switch (this) {
      case AchievementTier.bronze: return const Color(0xFFCD7F32);
      case AchievementTier.silver: return const Color(0xFFB0C4DE);
      case AchievementTier.gold:   return const Color(0xFFFFD700);
    }
  }

  Color get glowColor {
    switch (this) {
      case AchievementTier.bronze: return const Color(0xFFCD7F32);
      case AchievementTier.silver: return const Color(0xFF90AAD4);
      case AchievementTier.gold:   return const Color(0xFFFFD700);
    }
  }

  List<Color> get gradient {
    switch (this) {
      case AchievementTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)];
      case AchievementTier.silver:
        return [const Color(0xFFB0C4DE), const Color(0xFF708090)];
      case AchievementTier.gold:
        return [const Color(0xFFFFD700), const Color(0xFFFFA000)];
    }
  }

  IconData get tierIcon {
    switch (this) {
      case AchievementTier.bronze: return Icons.looks_3_rounded;
      case AchievementTier.silver: return Icons.looks_two_rounded;
      case AchievementTier.gold:   return Icons.looks_one_rounded;
    }
  }
}

class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  static AchievementService get instance => _instance;

  String? _loadedUserId;

  AchievementService._internal() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        if (_loadedUserId != user.uid) {
          _resetAchievements();
          _loadedUserId = user.uid;
          _loadProgress();
        }
      } else {
        _loadedUserId = null;
        _resetAchievements();
        _clearLocalCache();
      }
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _loadedUserId = currentUser.uid;
      _loadProgress();
    }
  }

  // ─────────────────────────────────────────
  //  BAŞARIM LİSTESİ
  // ─────────────────────────────────────────

  final List<Achievement> _achievements = [

    // ══════════════════════════════════════
    // 🩸 BAŞLANGIÇ
    // ══════════════════════════════════════
    Achievement(
      id: 'first_blood',
      title: 'İlk Adım',
      description: 'DUS yolculuğundaki ilk soruyu çözdün!',
      iconData: Icons.local_hospital_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'no_turning_back',
      title: 'Dönüş Yok',
      description: '10 soru tamamlandı. Artık DUS seni seçti.',
      iconData: Icons.rocket_launch_rounded,
      targetValue: 10,
    ),

    // ══════════════════════════════════════
    // 🦷 ANATOMİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'anatomy_bronze',
      title: 'Anatomi Çırağı',
      description: 'Fossalar ve sinüslere ilk adım. (50 Doğru)',
      iconData: Icons.accessibility_new_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'anatomy',
    ),
    Achievement(
      id: 'anatomy_silver',
      title: 'Anatomi Kalfa',
      description: 'Sinirler ve damarlar artık tanıdık. (250 Doğru)',
      iconData: Icons.accessibility_new_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'anatomy',
      requiredId: 'anatomy_bronze',
    ),
    Achievement(
      id: 'anatomy_gold',
      title: 'Fossaların Fatihi',
      description: 'Anatomi kitabını yazan sensin artık. (500 Doğru)',
      iconData: Icons.accessibility_new_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'anatomy',
      requiredId: 'anatomy_silver',
    ),

    // ══════════════════════════════════════
    // 🧪 BİYOKİMYA — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'bio_bronze',
      title: 'Biyokimya Çırağı',
      description: 'Enzimler ve metabolizma yoluna girdin. (50 Doğru)',
      iconData: Icons.science_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'bio',
    ),
    Achievement(
      id: 'bio_silver',
      title: 'Biyokimya Kalfa',
      description: 'Krebs döngüsü artık cebinde. (250 Doğru)',
      iconData: Icons.science_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'bio',
      requiredId: 'bio_bronze',
    ),
    Achievement(
      id: 'bio_gold',
      title: 'Moleküller Çarı',
      description: 'Enzimler senin emrinde, hücre sana bağlı. (500 Doğru)',
      iconData: Icons.science_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'bio',
      requiredId: 'bio_silver',
    ),

    // ══════════════════════════════════════
    // 🦠 PERİODONTOLOJİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'perio_bronze',
      title: 'Diş Eti Çırağı',
      description: 'Sondlamaya başladın. (50 Doğru)',
      iconData: Icons.health_and_safety_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'perio',
    ),
    Achievement(
      id: 'perio_silver',
      title: 'Diş Eti Kalfası',
      description: 'Cep derinliği senden kaçmaz. (250 Doğru)',
      iconData: Icons.health_and_safety_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'perio',
      requiredId: 'perio_bronze',
    ),
    Achievement(
      id: 'perio_gold',
      title: 'Diş Eti Dedektifi',
      description: 'Ataçman kaybını gözlerinle görebiliyorsun. (500 Doğru)',
      iconData: Icons.health_and_safety_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'perio',
      requiredId: 'perio_silver',
    ),

    // ══════════════════════════════════════
    // 👑 PROTETİK — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'pro_bronze',
      title: 'Protetik Çırak',
      description: 'Kuron ve köprüye ilk adım. (50 Doğru)',
      iconData: Icons.architecture_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'pro',
    ),
    Achievement(
      id: 'pro_silver',
      title: 'Protetik Kalfa',
      description: 'Total protez artık el işi gibi. (250 Doğru)',
      iconData: Icons.architecture_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'pro',
      requiredId: 'pro_bronze',
    ),
    Achievement(
      id: 'pro_gold',
      title: 'Porselen Sanatçısı',
      description: 'İmplant üstü protezde ustalaştın. (500 Doğru)',
      iconData: Icons.architecture_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'pro',
      requiredId: 'pro_silver',
    ),

    // ══════════════════════════════════════
    // 🔪 CERRAHİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'surgery_bronze',
      title: 'Bistüri Çırağı',
      description: 'İlk insizyon yapıldı. (50 Doğru)',
      iconData: Icons.content_cut_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'surgery',
    ),
    Achievement(
      id: 'surgery_silver',
      title: 'Bistüri Kalfası',
      description: 'Flep kaldırmak artık sanat. (250 Doğru)',
      iconData: Icons.content_cut_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'surgery',
      requiredId: 'surgery_bronze',
    ),
    Achievement(
      id: 'surgery_gold',
      title: 'Bistüri Dansçısı',
      description: 'Ameliyathane senin sahnen. (500 Doğru)',
      iconData: Icons.content_cut_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'surgery',
      requiredId: 'surgery_silver',
    ),

    // ══════════════════════════════════════
    // 📡 RADYOLOJİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'radio_bronze',
      title: 'Radyoloji Çırağı',
      description: 'Filmlere bakmaya başladın. (50 Doğru)',
      iconData: Icons.visibility_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'radio',
    ),
    Achievement(
      id: 'radio_silver',
      title: 'Radyoloji Kalfası',
      description: 'Lezyonları tanımak artık kolay. (250 Doğru)',
      iconData: Icons.visibility_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'radio',
      requiredId: 'radio_bronze',
    ),
    Achievement(
      id: 'radio_gold',
      title: 'X-Ray Gözlü',
      description: 'Radyografi okurken film bile fazla. (500 Doğru)',
      iconData: Icons.visibility_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'radio',
      requiredId: 'radio_silver',
    ),

    // ══════════════════════════════════════
    // 🔑 ENDODONTİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'endo_bronze',
      title: 'Kanal Çırağı',
      description: 'Apeksi bulmaya başladın. (50 Doğru)',
      iconData: Icons.vpn_key_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'endo',
    ),
    Achievement(
      id: 'endo_silver',
      title: 'Kanal Kalfası',
      description: 'Eğe tipleri ve irrigasyon sende. (250 Doğru)',
      iconData: Icons.vpn_key_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'endo',
      requiredId: 'endo_bronze',
    ),
    Achievement(
      id: 'endo_gold',
      title: 'Apeks Avcısı',
      description: 'Kanal tedavisinde zirvedesin. (500 Doğru)',
      iconData: Icons.vpn_key_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'endo',
      requiredId: 'endo_silver',
    ),

    // ══════════════════════════════════════
    // 👶 PEDODONTİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'pedo_bronze',
      title: 'Süt Dişi Çırağı',
      description: 'Minik hastalar seni tanımaya başladı. (50 Doğru)',
      iconData: Icons.child_friendly_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'pedo',
    ),
    Achievement(
      id: 'pedo_silver',
      title: 'Süt Dişi Kalfası',
      description: 'Çocuk davranış yönetimi senin işin. (250 Doğru)',
      iconData: Icons.child_friendly_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'pedo',
      requiredId: 'pedo_bronze',
    ),
    Achievement(
      id: 'pedo_gold',
      title: 'Süt Dişi Süperherosu',
      description: 'Minik hastaların en büyük destekçisi! (500 Doğru)',
      iconData: Icons.child_friendly_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'pedo',
      requiredId: 'pedo_silver',
    ),

    // ══════════════════════════════════════
    // 📐 ORTODONTİ — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'orto_bronze',
      title: 'Braket Çırağı',
      description: 'Tel büküm işine girdin. (50 Doğru)',
      iconData: Icons.linear_scale_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'orto',
    ),
    Achievement(
      id: 'orto_silver',
      title: 'Braket Kalfası',
      description: 'Oklüzyon analizi artık net. (250 Doğru)',
      iconData: Icons.linear_scale_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'orto',
      requiredId: 'orto_bronze',
    ),
    Achievement(
      id: 'orto_gold',
      title: 'Tel Büken',
      description: 'Braket, ark teli, retainer — her şey yerli yerinde. (500 Doğru)',
      iconData: Icons.linear_scale_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'orto',
      requiredId: 'orto_silver',
    ),

    // ══════════════════════════════════════
    // 🎨 RESTORATİF — 3 KADEME
    // ══════════════════════════════════════
    Achievement(
      id: 'resto_bronze',
      title: 'Restoratif Çırak',
      description: 'Kompozite ilk dokunuş. (50 Doğru)',
      iconData: Icons.brush_rounded,
      targetValue: 50,
      tier: AchievementTier.bronze,
      groupId: 'resto',
    ),
    Achievement(
      id: 'resto_silver',
      title: 'Restoratif Kalfa',
      description: 'Renk seçimi gözünde canlanıyor. (250 Doğru)',
      iconData: Icons.brush_rounded,
      targetValue: 250,
      tier: AchievementTier.silver,
      groupId: 'resto',
      requiredId: 'resto_bronze',
    ),
    Achievement(
      id: 'resto_gold',
      title: 'Kompozit Virtüözü',
      description: 'Restorasyon yaparken estetik mükemmel. (500 Doğru)',
      iconData: Icons.brush_rounded,
      targetValue: 500,
      tier: AchievementTier.gold,
      groupId: 'resto',
      requiredId: 'resto_silver',
    ),

    // ══════════════════════════════════════
    // 📊 HACİM MİLTASLARI
    // ══════════════════════════════════════
    Achievement(
      id: 'milestone_100',
      title: 'Servis Şefi',
      description: '100 soru barajı aşıldı. Asistanlar selam duruyor!',
      iconData: Icons.medical_services_rounded,
      targetValue: 100,
    ),
    Achievement(
      id: 'milestone_112',
      title: '112 Müdahale',
      description: 'Tam 112 soru — acil servisteki hızın var.',
      iconData: Icons.monitor_heart_rounded,
      targetValue: 112,
    ),
    Achievement(
      id: 'milestone_300',
      title: '300 Spartalı',
      description: '300 soru devirdin. Bu DUS bizim!',
      iconData: Icons.shield_rounded,
      targetValue: 300,
    ),
    Achievement(
      id: 'milestone_500',
      title: 'Soru Canavarı',
      description: '500 soru mu? Dur deme, devam et!',
      iconData: Icons.psychology_rounded,
      targetValue: 500,
    ),
    Achievement(
      id: 'milestone_1000',
      title: 'DUS Efsanesi',
      description: '1000 soru. Artık sen bir referans kaynaksın.',
      iconData: Icons.workspace_premium_rounded,
      targetValue: 1000,
    ),
    Achievement(
      id: 'milestone_1453',
      title: 'İstanbul\'u Fethettim',
      description: '1453 soru çözerek DUS\'u fethettim!',
      iconData: Icons.flag_rounded,
      targetValue: 1453,
    ),
    Achievement(
      id: 'milestone_1923',
      title: 'Cumhuriyet Ruhu',
      description: '1923 soruya ulaştın. Türk hekimliğine yakışır!',
      iconData: Icons.celebration_rounded,
      targetValue: 1923,
    ),
    Achievement(
      id: 'milestone_2000',
      title: 'İki Binin Ötesi',
      description: '2000+ soru. Artık sen DUS\'sun.',
      iconData: Icons.auto_awesome_rounded,
      targetValue: 2000,
    ),

    // ══════════════════════════════════════
    // ⏰ ZAMAN & YAŞAM TARZI
    // ══════════════════════════════════════
    Achievement(
      id: 'night_owl',
      title: 'Gece Nöbetçisi',
      description: 'Saat 00:00-05:00 arası çalışıyorsun. Uyku lüks!',
      iconData: Icons.nights_stay_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'early_bird',
      title: 'Güneş Doğmadan Uyanık',
      description: 'Sabah 05:00-08:00 arası zihin en açık zaman.',
      iconData: Icons.wb_sunny_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'lunch_break',
      title: 'Tabak Değil Tablet',
      description: 'Öğle 12:00-13:30: Yemek yerine soru yedin. Afiyet!',
      iconData: Icons.restaurant_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'weekend_warrior',
      title: 'Hafta Sonu Kurtarıcı',
      description: 'Cumartesi veya Pazar günü de bırakmadın.',
      iconData: Icons.weekend_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'monday_hero',
      title: 'Pazartesi Sendromsuz',
      description: 'Pazartesi çalıştın. Haftayı bomba gibi açtın.',
      iconData: Icons.calendar_today_rounded,
      targetValue: 1,
    ),

    // ══════════════════════════════════════
    // 🎯 PERFORMANS & ŞANS
    // ══════════════════════════════════════
    Achievement(
      id: 'perfectionist',
      title: '%100 Hatasız',
      description: 'Bir testte hiç yanlış yapmadın. Kusursuzluk mümkün!',
      iconData: Icons.verified_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'lucky_seven',
      title: 'Yedili Jackpot',
      description: 'Tam 7 doğru yaptın. Şans seninle!',
      iconData: Icons.casino_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'passed_threshold',
      title: 'Barajı Geçtik!',
      description: 'Testten 50 puan ve üzeri aldın. İyi iş!',
      iconData: Icons.check_circle_outline_rounded,
      targetValue: 1,
    ),
    Achievement(
      id: 'speed_demon',
      title: 'Işık Hızlı',
      description: '10 soruyu 3 dakika altında bitirdin.',
      iconData: Icons.bolt_rounded,
      targetValue: 1,
    ),

    // ══════════════════════════════════════
    // 🔥 SERİ
    // ══════════════════════════════════════
    Achievement(
      id: 'streak_3',
      title: '3 Günlük Israr',
      description: '3 gün üst üste çalıştın. Alışkanlık oluşuyor!',
      iconData: Icons.local_fire_department_rounded,
      targetValue: 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Tam Bir Hafta',
      description: '7 gün hiç ara vermeden. Artık rutin bu!',
      iconData: Icons.whatshot_rounded,
      targetValue: 7,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Aylık Disiplin Ödülü',
      description: '30 gün kesintisiz. Seni hiçbir şey durduramaz.',
      iconData: Icons.emoji_events_rounded,
      targetValue: 30,
    ),

    // ══════════════════════════════════════
    // 🌟 GİZLİ & ÖZEL
    // ══════════════════════════════════════
    Achievement(
      id: 'all_branches',
      title: 'Tam Kapsamlı',
      description: 'Tüm branşlardan en az 1 soru çözdün.',
      iconData: Icons.hub_rounded,
      targetValue: 10,
    ),
    Achievement(
      id: 'bookworm',
      title: 'Ansiklopedik Hafıza',
      description: '5 farklı kategoride 10\'ar doğru yaptın.',
      iconData: Icons.menu_book_rounded,
      targetValue: 50,
    ),
  ];

  List<Achievement> get achievements => _achievements;

  // ─────────────────────────────────────────
  //  KILIT KONTROLÜ — önceki kademe kazanılmadan sonraki kilitli
  // ─────────────────────────────────────────

  bool isLocked(Achievement achievement) {
    if (achievement.requiredId == null) return false;
    final required = _achievements.firstWhere(
      (a) => a.id == achievement.requiredId,
      orElse: () => achievement,
    );
    return !required.isUnlocked;
  }

  // ─────────────────────────────────────────
  //  MANTIK
  // ─────────────────────────────────────────

  Future<void> updateProgress(BuildContext context, String id, int amount) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != _loadedUserId) return;

    final index = _achievements.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final achievement = _achievements[index];
    if (achievement.isUnlocked) return;
    if (isLocked(achievement)) return; // önceki kademe bitmeden ilerleme yok

    int newValue = achievement.currentValue + amount;
    if (newValue > achievement.targetValue) newValue = achievement.targetValue;
    achievement.currentValue = newValue;

    if (achievement.currentValue >= achievement.targetValue && !achievement.isUnlocked) {
      achievement.isUnlocked = true;
      _showUnlockNotification(context, achievement);
    }

    notifyListeners();
    _saveProgress(achievement);
  }

  Future<void> incrementCategory(
      BuildContext context, String categoryName, int correctCount) async {
    updateProgress(context, 'first_blood', 1);
    updateProgress(context, 'no_turning_back', correctCount);

    // Milestones
    for (final id in ['milestone_100','milestone_112','milestone_300',
        'milestone_500','milestone_1000','milestone_1453','milestone_1923','milestone_2000']) {
      updateProgress(context, id, correctCount);
    }

    final lowerName = categoryName.toLowerCase();
    if (lowerName.contains('anatomi')) {
      for (final id in ['anatomy_bronze','anatomy_silver','anatomy_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('biyokimya')) {
      for (final id in ['bio_bronze','bio_silver','bio_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('perio')) {
      for (final id in ['perio_bronze','perio_silver','perio_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('protetik') || lowerName.contains('protez')) {
      for (final id in ['pro_bronze','pro_silver','pro_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('cerrah')) {
      for (final id in ['surgery_bronze','surgery_silver','surgery_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('radyo')) {
      for (final id in ['radio_bronze','radio_silver','radio_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('endo')) {
      for (final id in ['endo_bronze','endo_silver','endo_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('pedo') || lowerName.contains('çocuk')) {
      for (final id in ['pedo_bronze','pedo_silver','pedo_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('orto')) {
      for (final id in ['orto_bronze','orto_silver','orto_gold'])
        updateProgress(context, id, correctCount);
    } else if (lowerName.contains('resto') || lowerName.contains('tedavi')) {
      for (final id in ['resto_bronze','resto_silver','resto_gold'])
        updateProgress(context, id, correctCount);
    }

    updateProgress(context, 'all_branches', 1);
    updateProgress(context, 'bookworm', correctCount);
  }

  void checkTimeAndScore(
      BuildContext context, int totalScore, int maxScore, int correctCount) {
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday;

    if (totalScore == maxScore && maxScore > 0)
      updateProgress(context, 'perfectionist', 1);
    if (correctCount == 7) updateProgress(context, 'lucky_seven', 1);
    if (totalScore >= 50) updateProgress(context, 'passed_threshold', 1);

    if (hour >= 0 && hour < 5) updateProgress(context, 'night_owl', 1);
    if (hour >= 5 && hour < 8) updateProgress(context, 'early_bird', 1);
    if (hour >= 12 && hour < 14) updateProgress(context, 'lunch_break', 1);
    if (weekday == 6 || weekday == 7) updateProgress(context, 'weekend_warrior', 1);
    if (weekday == 1) updateProgress(context, 'monday_hero', 1);
  }

  // ─────────────────────────────────────────
  //  FIREBASE REFRESH
  // ─────────────────────────────────────────

  Future<void> refreshFromFirebase() async {
    final uid = _loadedUserId;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .get();

      if (snapshot.docs.isEmpty) return;
      if (_loadedUserId != uid) return;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final index = _achievements.indexWhere((a) => a.id == doc.id);
        if (index == -1) continue;

        int serverValue = (data['currentValue'] as num?)?.toInt() ?? 0;
        bool serverUnlocked = data['isUnlocked'] as bool? ?? false;

        if (serverValue >= _achievements[index].targetValue) serverUnlocked = true;

        _achievements[index].currentValue = serverValue;
        _achievements[index].isUnlocked = serverUnlocked;
      }

      notifyListeners();
      _saveLocalOnly(uid);
    } catch (e) {
      debugPrint("Achievement refresh error: $e");
    }
  }

  // ─────────────────────────────────────────
  //  KAYIT / YÜKLEME
  // ─────────────────────────────────────────

  void _resetAchievements() {
    for (var a in _achievements) {
      a.currentValue = 0;
      a.isUnlocked = false;
    }
    notifyListeners();
  }

  Future<void> _clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('achievements_v4');
    if (_loadedUserId != null) {
      await prefs.remove('achievements_v4_$_loadedUserId');
    }
  }

  String _localCacheKey(String uid) => 'achievements_v5_$uid';

  Future<void> _loadProgress() async {
    final uid = _loadedUserId;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString(_localCacheKey(uid));

    if (localData != null) {
      _applyJsonList(jsonDecode(localData));
      notifyListeners();
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .get();

      if (snapshot.docs.isNotEmpty) {
        if (_loadedUserId != uid) return;

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final index = _achievements.indexWhere((a) => a.id == doc.id);
          if (index == -1) continue;

          int serverValue = (data['currentValue'] as num?)?.toInt() ?? 0;
          bool serverUnlocked = data['isUnlocked'] as bool? ?? false;

          if (serverValue >= _achievements[index].targetValue) serverUnlocked = true;

          if (serverUnlocked || serverValue > _achievements[index].currentValue) {
            _achievements[index].currentValue = serverValue;
            _achievements[index].isUnlocked = serverUnlocked;
          }
        }

        notifyListeners();
        _saveLocalOnly(uid);
      }
    } catch (e) {
      debugPrint("Achievement Firebase Load Error: $e");
    }
  }

  void _applyJsonList(List<dynamic> jsonList) {
    for (var jsonItem in jsonList) {
      final index = _achievements.indexWhere((a) => a.id == jsonItem['id']);
      if (index != -1) {
        _achievements[index] = Achievement.fromMap(jsonItem, _achievements[index]);
      }
    }
  }

  Future<void> _saveProgress(Achievement achievement) async {
    final uid = _loadedUserId;
    if (uid == null) return;

    await _saveLocalOnly(uid);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .doc(achievement.id)
          .set({
        'currentValue': achievement.currentValue,
        'isUnlocked': achievement.isUnlocked,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Achievement Firebase Save Error: $e");
    }
  }

  Future<void> _saveLocalOnly(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _achievements.map((a) => a.toMap()).toList();
    await prefs.setString(_localCacheKey(uid), jsonEncode(data));
  }

  // ─────────────────────────────────────────
  //  BİLDİRİM
  // ─────────────────────────────────────────

  void _showUnlockNotification(BuildContext context, Achievement achievement) {
    final tier = achievement.tier;
    final gradientColors = tier != null
        ? tier.gradient
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];
    final glowColor = tier?.glowColor ?? Colors.blue;
    final badgeLabel = tier != null ? '${tier.label.toUpperCase()} ROZET' : 'BAŞARIM';

    NotificationQueue.instance.enqueueAchievement(() async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(achievement.iconData,
                      color: tier?.color ?? Colors.amberAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$badgeLabel AÇILDI! 🎉',
                        style: TextStyle(
                          color: tier?.color ?? Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(achievement.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(achievement.description,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 4));
    });
  }
}
