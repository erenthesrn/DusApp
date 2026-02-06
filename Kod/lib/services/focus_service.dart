// lib/services/focus_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:math'; // Random için eklendi
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // navigatorKey'e erişmek için şart

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

  // Motive edici sözleri globale taşıdık
  final List<String> _quotes = [
    "Başarı, her gün tekrarlanan küçük çabaların toplamıdır. 🦷",
    "Bugün yaptığın çalışma, yarınki uzmanlığının temelidir.",
    "DUS zor olabilir ama sen daha güçlüsün! 💪",
    "Bir ünite daha bitti, hedefe bir adım daha yaklaştın.",
    "Disiplin, hedeflerle başarı arasındaki köprüdür.",
  ];

  int get totalTimeInSeconds => _totalTimeInSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

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

  void resumeTimer() => startTimer();

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

  void _completeTimer() async {
    _timer?.cancel();
    _remainingSeconds = 0;
    _isRunning = false;
    _isPaused = false;
    WakelockPlus.disable();
    notifyListeners();
    
    // 1. Bildirim gönder
    await _showNotification();
    
    // 2. Global Pop-up aç (Hangi sayfada olursan ol)
    _showGlobalCompletionDialog();
  }

  // --- YENİ: GLOBAL POP-UP FONKSİYONU ---
  void _showGlobalCompletionDialog() {
    // NavigatorKey üzerinden o anki context'i yakalıyoruz
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final String randomQuote = _quotes[Random().nextInt(_quotes.length)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.stars_rounded, color: Colors.amber, size: 60),
            SizedBox(height: 10),
            Text("Harika İş Çıkardın!", textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Odaklanma seansını başarıyla tamamladın.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                randomQuote,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1565C0),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                resetTimer(); // Timer'ı eski süresine döndür
                Navigator.pop(context); // Pop-up'ı kapat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Devam Et", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'focus_channel_v3', 
        'Odak Modu Bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails, 
    );
    
    await _notificationsPlugin.show(
        0, 
        'Süre Doldu! 🎉', 
        'Harikasın! Hedefine bir adım daha yaklaştın. 🦷✨', 
        details);
  }
}