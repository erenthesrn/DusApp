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

  // ─────────────────────────────────────────────────────────────────────────
  // DOWNLOAD
  // ─────────────────────────────────────────────────────────────────────────

  /// Downloads all questions for a topic from Firebase and stores them locally.
  /// Returns true on success, false on any failure.
  static Future<bool> downloadTopic(String topic) async {
    try {
      String dbTopic = _topicToDbName(topic);

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

      final prefs = await SharedPreferences.getInstance();
      String key = '$_offlinePrefix$topic';

      await prefs.setString(key, jsonEncode(questions));

      List<String> downloaded =
          prefs.getStringList(_downloadedTopicsKey) ?? [];
      if (!downloaded.contains(topic)) {
        downloaded.add(topic);
        await prefs.setStringList(_downloadedTopicsKey, downloaded);
      }

      print("✅ $topic indirildi: ${questions.length} soru");
      return true;
    } catch (e) {
      print("❌ İndirme hatası ($topic): $e");
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  /// Removes a downloaded topic from local storage.
  static Future<void> deleteTopic(String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_offlinePrefix$topic');

      List<String> downloaded =
          prefs.getStringList(_downloadedTopicsKey) ?? [];
      downloaded.remove(topic);
      await prefs.setStringList(_downloadedTopicsKey, downloaded);

      print("🗑️ $topic silindi");
    } catch (e) {
      print("❌ Silme hatası ($topic): $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS QUERIES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> isTopicDownloaded(String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> downloaded =
          prefs.getStringList(_downloadedTopicsKey) ?? [];
      return downloaded.contains(topic);
    } catch (e) {
      print("❌ isTopicDownloaded hatası ($topic): $e");
      return false;
    }
  }

  static Future<List<String>> getDownloadedTopics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_downloadedTopicsKey) ?? [];
    } catch (e) {
      print("❌ getDownloadedTopics hatası: $e");
      return [];
    }
  }

  static Future<String> getTopicSize(String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonData = prefs.getString('$_offlinePrefix$topic');
      if (jsonData == null) return "0 KB";

      int bytes = jsonData.length;
      if (bytes < 1024) return "$bytes B";
      if (bytes < 1024 * 1024) {
        return "${(bytes / 1024).toStringAsFixed(1)} KB";
      }
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    } catch (e) {
      return "? KB";
    }
  }

  static Future<int> getPendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_pendingSyncKey) ?? []).length;
    } catch (e) {
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD OFFLINE QUESTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Loads cached questions for a specific topic + testNo.
  /// Returns an empty list (never throws) on any failure.
  static Future<List<Question>> loadOfflineQuestions(
      String topic, int testNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonData = prefs.getString('$_offlinePrefix$topic');

      if (jsonData == null || jsonData.isEmpty) {
        print("⚠️ Offline veri yok: $topic");
        return [];
      }

      List<dynamic> decoded;
      try {
        decoded = jsonDecode(jsonData) as List<dynamic>;
      } catch (parseError) {
        print("❌ JSON parse hatası ($topic): $parseError");
        return [];
      }

      List<Question> allQuestions = decoded
          .map((data) {
            try {
              return Question(
                id: (data['id'] as num?)?.toInt() ?? 0,
                question: data['question']?.toString() ?? "",
                options: data['options'] != null
                    ? List<String>.from(data['options'] as List)
                    : [],
                answerIndex: (data['answerIndex'] as num?)?.toInt() ?? 0,
                explanation: data['explanation']?.toString() ?? "",
                testNo: (data['testNo'] as num?)?.toInt() ?? 0,
                level: data['level']?.toString() ?? "Genel",
                imageUrl: data['imageUrl']?.toString(),
              );
            } catch (e) {
              print("⚠️ Soru parse hatası (atlanıyor): $e");
              return null;
            }
          })
          .whereType<Question>()
          .toList();

      final filtered =
          allQuestions.where((q) => q.testNo == testNo).toList();
      print(
          "📂 Offline yüklendi: $topic test=$testNo → ${filtered.length} soru");
      return filtered;
    } catch (e) {
      print("❌ loadOfflineQuestions genel hatası: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE OFFLINE MISTAKE
  // ─────────────────────────────────────────────────────────────────────────

  /// Appends a single mistake to the pending-sync queue.
  /// Never throws; failures are logged only.
  static Future<void> saveOfflineMistake(
      Map<String, dynamic> mistake) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pending =
          prefs.getStringList(_pendingSyncKey) ?? [];

      // Tag so the sync logic knows this is a mistake record
      final tagged = Map<String, dynamic>.from(mistake)
        ..putIfAbsent('type', () => 'mistake');

      pending.add(jsonEncode(tagged));
      await prefs.setStringList(_pendingSyncKey, pending);
      print(
          "💾 Offline yanlış kaydedildi (${pending.length} bekliyor)");
    } catch (e) {
      print("❌ saveOfflineMistake hatası (non-fatal): $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE OFFLINE RESULT
  // ─────────────────────────────────────────────────────────────────────────

  /// Appends a quiz result to the pending-sync queue.
  /// Never throws; failures are logged only.
  static Future<void> saveOfflineResult({
    required String topic,
    required int testNo,
    required int score,
    required int correctCount,
    required int wrongCount,
    required int emptyCount,
    required List<int?> userAnswers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pending =
          prefs.getStringList(_pendingSyncKey) ?? [];

      final result = {
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
      print(
          "💾 Offline sonuç kaydedildi (${pending.length} bekliyor)");
    } catch (e) {
      print("❌ saveOfflineResult hatası (non-fatal): $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC PENDING DATA
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads all locally-queued data to Firebase.
  /// Individual item failures are captured; successful items are removed
  /// from the queue while failed ones are retried next time.
  static Future<void> syncPendingData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("⚠️ Senkronizasyon atlandı: kullanıcı oturum açmamış");
      return;
    }

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      print("❌ SharedPreferences erişim hatası: $e");
      return;
    }

    List<String> pending = prefs.getStringList(_pendingSyncKey) ?? [];

    if (pending.isEmpty) {
      print("✅ Senkronize edilecek veri yok");
      return;
    }

    print("🔄 ${pending.length} veri senkronize ediliyor...");

    int syncedCount = 0;
    List<String> failed = [];

    for (final item in pending) {
      Map<String, dynamic> data;
      try {
        data = jsonDecode(item) as Map<String, dynamic>;
      } catch (e) {
        print("⚠️ Bozuk kayıt atlanıyor: $e");
        // Don't keep corrupt entries in the queue
        continue;
      }

      bool success = false;

      try {
        if (data['type'] == 'result') {
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
          success = true;
        } else {
          // Treat everything else as a mistake record
          String topic = data['topic']?.toString() ?? "Genel";
          int testNo = (data['testNo'] as num?)?.toInt() ?? 0;
          int qIndex = (data['questionIndex'] as num?)?.toInt() ?? 0;
          String uniqueId = "${topic}_${testNo}_$qIndex";

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('mistakes')
              .doc(uniqueId)
              .set(data, SetOptions(merge: true));
          success = true;
        }
      } catch (e) {
        print("❌ Senkron hatası (tekrar denenecek): $e");
        failed.add(item);
      }

      if (success) syncedCount++;
    }

    // Persist: keep only failed items for retry
    try {
      await prefs.setStringList(_pendingSyncKey, failed);
    } catch (e) {
      print("❌ Kuyruk güncelleme hatası: $e");
    }

    print("✅ $syncedCount / ${pending.length} veri senkronize edildi");
    if (failed.isNotEmpty) {
      print(
          "⚠️ ${failed.length} veri başarısız oldu, tekrar denenecek");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — topic name → Firebase collection name
  // ─────────────────────────────────────────────────────────────────────────
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
