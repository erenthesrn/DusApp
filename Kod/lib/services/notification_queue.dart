// lib/services/notification_queue.dart — v2
//
// DEĞİŞİKLİK: enqueueStreak artık isNewDay parametresi alıyor.

import 'package:flutter/material.dart';
import '../widgets/streak_banner.dart';

typedef _NotificationTask = Future<void> Function();

class NotificationQueue {
  NotificationQueue._();
  static final NotificationQueue instance = NotificationQueue._();

  bool _isRunning = false;
  final List<_NotificationTask> _queue = [];

  /// [isNewDay] → Sadece true ise banner ekrana gelir.
  ///              False ise task kuyruğa eklenmez bile.
  void enqueueStreak({
    required BuildContext context,
    required int streakDays,
    required bool isNewDay,       // 🆕
    required bool isDarkMode,
  }) {
    if (!isNewDay || streakDays <= 0) return; // Filtre — kuyruğa bile girme

    _queue.insert(
      0,
      () => StreakBanner.show(
        context: context,
        streakDays: streakDays,
        isNewDay: isNewDay,
        isDarkMode: isDarkMode,
      ),
    );
    _run();
  }

  void enqueueAchievement(_NotificationTask task) {
    _queue.add(task);
    _run();
  }

  Future<void> _run() async {
    if (_isRunning) return;
    _isRunning = true;

    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      try {
        await task();
      } catch (e) {
        debugPrint('NotificationQueue task error (non-fatal): $e');
      }
    }

    _isRunning = false;
  }

  void clear() {
    _queue.clear();
    _isRunning = false;
  }
}
