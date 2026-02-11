import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Yedek olarak kalsın

class QuizService {

// 🔥 DÜZELTME: ID'ye göre değil, İçeriğe (Konu ve Test No) göre arama yap
static Future<Map<String, dynamic>?> getQuizResult(String topic, int testNo) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  try {
    // 1. Önce Firebase'den Sorgula (En son çözülen testi getir)
    var querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('results')
        .where('topic', isEqualTo: topic)
        .where('testNo', isEqualTo: testNo)
        .orderBy('timestamp', descending: true) // En yeniyi al
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }
    
    // 2. Firebase'de bulamazsa Yerel Hafızaya (SharedPrefs) bak
    // (İnternet yokken çözülenler için)
    final prefs = await SharedPreferences.getInstance();
    List<String> localResults = prefs.getStringList('quiz_results') ?? [];
    
    // Format: "Konu|TestNo|Puan|Dogru|Yanlis|Tarih"
    for (String res in localResults.reversed) { // Tersten bak (en son eklenen)
      List<String> parts = res.split('|');
      if (parts.length >= 5 && parts[0] == topic && int.parse(parts[1]) == testNo) {
        return {
          'topic': parts[0],
          'testNo': int.parse(parts[1]),
          'score': int.parse(parts[2]),
          'correct': int.parse(parts[3]),
          'wrong': int.parse(parts[4]),
          'date': parts[5] // Tarih
        };
      }
    }

  } catch (e) {
    print("Sonuç getirme hatası: $e");
  }
  return null;
}
  
  // 🔥 Çözülen Testlerin Numaralarını Getir (Firebase'den)
  // 🔥 Çözülen Testlerin Numaralarını Getir (HEM LOCAL HEM FIREBASE - HİBRİT)
static Future<List<int>> getCompletedTests(String topic) async {
  Set<int> completedTests = {};

  try {
    // 1. ÖNCE YEREL VERİYİ ÇEK (HIZ İÇİN 🚀)
    final prefs = await SharedPreferences.getInstance();
    List<String> localResults = prefs.getStringList('quiz_results') ?? [];
    
    for (String res in localResults) {
      // Format: "Konu|TestNo|Puan|Dogru|Yanlis|Tarih"
      List<String> parts = res.split('|');
      if (parts.isNotEmpty && parts[0] == topic) {
        completedTests.add(int.parse(parts[1]));
      }
    }
  } catch (e) {
    print("Local okuma hatası: $e");
  }

  // 2. SONRA FIREBASE'DEN ÇEK (SENKRONİZASYON İÇİN ☁️)
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

  // 🔥 Sonuç Kaydetme (Hem Local Hem Firebase Destekli)
static Future<void> saveQuizResult({
  required String topic,
  required int testNo,
  required int score,
  required int correctCount,
  required int wrongCount,
  required int emptyCount, // Bunu da eklemen iyi olur
  List<int?>? userAnswers,
}) async {
  User? user = FirebaseAuth.instance.currentUser;

  // 1. Yerel Kayıt (Hız ve çevrimdışı kullanım için)
  final prefs = await SharedPreferences.getInstance();
  List<String> results = prefs.getStringList('quiz_results') ?? [];
  String resultJson = "$topic|$testNo|$score|$correctCount|$wrongCount|${DateTime.now()}";
  results.add(resultJson);
  await prefs.setStringList('quiz_results', results);

  // 2. 🔥 Firebase Kaydı (Burayı mutlaka açmalısın)
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
        // İstersen cevap anahtarını da tutabilirsin (analiz için)
        // 'userAnswers': userAnswers 
      });
    } catch (e) {
      print("Firebase kayıt hatası: $e");
      // Hata olursa yerel kayıttan sonra senkronize edecek bir yapı kurabilirsin.
    }
  }
}
  
  // Test İstatistiklerini Getir (Opsiyonel - Test Listesinde Puan Göstermek İstersen)
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
         // Eğer aynı testi birden fazla çözdüyse en yüksek puanı al
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