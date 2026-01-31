import 'dart:convert'; // 🔥 JSON işlemleri için
import 'package:shared_preferences/shared_preferences.dart';

class QuizService {
  
  // --- SONUÇ KAYDETME ---
  static Future<void> saveQuizResult({
    required String topic,
    required int testNo,
    required int score,
    required int correctCount,
    required int wrongCount
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Her testin kendine özel bir kimliği (key) olsun
    // Örn: "result_Anatomi_1"
    String key = "result_${topic}_$testNo";

    // Kaydedilecek veriyi hazırlayalım (Map formatında)
    Map<String, dynamic> resultData = {
      'score': score,
      'correct': correctCount,
      'wrong': wrongCount,
      'date': DateTime.now().toIso8601String(), // İstersen tarihi de tutabilirsin
    };

    // Map'i String'e (JSON) çevirip telefona kaydediyoruz
    String jsonString = json.encode(resultData);
    await prefs.setString(key, jsonString);
  }

  // --- SONUÇ OKUMA ---
  // Artık geriye Map döndürüyor (Eskiden List döndürüyordu, hata buradaydı)
  static Future<Map<String, dynamic>?> getQuizResult(String topic, int testNo) async {
    final prefs = await SharedPreferences.getInstance();
    String key = "result_${topic}_$testNo";

    // Veriyi String olarak çek
    String? jsonString = prefs.getString(key);

    if (jsonString != null) {
      try {
        // String'i tekrar Map'e çevir
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        // Eğer eski bir veri varsa ve formatı bozuksa null dön
        return null;
      }
    }
    return null;
  }
}