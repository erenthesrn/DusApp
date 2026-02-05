import 'package:flutter/material.dart';

class Achievement {
  final String id;          // Rozetin benzersiz kimliği (örn: 'anatomi_1')
  final String title;       // Başlık (örn: 'Anatomi Atlası')
  final String description; // Açıklama
  final IconData iconData;  // Gösterilecek ikon
  final int targetValue;    // Hedef (örn: 50 soru)
  int currentValue;         // Mevcut durum (örn: 12 soru)
  bool isUnlocked;          // Kazanıldı mı?

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
  });

  // İlerleme kaydetme (0.0 ile 1.0 arası bir değer döner, progress bar için)
  double get progressPercentage {
    if (isUnlocked) return 1.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  // Veriyi telefona kaydetmek için JSON'a çevirme
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currentValue': currentValue,
      'isUnlocked': isUnlocked,
    };
  }

  // Telefondan veriyi geri okuma
  factory Achievement.fromMap(Map<String, dynamic> map, Achievement original) {
    return Achievement(
      id: original.id,
      title: original.title,
      description: original.description,
      iconData: original.iconData,
      targetValue: original.targetValue,
      currentValue: map['currentValue'] ?? 0,
      isUnlocked: map['isUnlocked'] ?? false,
    );
  }
}