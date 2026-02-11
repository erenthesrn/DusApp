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
        
        // 🛠️ ID ÇAKIŞMASINI VE EKSİK VERİYİ ÖNLEME
        String docId = doc.id;
        data['id'] = docId; // String ID'yi sakla (örn: Anatomi_1_5)
        
        // Konu veya TestNo eksikse Document ID'den kurtar
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
        
        return data;
      }).toList();
    } catch (e) {
      print("Yanlışları getirme hatası: $e");
      return [];
    }
  }

  // 🔥 YENİ YANLIŞ EKLE
  static Future<void> addMistakes(List<Map<String, dynamic>> mistakes) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    WriteBatch batch = _firestore.batch();

    for (var mistake in mistakes) {
      String topic = mistake['topic'] ?? mistake['subject'] ?? "genel";
      int testNo = int.tryParse(mistake['testNo'].toString()) ?? 0;
      int qIndex = int.tryParse(mistake['questionIndex'].toString()) ?? 0;

      if (testNo == 0 && qIndex == 0) {
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
        'question': mistake['question'],
        'options': mistake['options'] ?? [],
        'correctIndex': mistake['correctIndex'],
        'explanation': mistake['explanation'] ?? "",
        'date': DateTime.now().toIso8601String(),
      };

      batch.set(docRef, dataToSave); 
    }

    await batch.commit();
  }

  // TEK SİLME İŞLEMİ
  static Future<void> removeMistake(dynamic id, String topic) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      if (id is String) {
         await _firestore.collection('users').doc(user.uid).collection('mistakes').doc(id).delete();
      }
    } catch (e) {
      print("Silme hatası: $e");
    }
  }
  
  // 🔥 DÜZELTİLDİ: ÇOKLU SİLME (LİSTE HALİNDE STRING ID ALIR)
  static Future<void> removeMistakeList(List<String> idsToRemove) async {
    User? user = _auth.currentUser;
    if (user == null || idsToRemove.isEmpty) return;
    
    WriteBatch batch = _firestore.batch();
    
    for(String id in idsToRemove) {
       DocumentReference docRef = _firestore.collection('users').doc(user.uid).collection('mistakes').doc(id);
       batch.delete(docRef);
    }
    
    await batch.commit();
  }

  // 🔥 EKLENDİ: HOME SCREEN HATASINI ÖNLEMEK İÇİN
  static Future<void> syncLocalToFirebase() async {
    // Burası şimdilik boş kalabilir, hata vermemesi için ekledik.
  }
}