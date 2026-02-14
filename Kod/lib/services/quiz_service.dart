import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizService {

  // 🔥 DÜZELTME: user_answers eksikliği giderildi
  static Future<Map<String, dynamic>?> getQuizResult(String topic, int testNo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Firebase'den sorgula (En son çözülen)
      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('results')
          .where('topic', isEqualTo: topic)
          .where('testNo', isEqualTo: testNo)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      
      // Yerel hafızaya bak
      final prefs = await SharedPreferences.getInstance();
      List<String> localResults = prefs.getStringList('quiz_results') ?? [];
      
      for (String res in localResults.reversed) {
        List<String> parts = res.split('|');
        if (parts.length >= 5 && parts[0] == topic && int.parse(parts[1]) == testNo) {
          return {
            'topic': parts[0],
            'testNo': int.parse(parts[1]),
            'score': int.parse(parts[2]),
            'correct': int.parse(parts[3]),
            'wrong': int.parse(parts[4]),
            'date': parts[5]
          };
        }
      }

    } catch (e) {
      print("Sonuç getirme hatası: $e");
    }
    return null;
  }
  
  static Future<List<int>> getCompletedTests(String topic) async {
    Set<int> completedTests = {};

    try {
      // Yerel veri
      final prefs = await SharedPreferences.getInstance();
      List<String> localResults = prefs.getStringList('quiz_results') ?? [];
      
      for (String res in localResults) {
        List<String> parts = res.split('|');
        if (parts.isNotEmpty && parts[0] == topic) {
          completedTests.add(int.parse(parts[1]));
        }
      }
    } catch (e) {
      print("Local okuma hatası: $e");
    }

    // Firebase'den çek
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('results')
            .where('topic', isEqualTo: topic)
            .get();

        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('testNo')) {
            completedTests.add(data['testNo'] as int);
          }
        }
      } catch (e) {
        print("Firebase okuma hatası: $e");
      }
    }

    return completedTests.toList();
  }

  // 🔥 DÜZELTME: userAnswers artık mutlaka kaydediliyor
  static Future<void> saveQuizResult({
    required String topic,
    required int testNo,
    required int score,
    required int correctCount,
    required int wrongCount,
    required int emptyCount,
    List<int?>? userAnswers,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;

    // 1. Yerel kayıt
    final prefs = await SharedPreferences.getInstance();
    List<String> results = prefs.getStringList('quiz_results') ?? [];
    String resultJson = "$topic|$testNo|$score|$correctCount|$wrongCount|${DateTime.now()}";
    results.add(resultJson);
    await prefs.setStringList('quiz_results', results);

    // 2. 🔥 Firebase kaydı - user_answers MUTLAKA ekleniyor
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('results')
            .add({
          'topic': topic,
          'testNo': testNo,
          'score': score,
          'correct': correctCount,
          'wrong': wrongCount,
          'empty': emptyCount,
          'timestamp': FieldValue.serverTimestamp(),
          'user_answers': userAnswers ?? [], // 🔥 Boş bile olsa kaydet
          'date': DateTime.now().toIso8601String(), // 🔥 Ek güvenlik
        });
        print("✅ Quiz result saved: $topic Test $testNo - user_answers: ${userAnswers?.length ?? 0} items");
      } catch (e) {
        print("❌ Firebase kayıt hatası: $e");
      }
    }
  }
  
  static Future<Map<int, int>> getTestScores(String topic) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('results')
          .where('topic', isEqualTo: topic)
          .get();
          
      Map<int, int> scores = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        int tNo = data['testNo'];
        int sc = data['score'];
        if (!scores.containsKey(tNo) || sc > scores[tNo]!) {
          scores[tNo] = sc;
        }
      }
      return scores;
    } catch (e) {
      return {};
    }
  }
}
