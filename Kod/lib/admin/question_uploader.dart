import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// JSON dosyasından soruları okuyup Firestore'a Batch Write ile kaydeder.
/// Mevcut QuestionUploader servisindeki alan isimleriyle (correctIndex, testNo vb.)
/// tam uyumludur.
class QuestionUploadService {
  final FirebaseFirestore _firestore;

  // Firebase Batch limiti 500 — 450 ile çalışıyoruz (güvenlik payı)
  static const int _batchLimit = 450;

  QuestionUploadService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // ANA FONKSİYON
  // filePath   : file_picker'dan gelen dosya yolu
  // topic      : hangi ders (örn: "anatomi", "fizyoloji")
  // onProgress : 0.0 – 1.0 arası ilerleme callback'i
  // ─────────────────────────────────────────────────────────────────────────
  Future<UploadResult> uploadFromFile({
    required String filePath,
    required String topic,
    void Function(double progress, int uploaded, int total)? onProgress,
  }) async {
    try {
      // 1. Dosyayı oku
      final file = File(filePath);
      if (!await file.exists()) {
        return UploadResult.error('Dosya bulunamadı: $filePath');
      }

      final String jsonString = await file.readAsString();
      return await _processJsonString(
        jsonString: jsonString,
        topic: topic,
        onProgress: onProgress,
      );
    } catch (e) {
      return UploadResult.error('Dosya okuma hatası: $e');
    }
  }

  /// Web / bytes üzerinden yükleme (file_picker bytes modu için)
  Future<UploadResult> uploadFromBytes({
    required Uint8List bytes,
    required String topic,
    void Function(double progress, int uploaded, int total)? onProgress,
  }) async {
    try {
      final String jsonString = utf8.decode(bytes);
      return await _processJsonString(
        jsonString: jsonString,
        topic: topic,
        onProgress: onProgress,
      );
    } catch (e) {
      return UploadResult.error('Bytes okuma hatası: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORTAK JSON İŞLEYİCİ
  // ─────────────────────────────────────────────────────────────────────────
  Future<UploadResult> _processJsonString({
    required String jsonString,
    required String topic,
    void Function(double progress, int uploaded, int total)? onProgress,
  }) async {
    // 2. JSON parse
    final List<dynamic> questionList = _parseJson(jsonString);
    if (questionList.isEmpty) {
      return UploadResult.error('JSON boş veya geçersiz format.');
    }

    final int total = questionList.length;
    int uploaded = 0;

    // 3. Batch işlemleri
    WriteBatch batch = _firestore.batch();
    int batchCounter = 0;

    // testNo bazında soru sırasını takip et
    final Map<int, int> testQuestionCounter = {};

    for (int i = 0; i < questionList.length; i++) {
      final item = questionList[i] as Map<String, dynamic>;

      // Alan okuma — hem snake_case hem camelCase destekli
      final int testNo = _safeInt(item['test_no'] ?? item['testNo']);
      final int originalId = _safeInt(item['id']);

      // Her test için soru indeksini ilerlet
      testQuestionCounter[testNo] = (testQuestionCounter[testNo] ?? 0);
      final int questionIndex = testQuestionCounter[testNo]!;
      testQuestionCounter[testNo] = questionIndex + 1;

      // Benzersiz doküman ID: ders_testNo_soruSırası
      // QuestionUploader'daki formatla aynı
      final String docId =
          '${topic.toLowerCase()}_${testNo}_$questionIndex';

      final DocumentReference docRef =
          _firestore.collection('questions').doc(docId);

      // QuizScreen'deki alan adlarıyla birebir eşleşen yapı:
      // correctIndex, testNo, questionIndex, topic
      final Map<String, dynamic> data = {
        'topic': topic.toLowerCase(),
        'testNo': testNo,
        'questionIndex': questionIndex,
        'original_id': originalId,
        'question': _safeString(item['question']),
        'options': _safeStringList(item['options']),
        // QuizScreen: data['correctIndex'] ?? 0
        'correctIndex':
            _safeInt(item['answer_index'] ?? item['correctIndex']),
        'explanation': _safeString(item['explanation']),
        'level': _safeString(item['level']),
        // Opsiyonel resim desteği
        'image_url': item['image_url'],
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      batch.set(docRef, data, SetOptions(merge: true));
      batchCounter++;
      uploaded++;

      // 4. Batch limiti doldu → commit et, yenisini başlat
      if (batchCounter >= _batchLimit) {
        await batch.commit();
        batch = _firestore.batch();
        batchCounter = 0;

        // İlerleme bildirimi
        onProgress?.call(uploaded / total, uploaded, total);
        debugPrint('⏳ $topic: $uploaded/$total yüklendi...');
      }
    }

    // 5. Kalan dokümanları commit et
    if (batchCounter > 0) {
      await batch.commit();
      onProgress?.call(1.0, uploaded, total);
    }

    debugPrint('✅ $topic: $total soru başarıyla Firestore\'a yazıldı.');
    return UploadResult.success(uploadedCount: total, topic: topic);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YARDIMCI: JSON PARSE
  // Hem [ {...} ] hem { "questions": [...] } formatını destekler
  // ─────────────────────────────────────────────────────────────────────────
  List<dynamic> _parseJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);

      if (decoded is List) return decoded;

      if (decoded is Map) {
        // Map içindeki ilk listeyi bul
        for (final value in decoded.values) {
          if (value is List) return value;
        }
      }
    } catch (e) {
      debugPrint('❌ JSON parse hatası: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YARDIMCI TİP GÜVENLİ DÖNÜŞTÜRÜCÜLER
  // Mevcut QuestionUploader servisindekiyle aynı mantık
  // ─────────────────────────────────────────────────────────────────────────
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static String _safeString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SONUÇ MODELİ
// ─────────────────────────────────────────────────────────────────────────
class UploadResult {
  final bool isSuccess;
  final int uploadedCount;
  final String topic;
  final String? errorMessage;

  const UploadResult._({
    required this.isSuccess,
    required this.uploadedCount,
    required this.topic,
    this.errorMessage,
  });

  factory UploadResult.success({
    required int uploadedCount,
    required String topic,
  }) =>
      UploadResult._(
        isSuccess: true,
        uploadedCount: uploadedCount,
        topic: topic,
      );

  factory UploadResult.error(String message) => UploadResult._(
        isSuccess: false,
        uploadedCount: 0,
        topic: '',
        errorMessage: message,
      );
}
