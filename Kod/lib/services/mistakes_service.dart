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
        data['id'] = doc.id;
        
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

  // 🔥 YENİ YANLIŞ EKLE (HAYALET VERİ KORUMALI)
  static Future<void> addMistakes(List<Map<String, dynamic>> mistakes) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    WriteBatch batch = _firestore.batch();

    for (var mistake in mistakes) {
      String topic = mistake['topic'] ?? mistake['subject'] ?? "genel";
      int testNo = int.tryParse(mistake['testNo'].toString()) ?? 0;
      int qIndex = int.tryParse(mistake['questionIndex'].toString()) ?? 0;

      // 🛡️ GÜVENLİK KAPISI: 
      // Eğer hem TestNo 0 hem de SoruIndex 0 ise bu hatalı bir kayıttır.
      // Bunu veritabanına sokma!
      if (testNo == 0 && qIndex == 0) {
        print("⚠️ Hatalı veri engellendi: ${topic}_0_0");
        continue; // Döngünün bu adımını atla
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

  // SİLME İŞLEMİ
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
  
  static Future<void> removeMistakeList(List<Map<String, dynamic>> items) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    WriteBatch batch = _firestore.batch();
    for(var item in items) {
       if(item['id'] is String) {
         DocumentReference docRef = _firestore.collection('users').doc(user.uid).collection('mistakes').doc(item['id']);
         batch.delete(docRef);
       }
    }
    await batch.commit();
  }

  static Future<void> syncLocalToFirebase() async {}
}