import 'dart:convert';
import 'package:flutter/services.dart'; // rootBundle için
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionUploader {
  
  // 🔥 GÜVENLİ SAYI DÖNÜŞTÜRÜCÜ
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // 🔥 GÜVENLİ STRING DÖNÜŞTÜRÜCÜ
  static String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  // 🔥 GÜVENLİ LİSTE DÖNÜŞTÜRÜCÜ
  static List<String> _safeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static Future<void> uploadQuestions() async {
    final firestore = FirebaseFirestore.instance;
    
    // JSON dosya isimlerin
final files = [
      'anatomi', 
      'biyokimya', 
      'fizyoloji',
      'histoloji',
      'farma',
      'patoloji',
      'mikrobiyoloji',
      'biyoloji',
      'cerrahi', 
      'endo',      // Endodonti için
      'perio',     // Periodontoloji için
      'orto',      // Ortodonti için
      'pedo',      // Pedodonti için
      'protetik',
      'radyoloji',
      'resto'      // Restoratif için
    ];

    print("🚀 Yükleme (Düz Liste Modu) Başlatılıyor...");

    for (String lesson in files) {
      try {
        String path = 'Assets/data/$lesson.json'; 
        String jsonString = await rootBundle.loadString(path);
        
        // JSON'ı çöz
        var decodedData = jsonDecode(jsonString);
        List<dynamic> questionList = [];

        // Eğer JSON direkt bir liste ise (Attığın örnekteki gibi): [ {...}, {...} ]
        if (decodedData is List) {
          questionList = decodedData;
        } 
        // Eğer Map ise ve içinde liste varsa: { "questions": [...] }
        else if (decodedData is Map) {
           // Bazen 'Anatomi' key'i altında olabilir, bazen direkt values olabilir.
           // Güvenli yöntem: Map'in içindeki ilk listeyi bul.
           for (var value in decodedData.values) {
             if (value is List) {
               questionList = value;
               break;
             }
           }
        }

        if (questionList.isEmpty) {
          print("⚠️ $lesson içeriği boş veya format anlaşılamadı.");
          continue;
        }

        // --- BATCH İŞLEMİ ---
        WriteBatch batch = firestore.batch();
        int counter = 0;
        int totalLoaded = 0;

        // Her test grubu için soru indeksini sıfırdan başlatmak adına bir sayaç haritası tutalım
        // Örn: Test 1 -> 5. soruda, Test 2 -> 0. soruda
        Map<int, int> testQuestionCounter = {};

        for (var item in questionList) {
          // --- VERİ EŞLEŞTİRME (Senin JSON Formatına Göre) ---
          // JSON: "test_no" -> Bizim: testNo
          // JSON: "answer_index" -> Bizim: correctIndex
          
          int testNo = _safeInt(item['test_no'] ?? item['testNo']); // İkisini de dener
          int qIdFromJs = _safeInt(item['id']); // JSON'daki ID'yi alalım
          
          // Bu test numarası için soru sırasını belirle
          if (!testQuestionCounter.containsKey(testNo)) {
            testQuestionCounter[testNo] = 0;
          }
          int currentQuestionIndex = testQuestionCounter[testNo]!;
          testQuestionCounter[testNo] = currentQuestionIndex + 1;

          // DOKÜMAN ID: ders_testNo_soruSırası (Benzersiz olması için)
          String docId = "${lesson.toLowerCase()}_${testNo}_$currentQuestionIndex";
          
          DocumentReference docRef = firestore.collection('questions').doc(docId);
          
          Map<String, dynamic> data = {
            'topic': lesson.toLowerCase(),
            'testNo': testNo,
            'questionIndex': currentQuestionIndex,
            'question': _safeString(item['question']),
            'options': _safeList(item['options']),
            // Senin JSON'da "answer_index" var, eski kod "correctOption" arıyordu.
            'correctIndex': _safeInt(item['answer_index'] ?? item['correctOption']), 
            'explanation': _safeString(item['explanation']), // Eğer yoksa boş atar
            'level': _safeString(item['level']), // Zorluk seviyesini de alalım
            'original_id': qIdFromJs, // Takip için JSON'daki ID'yi de saklayalım
          };

          batch.set(docRef, data);
          
          counter++;
          totalLoaded++;

          // Firebase limiti (500 işlem)
          if (counter >= 450) {
            await batch.commit();
            batch = firestore.batch();
            counter = 0;
            print("⏳ $lesson yükleniyor...");
          }
        }

        // Kalanları gönder
        if (counter > 0) {
          await batch.commit();
        }

        print("✅ $lesson : $totalLoaded soru yüklendi!");

      } catch (e) {
        if (e.toString().contains("Unable to load asset")) {
           print("❌ DOSYA YOK: $lesson.json");
        } else {
           print("❌ HATA ($lesson): $e");
        }
      }
    }
    print("🎉 SONUÇ: Veritabanı doldu! Şimdi Quiz ekranını dene. 🎉");
  }
}