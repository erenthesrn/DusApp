import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MistakesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 YANLIŞLARI GETİR
  static Future<List<Map<String, dynamic>>> getMistakes() async {
    User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      var snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('mistakes')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data();
        
        String docId = doc.id;
        data['id'] = docId;
        
        // Document ID'den veri kurtar
        List<String> parts = docId.split('_');
        if (parts.length >= 3) {
          if (data['topic'] == null || data['topic'] == "genel" || data['topic'] == "") {
            data['topic'] = parts[0]; 
          }
          if (data['testNo'] == null) {
            data['testNo'] = int.tryParse(parts[1]) ?? 0;
          }
          if (data['questionIndex'] == null) {
            data['questionIndex'] = int.tryParse(parts[2]) ?? 0;
          }
        }

        if (data['options'] != null) {
          if (data['options'] is List) {
            data['options'] = List<String>.from(data['options']);
          } else {
            data['options'] = [];
          }
        } else {
          data['options'] = [];
        }
        
        // 🔥 GÖRSEL URL'İNİ SAKLA (null olabilir)
        data['imageUrl'] = data['image_url'];
        
        return data;
      }).toList();
    } catch (e) {
      print("❌ Yanlışları getirme hatası: $e");
      return [];
    }
  }

  // 🔥 DÜZELTME: topic ve questionIndex eksiksiz kaydediliyor
  static Future<void> addMistakes(List<Map<String, dynamic>> mistakes) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    WriteBatch batch = _firestore.batch();
    int savedCount = 0;

    for (var mistake in mistakes) {
      // 🔥 FIX: Hem 'topic' hem 'subject' alanlarını kontrol et
      String topic = (mistake['topic'] ?? mistake['subject'] ?? "Genel").toString().trim();

      // Boş topic'i engelle
      if (topic.isEmpty || topic.toLowerCase() == "genel") {
        topic = "Anatomi"; // Varsayılan konu (anatomi.json'dan geldiği için)
      }

      // İlk harfi büyük yap (ör: "anatomi" → "Anatomi")
      topic = topic[0].toUpperCase() + topic.substring(1);
      
      int testNo = int.tryParse(mistake['testNo']?.toString() ?? "0") ?? 0;
      int qIndex = int.tryParse(mistake['questionIndex']?.toString() ?? mistake['id']?.toString() ?? "0") ?? 0;

      // 🔥 DÜZELTME: || yerine && kullanıldı
      // qIndex=0 geçerli bir soru indeksidir (ilk soru).
      // Sadece ikisi de 0 ise (yani gerçekten geçersiz veri) atla.
      if (testNo == 0 && qIndex == 0) {
        print("⚠️ Geçersiz veri atlandı: testNo=$testNo, qIndex=$qIndex");
        continue;
      }

      String uniqueId = "${topic}_${testNo}_$qIndex";
      
      DocumentReference docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('mistakes')
          .doc(uniqueId);

      Map<String, dynamic> dataToSave = {
        'topic': topic,
        'testNo': testNo,
        'questionIndex': qIndex,
        'question': mistake['question'] ?? "",
        'options': mistake['options'] ?? [],
        'correctIndex': mistake['correctIndex'] ?? 0,
        'userIndex': mistake['userIndex'] ?? -1,
        'explanation': mistake['explanation'] ?? "",
        'image_url': mistake['image_url'], // 🔥 GÖRSEL URL'İNİ KAYDET
        'date': DateTime.now().toIso8601String(),
      };

      batch.set(docRef, dataToSave, SetOptions(merge: true));
      savedCount++;
    }

    if (savedCount > 0) {
      await batch.commit();
      print("✅ $savedCount yanlış soru Firebase'e kaydedildi.");
    }
  }

  // TEK SİLME
  static Future<void> removeMistake(dynamic id, String topic) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      if (id is String) {
        await _firestore.collection('users').doc(user.uid).collection('mistakes').doc(id).delete();
      }
    } catch (e) {
      print("❌ Silme hatası: $e");
    }
  }
  
  // ÇOKLU SİLME
  static Future<void> removeMistakeList(List<String> idsToRemove) async {
    User? user = _auth.currentUser;
    if (user == null || idsToRemove.isEmpty) return;
    
    WriteBatch batch = _firestore.batch();
    
    for (String id in idsToRemove) {
      DocumentReference docRef = _firestore.collection('users').doc(user.uid).collection('mistakes').doc(id);
      batch.delete(docRef);
    }
    
    await batch.commit();
  }

  static Future<void> syncLocalToFirebase() async {
    // Boş bırakıldı - hata önleme için
  }
}