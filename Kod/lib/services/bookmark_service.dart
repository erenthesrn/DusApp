import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';

class BookmarkService {
  // Kullanıcının favoriler koleksiyonuna referans
  static CollectionReference _getBookmarkRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Kullanıcı oturum açmamış");
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('bookmarks');
  }

  // Soru favori mi kontrol et
  static Future<bool> isBookmarked(String uniqueId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final doc = await _getBookmarkRef().doc(uniqueId).get();
    return doc.exists;
  }

  // Favoriye Ekle / Çıkar (Toggle)
  static Future<bool> toggleBookmark(Question question, String topic) async {
    // Benzersiz ID oluştur: Konu_TestNo_SoruID
    // Boşlukları ve özel karakterleri temizle
    String safeTopic = topic.replaceAll(' ', '_').toLowerCase();
    String uniqueId = "${safeTopic}_${question.testNo}_${question.id}";

    final ref = _getBookmarkRef().doc(uniqueId);
    final doc = await ref.get();

    if (doc.exists) {
      // Varsa sil
      await ref.delete();
      return false; // Artık favori değil
    } else {
      // Yoksa ekle
      await ref.set({
        'id': question.id,
        'question': question.question,
        'options': question.options,
        'correctIndex': question.answerIndex,
        'explanation': question.explanation,
        'testNo': question.testNo,
        'topic': topic, // Orijinal konu ismi
        'image_url': question.imageUrl,
        'level': question.level,
        'savedAt': FieldValue.serverTimestamp(),
      });
      return true; // Artık favori
    }
  }

  // Tüm favorileri getir
  static Stream<QuerySnapshot> getBookmarksStream() {
    return _getBookmarkRef().orderBy('savedAt', descending: true).snapshots();
  }
}