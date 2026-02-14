import 'package:flutter/material.dart';

class SnackBarHelper {
  static DateTime? _lastShownTime;
  static String? _lastMessage;
  
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    bool force = false,
  }) {
    // Aynı mesaj 2 saniye içinde tekrar gösterilmesin
    final now = DateTime.now();
    if (!force && 
        _lastMessage == message && 
        _lastShownTime != null && 
        now.difference(_lastShownTime!) < const Duration(seconds: 2)) {
      return;
    }

    _lastMessage = message;
    _lastShownTime = now;

    // Önceki SnackBar'ı kapat
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}