// lib/models/achievement_model.dart
import 'package:flutter/material.dart';
import '../services/achievement_service.dart'; // AchievementTier için

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData iconData;
  final int targetValue;

  /// Bronz / Gümüş / Altın — null ise tier'siz özel başarım
  final AchievementTier? tier;

  /// Aynı branşın kademe grubu (ör: 'anatomy', 'endo')
  final String? groupId;

  /// Bu başarım açılmadan önce kazanılması gereken başarım ID'si
  final String? requiredId;

  int currentValue;
  bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    required this.targetValue,
    this.tier,
    this.groupId,
    this.requiredId,
    this.currentValue = 0,
    this.isUnlocked = false,
  });

  double get progressPercentage =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'currentValue': currentValue,
        'isUnlocked': isUnlocked,
      };

  static Achievement fromMap(
      Map<String, dynamic> map, Achievement template) {
    return Achievement(
      id: template.id,
      title: template.title,
      description: template.description,
      iconData: template.iconData,
      targetValue: template.targetValue,
      tier: template.tier,
      groupId: template.groupId,
      requiredId: template.requiredId,
      currentValue: (map['currentValue'] as num?)?.toInt() ?? 0,
      isUnlocked: map['isUnlocked'] as bool? ?? false,
    );
  }
}
