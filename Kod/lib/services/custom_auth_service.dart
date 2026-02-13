import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. 6 Haneli Kod Üretip Mail Atma Fonksiyonu
  Future<void> sendVerificationCode() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    // 6 haneli rastgele kod üret
    String code = (Random().nextInt(900000) + 100000).toString();
    
    // Geçerlilik süresi (Şu an + 15 dakika)
    DateTime expiresAt = DateTime.now().add(const Duration(minutes: 15));

try {
      // A. Kodu Kullanıcının Veritabanına Kaydet
      await _firestore.collection('users').doc(user.uid).update({
        'verificationCode': code,
        'codeExpiresAt': expiresAt,
      });

      // B. Mail Kuyruğuna Ekle
      await _firestore.collection('mail').add({
        'to': [user.email],
        'message': {
          // 1. GÖNDEREN İSMİ BURADA AYARLANIYOR
          'from': 'DUS Asistanı <forfuturedentists@gmail.com>', 
          'subject': 'Giriş Doğrulama Kodunuz: $code',
          'html': '''
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>DUS Asistanı Doğrulama</title>
          </head>
          <body style="margin: 0; padding: 0; background-color: #f8f9fa; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
            
            <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="padding: 40px 0;">
              <tr>
                <td align="center">
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 540px; background-color: #ffffff; border-radius: 16px; box-shadow: 0 8px 30px rgba(0,0,0,0.04); border: 1px solid #eaeaea; overflow: hidden;">
                    
                    <tr>
                      <td align="center" style="padding: 40px 0 30px 0; border-bottom: 1px solid #f0f0f0;">
                        <img src="https://firebasestorage.googleapis.com/v0/b/dusapp-17b00.firebasestorage.app/o/logo-Photoroom.png?alt=media&token=1d29879d-c3b3-4c06-8f92-99160b7f61ca" alt="DUS Asistanı" width="120" style="display: block; border: 0; outline: none; text-decoration: none; -ms-interpolation-mode: bicubic;">
                        
                        <div style="margin-top: 12px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 18px; font-weight: 700; color: #0D47A1; letter-spacing: 1.5px; text-transform: uppercase;">
                          DUS Asistanı
                        </div>
                      </td>
                    </tr>

                    <tr>
                      <td style="padding: 40px 40px 20px 40px; text-align: center;">
                        <h1 style="color: #111111; margin: 0 0 15px 0; font-size: 24px; font-weight: 600; letter-spacing: -0.5px;">Giriş Doğrulama</h1>
                        <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                          Hesabınıza güvenli erişim sağlamak için tek kullanımlık doğrulama kodunuz aşağıdadır.
                        </p>

                        <div style="background-color: #f5f8ff; border: 1px solid #dce8ff; border-radius: 12px; padding: 24px; display: inline-block; margin-bottom: 30px;">
                          <span style="font-family: 'SF Mono', 'Menlo', 'Monaco', 'Courier New', monospace; font-size: 36px; font-weight: 700; color: #0D47A1; letter-spacing: 8px; display: block;">$code</span>
                        </div>

                        <p style="color: #888888; font-size: 14px; margin: 0;">
                          Bu kod kişiseldir ve <strong>15 dakika</strong> süreyle geçerlidir.<br>
                          Güvenliğiniz için kodu kimseyle paylaşmayınız.
                        </p>
                      </td>
                    </tr>

                    <tr>
                      <td style="background-color: #fafafa; padding: 24px; text-align: center; border-top: 1px solid #eaeaea;">
                        <p style="color: #999999; font-size: 12px; margin: 0; line-height: 1.5;">
                          © 2026 DUS Asistanı Teknoloji A.Ş.<br>
                          Bu e-posta otomatik olarak oluşturulmuştur.
                        </p>
                      </td>
                    </tr>

                  </table>
                </td>
              </tr>
            </table>

          </body>
          </html>
          ''',
        }
      });
      
    } catch (e) {
      print("Mail gönderme hatası: $e");
      throw e;
    }
  }
  // 2. Girilen Kodu Doğrulama Fonksiyonu
  Future<bool> verifyCode(String inputCode) async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!doc.exists) return false;
    
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String? storedCode = data['verificationCode'];
    Timestamp? expiresAtTimestamp = data['codeExpiresAt'];

    // Kod yanlışsa veya yoksa
    if (storedCode != inputCode) {
      throw Exception("Hatalı kod girdiniz.");
    }

    // Süre dolmuşsa
    if (expiresAtTimestamp != null) {
      DateTime expiresAt = expiresAtTimestamp.toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception("Kodun süresi dolmuş. Lütfen yeni kod isteyin.");
      }
    }

    // --- BAŞARILI ---
    // Firestore'daki kodu temizle (tekrar kullanılamasın)
    await _firestore.collection('users').doc(user.uid).update({
      'verificationCode': FieldValue.delete(),
      'codeExpiresAt': FieldValue.delete(),
      'isEmailVerified': true, // Kendi flag'imiz
    });

    // Firebase Auth tarafında da verified yapabiliriz ama bu Client tarafında zor.
    // Genelde "isEmailVerified" alanını Firestore'da tutup oradan kontrol etmek daha kolaydır.
    
    return true;
  }
}