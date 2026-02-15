// lib/services/offline_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';

class OfflineService {
  static const String _offlinePrefix = 'offline_';
  static const String _downloadedTopicsKey = 'downloaded_topics';
  static const String _pendingSyncKey = 'pending_sync';
  
  // 🔥 KONUDAKİ TÜM SORULARI İNDİR (WiFi varken)
  static Future<bool> downloadTopic(String topic) async {
    try {
      // Topic ismini Firebase formatına çevir
      String dbTopic = _topicToDbName(topic);
      
      // Firebase'den tüm soruları çek
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('topic', isEqualTo: dbTopic)
          .orderBy('testNo')
          .orderBy('questionIndex')
          .get();
      
      if (snapshot.docs.isEmpty) {
        print("⚠️ $topic için soru bulunamadı");
        return false;
      }
      
      // Soruları Question modeline çevir
      List<Map<String, dynamic>> questions = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': data['questionIndex'] ?? 0,
          'question': data['question'] ?? "",
          'options': List<String>.from(data['options'] ?? []),
          'answerIndex': data['correctIndex'] ?? 0,
          'explanation': data['explanation'] ?? "",
          'testNo': data['testNo'] ?? 0,
          'level': data['topic'] ?? "Genel",
          'imageUrl': data['image_url'],
        };
      }).toList();
      
      // Yerel hafızaya kaydet
      final prefs = await SharedPreferences.getInstance();
      String key = '$_offlinePrefix$topic';
      String jsonData = jsonEncode(questions);
      
      await prefs.setString(key, jsonData);
      
      // İndirilen konular listesine ekle
      List<String> downloaded = prefs.getStringList(_downloadedTopicsKey) ?? [];
      if (!downloaded.contains(topic)) {
        downloaded.add(topic);
        await prefs.setStringList(_downloadedTopicsKey, downloaded);
      }
      
      print("✅ $topic indirildi: ${questions.length} soru");
      return true;
      
    } catch (e) {
      print("❌ İndirme hatası: $e");
      return false;
    }
  }
  
  // 🔥 İNDİRİLEN KONUYU SİL
  static Future<void> deleteTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    String key = '$_offlinePrefix$topic';
    await prefs.remove(key);
    
    List<String> downloaded = prefs.getStringList(_downloadedTopicsKey) ?? [];
    downloaded.remove(topic);
    await prefs.setStringList(_downloadedTopicsKey, downloaded);
    
    print("🗑️ $topic silindi");
  }
  
  // 🔥 KONU İNDİRİLDİ Mİ?
  static Future<bool> isTopicDownloaded(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloaded = prefs.getStringList(_downloadedTopicsKey) ?? [];
    return downloaded.contains(topic);
  }
  
  // 🔥 İNDİRİLEN TÜM KONULAR
  static Future<List<String>> getDownloadedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedTopicsKey) ?? [];
  }
  
  // 🔥 OFFLİNE SORULARI YÜKLE (Uçaktayken)
  static Future<List<Question>> loadOfflineQuestions(String topic, int testNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String key = '$_offlinePrefix$topic';
      String? jsonData = prefs.getString(key);
      
      if (jsonData == null) {
        print("⚠️ Offline veri yok");
        return [];
      }
      
      List<dynamic> questionList = jsonDecode(jsonData);
      
      // İlgili test numarasını filtrele
      List<Question> allQuestions = questionList.map((data) {
        return Question(
          id: data['id'] ?? 0,
          question: data['question'] ?? "",
          options: List<String>.from(data['options'] ?? []),
          answerIndex: data['answerIndex'] ?? 0,
          explanation: data['explanation'] ?? "",
          testNo: data['testNo'] ?? 0,
          level: data['level'] ?? "Genel",
          imageUrl: data['imageUrl'],
        );
      }).toList();
      
      // Sadece bu test numarasını döndür
      return allQuestions.where((q) => q.testNo == testNo).toList();
      
    } catch (e) {
      print("❌ Offline yükleme hatası: $e");
      return [];
    }
  }
  
  // 🔥 OFFLİNE YANLIŞ KAYDET (Uçaktayken)
  static Future<void> saveOfflineMistake(Map<String, dynamic> mistake) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingSyncKey) ?? [];
    
    String mistakeJson = jsonEncode(mistake);
    pending.add(mistakeJson);
    
    await prefs.setStringList(_pendingSyncKey, pending);
    print("💾 Offline yanlış kaydedildi (Senkronize edilecek)");
  }
  
  // 🔥 OFFLİNE SONUCU KAYDET (Uçaktayken)
  static Future<void> saveOfflineResult({
    required String topic,
    required int testNo,
    required int score,
    required int correctCount,
    required int wrongCount,
    required int emptyCount,
    required List<int?> userAnswers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingSyncKey) ?? [];
    
    Map<String, dynamic> result = {
      'type': 'result',
      'topic': topic,
      'testNo': testNo,
      'score': score,
      'correct': correctCount,
      'wrong': wrongCount,
      'empty': emptyCount,
      'user_answers': userAnswers,
      'date': DateTime.now().toIso8601String(),
    };
    
    pending.add(jsonEncode(result));
    await prefs.setStringList(_pendingSyncKey, pending);
    print("💾 Offline sonuç kaydedildi (Senkronize edilecek)");
  }
  
  // 🔥 BEKLEYEN VERİLERİ FİREBASE'E SENKRON ET (İnternet gelince)
  static Future<void> syncPendingData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingSyncKey) ?? [];
    
    if (pending.isEmpty) {
      print("✅ Senkronize edilecek veri yok");
      return;
    }
    
    print("🔄 ${pending.length} veri senkronize ediliyor...");
    
    int syncedCount = 0;
    List<String> failed = [];
    
    for (String item in pending) {
      try {
        Map<String, dynamic> data = jsonDecode(item);
        
        if (data['type'] == 'result') {
          // Sonuç kaydet
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('results')
              .add({
            'topic': data['topic'],
            'testNo': data['testNo'],
            'score': data['score'],
            'correct': data['correct'],
            'wrong': data['wrong'],
            'empty': data['empty'],
            'user_answers': data['user_answers'],
            'date': data['date'],
            'timestamp': FieldValue.serverTimestamp(),
          });
          
        } else {
          // Yanlış kaydet
          String topic = data['topic'] ?? "Genel";
          int testNo = data['testNo'] ?? 0;
          int qIndex = data['questionIndex'] ?? 0;
          String uniqueId = "${topic}_${testNo}_$qIndex";
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('mistakes')
              .doc(uniqueId)
              .set(data, SetOptions(merge: true));
        }
        
        syncedCount++;
        
      } catch (e) {
        print("❌ Senkron hatası: $e");
        failed.add(item);
      }
    }
    
    // Başarılı olanları temizle, başarısızları tut
    await prefs.setStringList(_pendingSyncKey, failed);
    
    print("✅ $syncedCount veri senkronize edildi");
    if (failed.isNotEmpty) {
      print("⚠️ ${failed.length} veri başarısız oldu, tekrar denenecek");
    }
  }
  
  // 🔥 BEKLEYEN VERİ VAR MI?
  static Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingSyncKey) ?? [];
    return pending.length;
  }
  
  // 🔥 İNDİRİLEN KONU BOYUTU
  static Future<String> getTopicSize(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    String key = '$_offlinePrefix$topic';
    String? jsonData = prefs.getString(key);
    
    if (jsonData == null) return "0 KB";
    
    int bytes = jsonData.length;
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
  
  // 🔥 YARDIMCI: Topic ismini DB formatına çevir
  static String _topicToDbName(String topic) {
    if (topic.contains("Anatomi")) return "anatomi";
    if (topic.contains("Biyokimya")) return "biyokimya";
    if (topic.contains("Fizyoloji")) return "fizyoloji";
    if (topic.contains("Histoloji")) return "histoloji";
    if (topic.contains("Farmakoloji")) return "farma";
    if (topic.contains("Patoloji")) return "patoloji";
    if (topic.contains("Mikrobiyoloji")) return "mikrobiyo";
    if (topic.contains("Biyoloji")) return "biyoloji";
    if (topic.contains("Cerrahi")) return "cerrahi";
    if (topic.contains("Endodonti")) return "endo";
    if (topic.contains("Perio")) return "perio";
    if (topic.contains("Orto")) return "orto";
    if (topic.contains("Pedo")) return "pedo";
    if (topic.contains("Protetik")) return "protetik";
    if (topic.contains("Radyoloji")) return "radyoloji";
    if (topic.contains("Restoratif")) return "resto";
    return topic.toLowerCase();
  }
}
