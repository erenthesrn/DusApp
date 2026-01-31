import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QuizService {
  
  // --- SONUÇ KAYDETME (GÜNCELLENDİ: userAnswers eklendi) ---
  static Future<void> saveQuizResult({
    required String topic,
    required int testNo,
    required int score,
    required int correctCount,
    required int wrongCount,
    required List<int?> userAnswers, // 🔥 YENİ: Cevap anahtarını da alıyoruz
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String key = "result_${topic}_$testNo";

    Map<String, dynamic> resultData = {
      'score': score,
      'correct': correctCount,
      'wrong': wrongCount,
      'user_answers': userAnswers, // 🔥 YENİ: Listeyi kaydediyoruz
      'date': DateTime.now().toIso8601String(),
    };

    await prefs.setString(key, json.encode(resultData));
  }

  // --- SONUÇ OKUMA ---
  static Future<Map<String, dynamic>?> getQuizResult(String topic, int testNo) async {
    final prefs = await SharedPreferences.getInstance();
    String key = "result_${topic}_$testNo";
    String? jsonString = prefs.getString(key);

    if (jsonString != null) {
      try {
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}