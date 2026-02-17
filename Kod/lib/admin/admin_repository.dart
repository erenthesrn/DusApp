import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Kullanıcının admin rolünü Firestore'dan kontrol eder.
/// users/{uid} dokümanındaki `role: "admin"` alanını okur.
class AdminRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────
  // checkAdminStatus
  // Dönüş: true = admin, false = normal kullanıcı veya hata
  // ─────────────────────────────────────────────────────────────
  Future<bool> checkAdminStatus() async {
    try {
      final User? user = _auth.currentUser;

      // Giriş yapılmamış → kesinlikle admin değil
      if (user == null) return false;

      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['role'] == 'admin';
    } catch (e) {
      // Firestore erişim hatası, network sorunu vb. → admin sayma
      print('❌ checkAdminStatus hatası: $e');
      return false;
    }
  }

  /// Firestore'a test kullanıcısına admin rolü vermek için
  /// yalnızca geliştirme ortamında çağır.
  /// Prodüksiyonda bunu Firebase Console veya Cloud Function ile yap.
  Future<void> setAdminRole(String uid) async {
    await _firestore.collection('users').doc(uid).set(
      {'role': 'admin'},
      SetOptions(merge: true), // Diğer alanları silme
    );
  }
}
