const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// E-posta gönderici ayarları (Gmail örneği)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().gmail.email,
    pass: functions.config().gmail.password
  }
});

// ✅ Fonksiyonlardan ÖNCE ekle (satır 14 civarı):
function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || typeof email !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'E-posta gerekli.');
  }
  if (!emailRegex.test(email) || email.length > 100) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçersiz e-posta.');
  }
}

function validateCode(code) {
  if (!code || typeof code !== 'string' || !/^\d{6}$/.test(code)) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçersiz kod formatı.');
  }
}

function validatePassword(password) {
  if (!password || typeof password !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Şifre gerekli.');
  }
  if (password.length < 6 || password.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Şifre 6-128 karakter olmalı.');
  }
}

// 🔹 1. FONKSİYON: Kod Gönder
exports.sendPasswordResetCode = functions.https.onCall(async (data, context) => {
  const { email } = data;

  validateEmail(email);

  // ✅ EKLE: Rate Limiting
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş gerekli.');
  }

  const userId = context.auth.uid;
  const now = Date.now();
  const oneHourAgo = now - 3600000;

  // Son 1 saatteki denemeleri kontrol et
  const recentAttempts = await db.collection('passwordResetAttempts')
    .where('userId', '==', userId)
    .where('timestamp', '>', oneHourAgo)
    .get();

  if (recentAttempts.size >= 3) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Çok fazla deneme. 1 saat sonra tekrar deneyin.'
    );
  }

  // Denemeyi kaydet
  await db.collection('passwordResetAttempts').add({
    userId: userId,
    email: email,
    timestamp: now
  });

  try {
    // Kullanıcıyı kontrol et
    const userRecord = await admin.auth().getUserByEmail(email);
    
    // 6 haneli rastgele kod oluştur
    const code = crypto.randomInt(100000, 999999).toString();    
    // Firestore'a kaydet (5 dakika geçerli)
    await db.collection('passwordResetCodes').doc(email).set({
      code: code,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 5 * 60 * 1000) // 5 dakika
      ),
      used: false
    });

    // E-posta gönder
    await transporter.sendMail({
      from: 'DUS Asistanı <forfuturedentists@gmail.com>',
      to: email,
      subject: '🔐 Şifre Sıfırlama Kodu',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">
            <h2 style="color: #0D47A1;">Şifre Sıfırlama Kodu</h2>
            <p style="font-size: 16px; color: #666;">Şifrenizi sıfırlamak için aşağıdaki kodu kullanın:</p>
            <div style="background: #E3F2FD; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
              <h1 style="color: #0D47A1; font-size: 36px; margin: 0; letter-spacing: 8px;">${code}</h1>
            </div>
            <p style="color: #999; font-size: 14px;">Bu kod 5 dakika içinde geçerliliğini yitirecektir.</p>
            <p style="color: #999; font-size: 14px;">Eğer bu isteği siz yapmadıysanız, bu e-postayı görmezden gelin.</p>
          </div>
        </div>
      `
    });

    return { success: true, message: 'Kod e-posta adresinize gönderildi.' };

  } catch (error) {
    console.error('Hata:', error);
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.');
    }
    throw new functions.https.HttpsError('internal', 'Kod gönderilemedi.');
  }
});

// 🔹 2. FONKSİYON: Kodu Doğrula ve Şifreyi Değiştir
exports.verifyCodeAndResetPassword = functions.https.onCall(async (data, context) => {
  const { email, code, newPassword } = data;

  validateEmail(email);
  validateCode(code);
  validatePassword(newPassword);

  try {
    // Firestore'dan kodu al
    const docRef = db.collection('passwordResetCodes').doc(email);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new functions.https.HttpsError('not-found', 'Kod bulunamadı.');
    }

    const codeData = doc.data();

    const attempts = codeData.attempts || 0;
    if (attempts>=5){
      await docRef.delete();
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Çok fazla hatalı deneme. Yeni kod isteyin.'
      );
    }

    // Kontroller
    if (codeData.used) {
      throw new functions.https.HttpsError('failed-precondition', 'Bu kod zaten kullanılmış.');
    }

    if (codeData.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Kod süresi dolmuş.');
    }

    if (codeData.code !== code) {
      await docRef.update({ attempts: attempts+1});
      throw new functions.https.HttpsError('invalid-argument', 'Geçersiz kod.');
    }

    // Şifreyi değiştir (Firebase Admin SDK)
    const userRecord = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword
    });

    // Kodu kullanıldı olarak işaretle
    await docRef.update({ used: true });

    return { success: true, message: 'Şifreniz başarıyla değiştirildi.' };

  } catch (error) {
    console.error('Hata:', error);
    throw error;
  }
});