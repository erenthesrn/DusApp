// lib/services/focus_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FocusService extends ChangeNotifier {
  // Singleton Yapısı
  static final FocusService _instance = FocusService._internal();
  static FocusService get instance => _instance;

  FocusService._internal() {
    _initNotifications();
  }

  // --- DEĞİŞKENLER ---
  Timer? _timer;
  int _totalTimeInSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isPaused = false;

  // Dışarıdan erişim için getter'lar
  int get totalTimeInSeconds => _totalTimeInSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // --- BİLDİRİM KURULUMU ---
  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // --- TIMER KONTROLLERİ ---

  void startTimer() {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    WakelockPlus.enable(); 
    notifyListeners(); 

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners(); 
      } else {
        _completeTimer();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = true;
    notifyListeners();
  }

  void resumeTimer() {
    startTimer();
  }

  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = _totalTimeInSeconds;
    WakelockPlus.disable();
    notifyListeners();
  }

  void setDuration(int minutes) {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _totalTimeInSeconds = minutes * 60;
    _remainingSeconds = minutes * 60;
    notifyListeners();
  }

  // --- GÜNCELLENEN KISIM ---
  void _completeTimer() async {
    _timer?.cancel();
    _remainingSeconds = 0;
    WakelockPlus.disable();
    
    // ÖNEMLİ: notifyListeners'ı isRunning hala true iken çağırıyoruz.
    // Bu sayede FocusScreen sürenin bittiğini ve diyaloğu göstermesi gerektiğini anlıyor.
    notifyListeners();

    // Diyalog tetiklendikten sonra durumu sıfırlıyoruz
    _isRunning = false;
    _isPaused = false;
    
    await _showNotification();
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'focus_channel', 'Odak Modu',
        channelDescription: 'Odak süresi bittiğinde bildirim gönderir',
        importance: Importance.max,
        priority: Priority.high);
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
        0, 'Süre Doldu! 🎉', 'Harikasın! Hedefine bir adım daha yaklaştın. 🦷✨', details);
  }
}