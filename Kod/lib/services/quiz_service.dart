// lib/services/quiz_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class QuizService {
  // --- 1. SONUCU KAYDET ---
  // Örn: Anatomi, Test 1, Puan 85, Doğru 17, Yanlış 3
  static Future<void> saveQuizResult({
    required String topic, 
    required int testNo, 
    required int score,
    required int correctCount,
    required int wrongCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Her test için benzersiz bir anahtar (Key) oluşturuyoruz
    // Örn: "result_Anatomi_1"
    String key = "result_${topic}_$testNo";
    
    // Verileri tek bir String olarak birleştirip kaydediyoruz (Basit Yöntem)
    // Format: "Puan|Doğru|Yanlış" -> "85|17|3"
    String value = "$score|$correctCount|$wrongCount";
    
    await prefs.setString(key, value);
    print("💾 Kaydedildi: $key -> $value");
  }

  // --- 2. SONUCU OKU ---
  // Geriye bir Liste döner: [Puan, Doğru, Yanlış] veya null
  static Future<List<int>?> getQuizResult(String topic, int testNo) async {
    final prefs = await SharedPreferences.getInstance();
    String key = "result_${topic}_$testNo";
    
    String? value = prefs.getString(key);
    
    if (value != null) {
      // "85|17|3" stringini parçalayıp sayılara çeviriyoruz
      List<String> parts = value.split('|');
      return parts.map((e) => int.parse(e)).toList();
    }
    return null; // Daha önce çözülmemiş
  }
}