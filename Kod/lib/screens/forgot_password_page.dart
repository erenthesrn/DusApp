import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dus_app_1/Fish.dart';
import '../utils/snackbar_helper.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;

  // ✅ Spam koruması için
  DateTime? _lastSubmitTime;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // ✅ Spam kontrolü fonksiyonu
  bool _canSubmit() {
    if (_lastSubmitTime == null) return true;
    return DateTime.now().difference(_lastSubmitTime!) > const Duration(seconds: 2);
  }

  // 1️⃣ Kod Gönder
  Future<void> _sendCode() async {
    // ✅ Spam kontrolü
    if (!_canSubmit()) {
      SnackBarHelper.showSnackBar(
        context,
        "Lütfen birkaç saniye bekleyin.",
        backgroundColor: Colors.orange,
      );
      return;
    }
    _lastSubmitTime = DateTime.now();

    FocusScope.of(context).unfocus();
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      SnackBarHelper.showSnackBar(
        context,
        "Lütfen e-posta adresinizi girin.",
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendPasswordResetCode');
      final result = await callable.call({'email': email});
      
      if (result.data['success']) {
        setState(() => _codeSent = true);
        SnackBarHelper.showSnackBar(
          context,
          "6 haneli kod e-postanıza gönderildi! 📧",
          backgroundColor: Colors.green,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      SnackBarHelper.showSnackBar(
        context,
        e.message ?? "Bir hata oluştu.",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 2️⃣ Kodu Doğrula ve Şifreyi Değiştir
  Future<void> _resetPassword() async {
    // ✅ Spam kontrolü
    if (!_canSubmit()) {
      SnackBarHelper.showSnackBar(
        context,
        "Lütfen birkaç saniye bekleyin.",
        backgroundColor: Colors.orange,
      );
      return;
    }
    _lastSubmitTime = DateTime.now();

    FocusScope.of(context).unfocus();
    String email = _emailController.text.trim();
    String code = _codeController.text.trim();
    String newPassword = _newPasswordController.text.trim();

    if (code.isEmpty || newPassword.isEmpty) {
      SnackBarHelper.showSnackBar(
        context,
        "Lütfen tüm alanları doldurun.",
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (newPassword.length < 6) {
      SnackBarHelper.showSnackBar(
        context,
        "Şifre en az 6 karakter olmalıdır.",
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('verifyCodeAndResetPassword');
      final result = await callable.call({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });

      if (result.data['success']) {
        if (mounted) {
          // ✅ SnackBar'ları temizle dialog açmadan önce
          ScaffoldMessenger.of(context).clearSnackBars();
          
          showDialog(
            context: context,
            barrierDismissible: false, // ✅ Dışarı tıklayarak kapatamasın
            builder: (context) => AlertDialog(
              title: const Text("✅ Başarılı!"),
              content: const Text("Şifreniz başarıyla değiştirildi. Şimdi giriş yapabilirsiniz."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Dialog'u kapat
                    Navigator.pop(context); // ForgotPasswordPage'i kapat
                  },
                  child: const Text("Giriş Yap"),
                )
              ],
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      SnackBarHelper.showSnackBar(
        context,
        e.message ?? "Bir hata oluştu.",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF0D47A1),
      scaffoldBackgroundColor: const Color.fromARGB(255, 224, 247, 250),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0D47A1),
        secondary: Color(0xFF00BFA5),
        surface: Colors.white,
        onSurface: Colors.black87,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[700]),
        prefixIconColor: Colors.grey[600],
      ),
    );

    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 224, 247, 250),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 224, 247, 250),
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Fish.fish_svgrepo_com, size: 100, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 24),
                
                Text(
                  'Şifrenizi mi unuttunuz?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'E-posta adresinize 6 haneli doğrulama kodu göndereceğiz.',
                  style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 32),

                // E-posta
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_codeSent && !_isLoading, // ✅ Loading sırasında da disable et
                  decoration: const InputDecoration(
                    labelText: 'E-posta Adresi',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Kod Gönder Butonu
                if (!_codeSent)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[400], // ✅ Disabled rengi
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Kod Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                // Kod ve Yeni Şifre Alanları
                if (_codeSent) ...[
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_isLoading, // ✅ Loading sırasında disable et
                    decoration: const InputDecoration(
                      labelText: '6 Haneli Kod',
                      prefixIcon: Icon(Icons.lock_outline),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    enabled: !_isLoading, // ✅ Loading sırasında disable et
                    decoration: const InputDecoration(
                      labelText: 'Yeni Şifre',
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[400], // ✅ Disabled rengi
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Şifreyi Değiştir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: _isLoading ? null : () { // ✅ Loading sırasında disable et
                      setState(() {
                        _codeSent = false;
                        _codeController.clear();
                        _newPasswordController.clear();
                        _lastSubmitTime = null; // ✅ Timer'ı sıfırla
                      });
                    },
                    child: const Text('Farklı e-posta ile dene'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}